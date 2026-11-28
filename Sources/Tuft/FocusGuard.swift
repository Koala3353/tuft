import AppKit
import SpriteKit
import ApplicationServices

/// During a focus session, notices a social media tab in the frontmost browser so a pet can fly up and deal with it.
/// Off unless you turn it on. Nothing it reads is stored or sent anywhere: an address or a window title is compared
/// with your list of sites and then forgotten.
///
/// Two ways of looking, because browsers differ:
/// - Safari and the Chrome family answer when asked for the address of the active tab (macOS asks you to allow it).
/// - Zen, Firefox and their relatives do not, so their window title is read and the close-tab shortcut is sent
///   instead. Both need the Accessibility permission.
enum FocusGuard {
    struct Hit {
        let site: String
        let pid: pid_t
        let bundle: String
        let kind: Int          // 0 Safari, 1 Chrome family, 2 Zen and Firefox family
    }

    static let builtIn = "facebook.com, instagram.com, x.com, twitter.com, tiktok.com, reddit.com, threads.net, threads.com, "
        + "snapchat.com, tumblr.com, pinterest.com, twitch.tv, youtube.com"
    static var siteList: String {
        get { UserDefaults.standard.string(forKey: "guardSites") ?? builtIn }
        set { UserDefaults.standard.set(newValue, forKey: "guardSites") }
    }
    static var sites: [String] {
        siteList.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static let safari: Set<String> = ["com.apple.Safari", "com.apple.SafariTechnologyPreview"]
    static let chromium: Set<String> = ["com.google.Chrome", "com.google.Chrome.canary", "com.brave.Browser", "com.microsoft.edgemac",
                                        "company.thebrowser.Browser", "com.vivaldi.Vivaldi", "com.operasoftware.Opera", "org.chromium.Chromium"]
    static func isGecko(_ id: String) -> Bool {
        let l = id.lowercased()
        return ["zen-browser", "mozilla", "firefox", "librewolf", "waterfox", "floorp"].contains { l.contains($0) }
    }
    static var trusted: Bool { AXIsProcessTrusted() }
    static var geckoRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { isGecko($0.bundleIdentifier ?? "") }
    }
    /// Shows the system's "allow Tuft in Accessibility" prompt.
    static func askForAccess() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    }

    /// One click from the menu: clears any entry left by an older build of Tuft (macOS ignores those), has macOS add
    /// this build to the Accessibility list, and opens that list. All that is left for you is to flip the switch.
    static func setUp() {
        if let id = Bundle.main.bundleIdentifier {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            p.arguments = ["reset", "Accessibility", id]
            p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
            try? p.run()
            p.waitUntilExit()
        }
        askForAccess()
        if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(u) }
    }

    /// The site on your list that this address belongs to, if any.
    static func hostMatch(_ url: String) -> String? {
        guard let host = URL(string: url)?.host?.lowercased() else { return nil }
        return sites.first { host == $0 || host.hasSuffix("." + $0) }
    }

    /// The site on your list that this page title names, if any. Rougher than an address: a title that only
    /// mentions a site counts too.
    static func titleMatch(_ title: String) -> String? {
        let t = title.lowercased()
        for s in sites {
            let base = String(s.split(separator: ".").first ?? "")
            if base == "x" {
                if t == "x" || t.hasSuffix(" / x") || t.hasSuffix("| x") || t.contains(" on x: ") { return s }
                continue
            }
            if base == "reddit", t.contains(": r/") { return s }
            guard base.count >= 4 else { continue }
            if t.range(of: "\\b" + NSRegularExpression.escapedPattern(for: base) + "\\b", options: .regularExpression) != nil { return s }
        }
        return nil
    }

    private static let queue = DispatchQueue(label: "tuft.focusguard")

    private static func script(_ src: String) -> String? {
        var err: NSDictionary?
        let r = NSAppleScript(source: src)?.executeAndReturnError(&err)
        return err == nil ? (r?.stringValue ?? "") : nil
    }

    private static func frontTitle(_ pid: pid_t) -> String? {
        let app = AXUIElementCreateApplication(pid)
        var win: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &win) == .success, let w = win else { return nil }
        var title: CFTypeRef?
        guard AXUIElementCopyAttributeValue(w as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success else { return nil }
        return title as? String
    }

    /// Looks at the frontmost app. Calls back on the main thread with a hit, or nil for "nothing to do".
    static func check(_ done: @escaping (Hit?) -> Void) {
        guard let app = NSWorkspace.shared.frontmostApplication, let id = app.bundleIdentifier else { done(nil); return }
        let pid = app.processIdentifier
        if safari.contains(id) || chromium.contains(id) {
            let isSafari = safari.contains(id)
            let src = "tell application id \"\(id)\" to get URL of \(isSafari ? "current" : "active") tab of front window"
            queue.async {
                let site = script(src).flatMap(hostMatch)
                DispatchQueue.main.async { done(site.map { Hit(site: $0, pid: pid, bundle: id, kind: isSafari ? 0 : 1) }) }
            }
        } else if isGecko(id), trusted {
            queue.async {
                let site = frontTitle(pid).flatMap(titleMatch)
                DispatchQueue.main.async { done(site.map { Hit(site: $0, pid: pid, bundle: id, kind: 2) }) }
            }
        } else {
            done(nil)
        }
    }

    /// Closes the tab, but only if the same site is still the one in front: you may have moved on while the pet flew up.
    static func close(_ hit: Hit) {
        check { now in
            guard let now, now.site == hit.site, now.pid == hit.pid else { return }
            switch hit.kind {
            case 0: queue.async { _ = script("tell application id \"\(hit.bundle)\" to close current tab of front window") }
            case 1:
                let arc = hit.bundle == "company.thebrowser.Browser"
                queue.async {
                    _ = script(arc ? "tell application id \"\(hit.bundle)\" to tell front window to tell active tab to close"
                                   : "tell application id \"\(hit.bundle)\" to close active tab of front window")
                }
            default:                                                     // Command-W, sent to that browser only
                let src = CGEventSource(stateID: .hidSystemState)
                for down in [true, false] {
                    let e = CGEvent(keyboardEventSource: src, virtualKey: 13, keyDown: down)
                    e?.flags = .maskCommand
                    e?.postToPid(hit.pid)
                }
            }
        }
    }

    /// For checking from Terminal: says what Tuft would make of the frontmost app, naming the site but never the page.
    static func report(_ done: @escaping (String) -> Void) {
        let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none"
        let how = safari.contains(id) || chromium.contains(id) ? "asks the browser for the tab's address"
            : isGecko(id) ? (trusted ? "reads the window title" : "needs the Accessibility permission to read the window title") : "not a browser Tuft knows"
        check { hit in done("front app \(id): \(how); match: \(hit?.site ?? "none")") }
    }
}

extension WeatherScene {
    /// A pet rockets up to the top of the frontmost window, tells you off, `hit` runs (closing the tab, or nothing),
    /// and the pet goes back to where it was. Returns false when no pet could go.
    @discardableResult
    func guardFly(word: String, hit: @escaping () -> Void) -> Bool {
        guard screenIndex == 0, !focus.isNull, action(forKey: "guard") == nil,
              let a = actors.first(where: { $0.state != 5 && $0.state != 6 && $0.state != 7 && !$0.inHouse && $0.node.alpha > 0.9 }) else { return false }
        let home = a.node.position, wasBar = a.bar, wasPerch = a.perch, wasSide = a.side
        let k = scaleOf(a) / 0.7
        let dest = CGPoint(x: min(size.width - 70, max(70, focus.minX + focus.width * 0.3)),
                           y: min(size.height - barH - 76 * k, max(120, focus.maxY - 40)))
        guardT = 9                                                       // stays awake for the whole errand
        a.node.removeAllActions()
        a.node.alpha = 1
        a.node.children.filter { $0.name == "ride" }.forEach { $0.removeFromParent() }
        a.trail = false
        toys.first { $0.carrier === a }?.carrier = nil
        go(a, to: dest, style: 2) { $0.bar = false; $0.perch = 0 }
        run(.sequence([.wait(forDuration: 1.75), .run { [weak self, weak a] in
            guard let self, let a else { hit(); return }
            a.state = 4; a.timer = 4
            self.face(a, 5, 0.3)
            self.wiggle(a, 0.32, times: 2)                               // the swat
            self.say(a, word, 1.7)
            self.bits(10, at: CGPoint(x: dest.x + a.dir * 26 * k, y: dest.y + 34 * k), tex: Art.star, size: CGSize(width: 8, height: 8),
                      colors: [0xFF7A7A, 0xFFD65A, 0xFFFFFF], up: 40...180)
            hit()
        }, .wait(forDuration: 1.5), .run { [weak self, weak a] in
            guard let self, let a else { return }
            self.guardT = 3
            self.go(a, to: home, style: 3) { $0.bar = wasBar; $0.perch = wasPerch; $0.side = wasSide }
        }]), withKey: "guard")
        return true
    }
}
