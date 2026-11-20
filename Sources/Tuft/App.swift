import AppKit
import SpriteKit
import IOKit.ps
import ServiceManagement
import CoreAudio
import CoreMediaIO

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class OverlayView: SKView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class ActionItem: NSMenuItem {
    private let handler: () -> Void
    init(_ title: String, checked: Bool = false, _ handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
        state = checked ? .on : .off
    }
    required init(coder: NSCoder) { fatalError() }
    @objc private func fire() { handler() }
}

/// Tells whether a call is likely on, by asking whether any app is using the microphone or a camera.
/// It never opens either device itself, so it needs no permission.
enum CallWatch {
    static func micInUse() -> Bool {
        var dev = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                           mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &dev) == noErr,
              dev != 0 else { return false }
        var running: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        a.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        return AudioObjectGetPropertyData(dev, &a, 0, nil, &size, &running) == noErr && running != 0
    }

    static func cameraInUse() -> Bool {
        var a = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
                                          mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                          mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var size: UInt32 = 0
        let sys = CMIOObjectID(kCMIOObjectSystemObject)
        guard CMIOObjectGetPropertyDataSize(sys, &a, 0, nil, &size) == 0, size > 0 else { return false }
        var ids = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(sys, &a, 0, nil, size, &used, &ids) == 0 else { return false }
        a.mSelector = CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere)
        for id in ids {
            var running: UInt32 = 0
            if CMIOObjectGetPropertyData(id, &a, 0, nil, UInt32(MemoryLayout<UInt32>.size), &used, &running) == 0,
               running != 0 { return true }
        }
        return false
    }
}

/// Current conditions from Open-Meteo (free, no account). Only the city name and its coordinates are sent.
enum RealWeather {
    private static func json(_ url: String, _ done: @escaping ([String: Any]?) -> Void) {
        guard let u = URL(string: url) else { done(nil); return }
        URLSession.shared.dataTask(with: u) { data, _, _ in
            let obj = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
            DispatchQueue.main.async { done(obj) }
        }.resume()
    }

    static func geocode(_ city: String, done: @escaping ((Double, Double, String)?) -> Void) {
        let q = city.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? city
        json("https://geocoding-api.open-meteo.com/v1/search?count=1&name=\(q)") { o in
            guard let r = (o?["results"] as? [[String: Any]])?.first,
                  let la = r["latitude"] as? Double, let lo = r["longitude"] as? Double else { done(nil); return }
            done((la, lo, r["name"] as? String ?? city))
        }
    }

    static func current(lat: Double, lon: Double, done: @escaping (Weather?) -> Void) {
        json("https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=weather_code,is_day") { o in
            guard let c = o?["current"] as? [String: Any], let code = c["weather_code"] as? Int else { done(nil); return }
            let day = (c["is_day"] as? Int ?? 1) == 1
            switch code {
            case 71...77, 85, 86: done(.snow)
            case 51...67, 80...82, 95...99: done(.rain)
            case 0: done(day ? .sakura : .starfall)          // clear
            default: done(day ? .leaves : .fireflies)        // cloudy or foggy
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panels: [OverlayPanel] = []
    private var scenes: [WeatherScene] = []
    private var pollTimer: Timer?
    private var slowTimer: Timer?
    private var lastPoll = CACurrentMediaTime()
    private let s = Settings.shared
    var debug = false
    private var asleep = false
    private var ticks = 0
    private var activity: NSObjectProtocol?
    private var moodItem: NSMenuItem?
    private var focusItem: NSMenuItem?
    private var didApplyOnce = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        s.tickMood()
        buildOverlays()
        rebuildMenu()
        refreshPower()

        // Keep App Nap from freezing the animation while the app has no regular window.
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiatedAllowingIdleSystemSleep],
                                                         reason: "Animating the desktop overlay")
        pollTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.poll() }
        pollTimer?.tolerance = 0.02
        RunLoop.main.add(pollTimer!, forMode: .common)
        slowTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.housekeeping() }
        slowTimer?.tolerance = 0.2
        RunLoop.main.add(slowTimer!, forMode: .common)

        let nc = NotificationCenter.default, ws = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        ws.addObserver(self, selector: #selector(screensSlept), name: NSWorkspace.screensDidSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(screensWoke), name: NSWorkspace.screensDidWakeNotification, object: nil)
        followTimeOfDay()
        applySound()
        if s.syncWeather { syncNow() }
    }

    // MARK: Overlays

    private func buildOverlays() {
        panels.forEach { $0.close() }
        panels = []; scenes = []
        for (i, screen) in NSScreen.screens.enumerated() {
            let panel = OverlayPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                                     backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.level = .statusBar
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            // No .fullScreenAuxiliary: the overlay stays out of full-screen spaces.
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            let view = OverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.allowsTransparency = true
            view.ignoresSiblingOrder = true
            let scene = WeatherScene(screen: screen, index: i)
            scene.debug = debug
            view.presentScene(scene)
            panel.contentView = view
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            panels.append(panel)
            scenes.append(scene)
        }
        applyPause()
    }

    @objc private func screensChanged() { buildOverlays() }
    @objc private func screensSlept() { asleep = true; applyPause() }
    @objc private func screensWoke() { asleep = false; applyPause() }

    private func housekeeping() {
        s.busy = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown) < 5
        ticks += 1
        s.tickMood()
        if let end = s.focusEnd, Date() >= end {            // focus session done: the pets celebrate
            s.focusEnd = nil
            s.celebrate = true
            s.cheer(10)
            NSSound(named: "Glass")?.play()
        }
        if ticks % 3 == 0 {
            let quiet = s.hideOnCalls && (CallWatch.micInUse() || CallWatch.cameraInUse())
            if quiet != s.quiet { s.quiet = quiet; applySound() }
        }
        if ticks % 60 == 0 {
            refreshPower()
            followTimeOfDay()
        }
        if s.syncWeather, ticks % 1200 == 0 { syncNow() }
        refreshLiveItems()
        applyPause()
    }

    /// Stop drawing when hidden, asleep, under a full-screen window, or with nothing to show.
    private func applyPause() {
        for (i, p) in panels.enumerated() {
            guard let v = p.contentView as? SKView, i < scenes.count else { continue }
            let pause = s.hidden || asleep || scenes[i].covered || scenes[i].isIdle
            if v.isPaused != pause { v.isPaused = pause }
            let fps = (s.smooth && s.power >= 1) ? 60 : 30
            if v.preferredFramesPerSecond != fps { v.preferredFramesPerSecond = fps }
            if s.hidden { if p.isVisible { p.orderOut(nil) } } else if !p.isVisible { p.orderFrontRegardless() }
        }
    }

    private func poll() {
        guard !s.hidden, !asleep else { return }
        let now = CACurrentMediaTime()
        let dt = CGFloat(now - lastPoll)
        lastPoll = now
        let wins = WindowTracker.poll()
        scenes.forEach { $0.setWindows(wins, dt: dt) }
    }

    private func refreshPower() {
        var battery = false
        if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String? {
            battery = type == "Battery Power"
        }
        let p = (battery || ProcessInfo.processInfo.isLowPowerModeEnabled) ? 0.5 : 1.0
        if p != s.power { s.power = p; applyPause() }
    }

    private func applySound() { Ambience.shared.set(s.weather, on: s.sound && !s.hidden) }

    private func setWeather(_ w: Weather, manual: Bool) {
        if manual { s.syncWeather = false }
        guard w != s.weather || manual else { return }
        s.weather = w
        applyPause()
        applySound()
        if s.wallpaperOn { applyWallpaper(DayTime(rawValue: s.wallTime) ?? .night) } else { rebuildMenu() }
    }

    // MARK: Real weather

    private func syncNow() {
        guard !s.city.isEmpty else { return }
        RealWeather.current(lat: s.lat, lon: s.lon) { [weak self] w in
            guard let self, self.s.syncWeather, let w else { return }
            self.setWeather(w, manual: false)
        }
    }

    private func chooseCity(thenSync: Bool) {
        guard let name = prompt("Your city", "Used only to look up the current weather.", s.city), !name.isEmpty else { return }
        RealWeather.geocode(name) { [weak self] hit in
            guard let self else { return }
            guard let hit else { NSSound.beep(); return }
            self.s.city = hit.2; self.s.lat = hit.0; self.s.lon = hit.1
            if thenSync { self.s.syncWeather = true; self.syncNow() }
            self.rebuildMenu()
        }
    }

    // MARK: Wallpaper

    private func followTimeOfDay() {
        guard s.wallpaperOn, s.followTime else { return }
        let now = DayTime.current()
        if now.rawValue != s.wallTime || !didApplyOnce { applyWallpaper(now) }
    }

    private func applyWallpaper(_ t: DayTime) {
        didApplyOnce = true
        s.wallpaperOn = true
        s.wallTime = t.rawValue
        Wallpapers.apply(time: t, season: s.weather.season)
        rebuildMenu()
    }

    // MARK: Menu

    private func prompt(_ title: String, _ info: String, _ value: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = info
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = value
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = field
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue.trimmingCharacters(in: .whitespaces) : nil
    }

    private func refreshLiveItems() {
        moodItem?.title = "Mood: \(s.moodWord) · \(Int(s.happy))/100"
        var badge = ""
        if let end = s.focusEnd {
            let mins = max(1, Int(ceil(end.timeIntervalSinceNow / 60)))
            badge = " \(mins)m"
            focusItem?.title = "Stop focus (\(mins) min left)"
        } else {
            focusItem?.title = "Start 25-minute focus"
        }
        if statusItem.button?.title != badge { statusItem.button?.title = badge }
    }

    private func petMenu(_ slot: Int) -> NSMenu {
        let m = NSMenu()
        for (title, kind) in [("Fox", "fox"), ("Cat", "cat"), ("Dog", "dog"), ("Egg", "egg"), ("None", "none")] {
            if kind == "none" { m.addItem(.separator()) }
            m.addItem(ActionItem(title, checked: s.petKind(slot) == kind) { [unowned self] in
                s.setPet(slot, kind); applyPause(); rebuildMenu()
            })
        }
        m.addItem(.separator())
        let hats = NSMenu()
        for (i, title) in ["No hat", "Beanie", "Party hat", "Crown", "Flower"].enumerated() {
            hats.addItem(ActionItem(title, checked: s.hat(slot) == i) { [unowned self] in s.setHat(slot, i); rebuildMenu() })
        }
        m.addItem(sub("Hat", hats))
        let scarves = NSMenu()
        for (title, hex) in [("Default", 0), ("Red", 0xF4727E), ("Teal", 0x4FB7A8), ("Yellow", 0xF7C948), ("Pink", 0xFFA8BE), ("Blue", 0x6FB7E9)] {
            scarves.addItem(ActionItem(title, checked: s.scarf(slot) == hex) { [unowned self] in s.setScarf(slot, hex); rebuildMenu() })
        }
        m.addItem(sub("Scarf or collar colour", scarves))
        let name = s.name(slot)
        m.addItem(ActionItem(name.isEmpty ? "Name…" : "Name: \(name)…") { [unowned self] in
            if let n = prompt("Pet name", "Shown above the pet when you pet it.", name) { s.setName(slot, n); rebuildMenu() }
        })
        return m
    }

    private func rebuildMenu() {
        statusItem.button?.image = NSImage(systemSymbolName: s.weather.symbol, accessibilityDescription: "Tuft")
        statusItem.button?.imagePosition = .imageLeading
        let menu = NSMenu()

        let weather = NSMenu()
        for w in Weather.allCases {
            if w == .off { weather.addItem(.separator()) }
            weather.addItem(ActionItem(w.title, checked: s.weather == w && !s.syncWeather) { [unowned self] in
                setWeather(w, manual: true)
            })
        }
        weather.addItem(.separator())
        let label = s.city.isEmpty ? "Match real weather…" : "Match real weather in \(s.city)"
        weather.addItem(ActionItem(label, checked: s.syncWeather) { [unowned self] in
            if s.syncWeather { s.syncWeather = false; rebuildMenu() }
            else if s.city.isEmpty { chooseCity(thenSync: true) }
            else { s.syncWeather = true; syncNow(); rebuildMenu() }
        })
        weather.addItem(ActionItem("Change city…") { [unowned self] in chooseCity(thenSync: s.syncWeather) })
        menu.addItem(sub("Weather", weather))

        let amount = NSMenu()
        for (title, v) in [("Light", 0.5), ("Normal", 1.0), ("Heavy", 1.8)] {
            amount.addItem(ActionItem(title, checked: s.intensity == v) { [unowned self] in
                s.intensity = v; rebuildMenu()
            })
        }
        menu.addItem(sub("Amount", amount))

        let depth = NSMenu()
        for (title, v) in [("No piling", 0.0), ("Thin", 6.0), ("Medium", 14.0), ("Deep", 26.0)] {
            depth.addItem(ActionItem(title, checked: s.snowCap == v) { [unowned self] in
                s.snowCap = v
                scenes.forEach { $0.refreshPiles() }
                rebuildMenu()
            })
        }
        menu.addItem(sub("Snow depth", depth))

        let wall = NSMenu()
        for t in DayTime.allCases {
            wall.addItem(ActionItem(t.title, checked: s.wallpaperOn && !s.followTime && s.wallTime == t.rawValue) { [unowned self] in
                s.followTime = false
                applyWallpaper(t)
            })
        }
        wall.addItem(.separator())
        wall.addItem(ActionItem("Follow time of day", checked: s.wallpaperOn && s.followTime) { [unowned self] in
            s.followTime = true
            applyWallpaper(DayTime.current())
        })
        wall.addItem(ActionItem("Restore my wallpaper") { [unowned self] in
            s.wallpaperOn = false
            Wallpapers.restore()
            rebuildMenu()
        })
        menu.addItem(sub("Wallpaper", wall))

        let deco = NSMenu()
        for (title, kind) in [("Snow bun", "bun"), ("Little tree", "tree"), ("Lantern", "lantern"), ("Gift", "gift")] {
            deco.addItem(ActionItem("Add \(title.lowercased())") { [unowned self] in
                let m = NSEvent.mouseLocation
                let scene = scenes.first { $0.screenFrame.contains(m) } ?? scenes.first
                scene?.addDecor(kind)
            })
        }
        deco.addItem(ActionItem("Roll a snowball (push it with the pointer)") { [unowned self] in
            scenes.first?.addSnowball()
            applyPause()
        })
        deco.addItem(.separator())
        let hint = NSMenuItem(title: "Drag to move · right-click to remove", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        deco.addItem(hint)
        deco.addItem(ActionItem("Clear all") { [unowned self] in scenes.forEach { $0.clearDecor() } })
        menu.addItem(sub("Decorate", deco))

        menu.addItem(.separator())
        menu.addItem(sub("Pet", petMenu(0)))
        menu.addItem(sub("Second pet", petMenu(1)))
        let home = NSMenu()
        for (title, spot) in [("Both sides of the Dock", "sides"), ("Bottom right", "right"), ("Bottom left", "left"), ("On the Dock", "dock"), ("On the menu bar", "menubar")] {
            home.addItem(ActionItem(title, checked: s.petSpot == spot) { [unowned self] in s.petSpot = spot; rebuildMenu() })
        }
        menu.addItem(sub("Pets live", home))
        menu.addItem(ActionItem("Toys (ball, leaves, burrow, house, bowl)", checked: s.toys) { [unowned self] in
            s.toys.toggle(); rebuildMenu()
        })
        let mood = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        mood.isEnabled = false
        menu.addItem(mood)
        moodItem = mood

        menu.addItem(.separator())
        let focus = ActionItem("") { [unowned self] in
            s.focusEnd = s.focusEnd == nil ? Date().addingTimeInterval(25 * 60) : nil
            refreshLiveItems()
        }
        menu.addItem(focus)
        focusItem = focus
        menu.addItem(ActionItem("Calm while I work", checked: s.calm) { [unowned self] in
            s.calm.toggle(); rebuildMenu()
        })
        menu.addItem(ActionItem("Hide during calls", checked: s.hideOnCalls) { [unowned self] in
            s.hideOnCalls.toggle()
            if !s.hideOnCalls { s.quiet = false; applyPause(); applySound() }
            rebuildMenu()
        })
        menu.addItem(ActionItem("Ambient sound", checked: s.sound) { [unowned self] in
            s.sound.toggle(); applySound(); rebuildMenu()
        })
        menu.addItem(ActionItem("Smooth motion (60 fps)", checked: s.smooth) { [unowned self] in
            s.smooth.toggle(); applyPause(); rebuildMenu()
        })
        menu.addItem(ActionItem("Open at login", checked: SMAppService.mainApp.status == .enabled) { [unowned self] in
            do {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
                else { try SMAppService.mainApp.register() }
            } catch { NSSound.beep() }
            rebuildMenu()
        })

        menu.addItem(.separator())
        menu.addItem(ActionItem(s.paused ? "Resume" : "Pause") { [unowned self] in
            s.paused.toggle(); applyPause(); applySound(); rebuildMenu()
        })
        menu.addItem(ActionItem("Quit Tuft") { NSApp.terminate(nil) })
        statusItem.menu = menu
        refreshLiveItems()
    }

    private func sub(_ title: String, _ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }
}
