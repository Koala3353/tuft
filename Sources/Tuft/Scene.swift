import AppKit
import SpriteKit

enum Weather: String, CaseIterable {
    case snow, leaves, starfall, rain, sakura, fireflies, off

    var title: String {
        switch self {
        case .snow: return "Snow"
        case .leaves: return "Leaves"
        case .starfall: return "Starfall"
        case .rain: return "Rain"
        case .sakura: return "Sakura"
        case .fireflies: return "Fireflies"
        case .off: return "Off"
        }
    }
    var symbol: String {
        switch self {
        case .snow: return "snowflake"
        case .leaves: return "leaf.fill"
        case .starfall: return "sparkles"
        case .rain: return "cloud.rain.fill"
        case .sakura: return "camera.macro"
        case .fireflies: return "light.min"
        case .off: return "moon.zzz"
        }
    }
    var season: Season {
        switch self {
        case .snow, .off: return .winter
        case .leaves: return .autumn
        case .sakura: return .spring
        case .starfall, .rain, .fireflies: return .summer
        }
    }
}

final class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard
    var weather: Weather { didSet { d.set(weather.rawValue, forKey: "weather") } }
    var intensity: Double { didSet { d.set(intensity, forKey: "intensity") } }
    var followTime: Bool { didSet { d.set(followTime, forKey: "followTime") } }
    var wallpaperOn: Bool { didSet { d.set(wallpaperOn, forKey: "wallpaperOn") } }
    var wallTime: Int { didSet { d.set(wallTime, forKey: "wallTime") } }
    var petSpot: String { didSet { d.set(petSpot, forKey: "petSpot") } }
    var calm: Bool { didSet { d.set(calm, forKey: "calm") } }
    var smooth: Bool { didSet { d.set(smooth, forKey: "smooth") } }
    /// Tallest the snow may pile on a window, in points. 0 turns piling off.
    var snowCap: Double { didSet { d.set(snowCap, forKey: "snowCap") } }
    var toys: Bool { didSet { d.set(toys, forKey: "toys") } }
    var barVisits: Bool { didSet { d.set(barVisits, forKey: "barVisits") } }
    /// Hide weather wherever the active window is, so it only shows around it.
    var behind: Bool { didSet { d.set(behind, forKey: "behind") } }
    var sound: Bool { didSet { d.set(sound, forKey: "sound") } }
    var hideOnCalls: Bool { didSet { d.set(hideOnCalls, forKey: "hideOnCalls") } }
    var syncWeather: Bool { didSet { d.set(syncWeather, forKey: "syncWeather") } }
    var city: String { didSet { d.set(city, forKey: "city") } }
    /// Which of your own scenes to use as wallpaper; empty follows the weather.
    var wallTheme: String { didSet { d.set(wallTheme, forKey: "wallTheme") } }
    var lat: Double { didSet { d.set(lat, forKey: "lat") } }
    var lon: Double { didSet { d.set(lon, forKey: "lon") } }
    /// Pet happiness, 10...100. Petting and play raise it; it drifts down when ignored.
    var happy: Double { didSet { d.set(happy, forKey: "happy") } }
    private var happyAt: Double

    // Runtime only
    var power: Double = 1      // 0.5 on battery or in Low Power Mode
    var paused = false
    var busy = false           // typing right now
    var quiet = false          // hidden because a call is on
    var focusEnd: Date?
    var celebrate = false
    var focusing: Bool { focusEnd != nil }
    var hidden: Bool { paused || quiet }
    var demo = false           // recording the README clips in a stand-alone window

    private init() {
        d.register(defaults: ["weather": "snow", "intensity": 1.0, "pet": "fox", "petSpot": "sides", "calm": true,
                              "followTime": true, "snowCap": 14.0, "toys": true, "barVisits": true, "hideOnCalls": true, "happy": 70.0])
        weather = Weather(rawValue: d.string(forKey: "weather") ?? "snow") ?? .snow
        intensity = d.double(forKey: "intensity")
        followTime = d.bool(forKey: "followTime")
        wallpaperOn = d.bool(forKey: "wallpaperOn")
        wallTime = d.integer(forKey: "wallTime")
        petSpot = d.string(forKey: "petSpot") ?? "sides"
        calm = d.bool(forKey: "calm")
        smooth = d.bool(forKey: "smooth")
        snowCap = d.double(forKey: "snowCap")
        toys = d.bool(forKey: "toys")
        barVisits = d.bool(forKey: "barVisits")
        behind = d.bool(forKey: "behind")
        sound = d.bool(forKey: "sound")
        hideOnCalls = d.bool(forKey: "hideOnCalls")
        syncWeather = d.bool(forKey: "syncWeather")
        city = d.string(forKey: "city") ?? ""
        wallTheme = d.string(forKey: "wallTheme") ?? ""
        lat = d.double(forKey: "lat")
        lon = d.double(forKey: "lon")
        happy = d.double(forKey: "happy")
        happyAt = d.double(forKey: "happyAt")
        if happyAt == 0 { happyAt = Date().timeIntervalSince1970 }
    }

    // Two pet slots, each with its own kind, hat, scarf colour and name.
    func petKind(_ i: Int) -> String { d.string(forKey: "pet\(i)") ?? (i == 0 ? (d.string(forKey: "pet") ?? "fox") : "none") }
    func setPet(_ i: Int, _ v: String) { d.set(v, forKey: "pet\(i)") }
    func hat(_ i: Int) -> Int { d.integer(forKey: "hat\(i)") }
    func setHat(_ i: Int, _ v: Int) { d.set(v, forKey: "hat\(i)") }
    func scarf(_ i: Int) -> Int { d.integer(forKey: "scarf\(i)") }
    func setScarf(_ i: Int, _ v: Int) { d.set(v, forKey: "scarf\(i)") }
    func name(_ i: Int) -> String { d.string(forKey: "name\(i)") ?? "" }
    func setName(_ i: Int, _ v: String) { d.set(v, forKey: "name\(i)") }

    func cheer(_ v: Double) { happy = min(100, happy + v * 0.35) }   // scaled so play alone does not max it in seconds
    /// About one point lost every five minutes, counted even while the app was closed.
    func tickMood() {
        let now = Date().timeIntervalSince1970, gap = now - happyAt
        guard gap > 60 else { return }
        happy = max(10, happy - gap / 300)
        happyAt = now
        d.set(now, forKey: "happyAt")
    }
    var moodWord: String { happy > 70 ? "Happy" : (happy > 35 ? "Content" : "Lonely") }
}

/// A loose toy the pets and the pointer can move: 0 ball, 1 yarn, 2 bone.
final class Toy {
    let node: SKSpriteNode
    let kind: Int
    var v = CGVector.zero
    weak var carrier: PetActor?
    init(node: SKSpriteNode, kind: Int) { self.node = node; self.kind = kind }
}

final class PetActor {
    let slot: Int
    let node: SKSpriteNode
    let label: SKLabelNode
    var key = "", kind = ""
    var frames: [Sprite] = []
    var state = 0          // 0 awake, 1 walking, 2 asleep, 3 happy feet, 4 busy with a toy
    var goal = 0           // 0 none, 1 ball, 2 leaf pile, 3 burrow, 4 the other pet
    var timer: CGFloat = 1.5, dir: CGFloat = -1, anim: CGFloat = 0, cooldown: CGFloat = 0
    var hover: CGFloat = 0, target: CGFloat = 0, z: CGFloat = 0
    var faceIdx = 0, faceTimer: CGFloat = 0, blinkT: CGFloat = 3, squash: CGFloat = 0
    var sit = false, again = false, inHouse = false
    var side = 1           // 0 left of the Dock, 1 right
    var toy: Toy?          // the toy it is after or carrying
    var bar = false        // visiting the menu bar
    var barMix: CGFloat = 0, barT: CGFloat = 0
    init(slot: Int, node: SKSpriteNode, label: SKLabelNode) { self.slot = slot; self.node = node; self.label = label }
}

struct Win {
    let id: Int
    let rect: CGRect   // global, top-left origin
}

enum WindowTracker {
    static func poll() -> [Win] {
        let me = Int(getpid())
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return [] }
        var out: [Win] = []
        for w in list {
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  (w[kCGWindowOwnerPID as String] as? Int) != me,
                  let b = w[kCGWindowBounds as String] as? [String: Any],
                  let r = CGRect(dictionaryRepresentation: b as CFDictionary),
                  r.width > 120, r.height > 60 else { continue }
            if let a = w[kCGWindowAlpha as String] as? Double, a < 0.05 { continue }
            out.append(Win(id: w[kCGWindowNumber as String] as? Int ?? 0, rect: r))
        }
        return out
    }
}

enum Kind { case flake, leaf, petal, drop, splash, meteor, spark, firefly, heart, zzz }

final class Particle {
    let node: SKSpriteNode
    var kind: Kind = .flake
    var vx: CGFloat = 0, vy: CGFloat = 0, tvy: CGFloat = 0
    var phase: CGFloat = 0, life: CGFloat = 0, maxLife: CGFloat = 1, spin: CGFloat = 0, alpha: CGFloat = 1
    var resting = false, restWin = 0
    init(node: SKSpriteNode) { self.node = node }
}

struct Surface {
    let id: Int
    let x0, x1, y: CGFloat
    var ranges: [(CGFloat, CGFloat)]
    func covers(_ x: CGFloat) -> Bool { ranges.contains { x >= $0.0 && x <= $0.1 } }
}

final class WeatherScene: SKScene {
    let screenIndex: Int
    var screenFrame: CGRect
    var debug = false
    /// When the last frame was drawn; the app delegate rebuilds the overlay if this goes stale.
    private(set) var lastFrame = CACurrentMediaTime()
    func touch() { lastFrame = CACurrentMediaTime() }

    private let cw: CGFloat = 4          // snow column width
    private var maxPile: CGFloat { CGFloat(Settings.shared.snowCap) }
    /// The cap varies along the edge so piles settle into soft drifts instead of a flat slab.
    private func capAt(_ id: Int, _ c: Int) -> CGFloat {
        let s = CGFloat(abs(id) % 89), x = CGFloat(c)
        let n = 0.5 + 0.25 * sin(x * 0.11 + s) + 0.15 * sin(x * 0.031 + s * 1.7) + 0.1 * sin(x * 0.37 + s * 0.6)
        return maxPile * (0.35 + 0.65 * n)
    }
    private var dock: CGRect?
    private var parts: [Particle] = [], pool: [Particle] = []
    private var surfaces: [Surface] = []
    private var piles: [Int: [CGFloat]] = [:]
    private var lastRects: [Int: CGRect] = [:]
    private let pileNode = SKShapeNode()
    private let flash = SKSpriteNode(color: .white, size: .zero)
    private var lastTime: TimeInterval = 0
    private var acc: CGFloat = 0, pileTimer: CGFloat = 0, debugTimer: CGFloat = 0
    private var pilesDirty = false
    private var mouse = CGPoint.zero, mouseV = CGVector.zero, stillFor: CGFloat = 0
    private var nextBolt: CGFloat = 8
    private var restCount = 0, fireflyCount = 0

    private(set) var decor: [SKSpriteNode] = []
    private var dragging: SKSpriteNode?
    private var dragOffset = CGPoint.zero

    private var actors: [PetActor] = []
    private var shook = false
    private var keyStreak = 0, lastClick = 9.0, scrollT: CGFloat = 0, userIdle = 0.0, inputT: CGFloat = 0
    private var evKey = false, evCheer = false, evClick = false, evScroll = false, evBack = false, evAway = false
    private var pile: SKSpriteNode?, hole: SKSpriteNode?
    private var toys: [Toy] = []
    private var held: Toy?                 // the toy you are dragging
    private let thread = SKShapeNode()     // the yarn's loose end
    private var threadPts: [CGPoint] = []
    private var ball: SKSpriteNode? { toys.first { $0.kind == 0 }?.node }
    private var house: SKSpriteNode?, bowl: SKSpriteNode?, snowball: SKSpriteNode?
    private var sbV: CGFloat = 0, sbR: CGFloat = 8
    private var propsKey = "", playT: CGFloat = 12
    private var togetherT: CGFloat = 20, wantTogether = false, crossT: CGFloat = 0
    private var barH: CGFloat = 24, notch = false

    /// The frontmost window on this screen; weather is drawn faint over it in calm mode.
    private var focus = CGRect.null
    /// A full-screen window covers this screen, so there is nothing to draw.
    private(set) var covered = false
    private var wind = CGVector.zero
    private var passThrough = true

    var isIdle: Bool {
        Settings.shared.weather == .off && parts.isEmpty && piles.isEmpty && decor.isEmpty && snowball == nil
            && (screenIndex != 0 || (Settings.shared.petKind(0) == "none" && Settings.shared.petKind(1) == "none"))
    }

    init(screen: NSScreen, index: Int) {
        screenIndex = index
        screenFrame = screen.frame
        super.init(size: screen.frame.size)
        scaleMode = .resizeFill
        backgroundColor = .clear
        let top = screen.frame.maxY - screen.visibleFrame.maxY
        barH = top > 10 ? top : 24
        notch = screen.safeAreaInsets.top > 0
        let dockH = screen.visibleFrame.minY - screen.frame.minY
        if dockH > 12 {
            let dd = UserDefaults(suiteName: "com.apple.dock")
            let n = (dd?.array(forKey: "persistent-apps")?.count ?? 8) + (dd?.array(forKey: "persistent-others")?.count ?? 1) + 3
            let width = min(size.width - 40, CGFloat(n) * (dockH - 14) + 30)
            dock = CGRect(x: (size.width - width) / 2, y: 0, width: width, height: dockH - 5)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        pileNode.fillColor = SKColor(white: 1, alpha: 0.96)
        pileNode.strokeColor = .clear
        pileNode.zPosition = 5
        addChild(pileNode)
        flash.anchorPoint = .zero
        flash.size = size
        flash.alpha = 0
        flash.zPosition = 1
        addChild(flash)
        thread.strokeColor = SKColor(cgColor: rgb(0xF79BB8, 0.85)) ?? .systemPink
        thread.lineWidth = 1.4
        thread.lineJoin = .round
        thread.zPosition = 18
        addChild(thread)
        let saved = UserDefaults.standard.array(forKey: "decor") as? [[String: Any]] ?? []
        for e in saved where (e["screen"] as? Int ?? 0) == screenIndex {
            guard let k = e["kind"] as? String, let x = e["x"] as? Double, let y = e["y"] as? Double else { continue }
            addDecor(k, at: CGPoint(x: CGFloat(x) * size.width, y: CGFloat(y) * size.height), animated: false)
        }
    }

    // MARK: Windows and surfaces

    func setWindows(_ wins: [Win], dt: CGFloat) {
        let primaryH = NSScreen.screens.first?.frame.height ?? size.height
        var rects: [(Int, CGRect)] = []
        for w in wins {
            rects.append((w.id, CGRect(x: w.rect.minX - screenFrame.minX, y: primaryH - w.rect.maxY - screenFrame.minY,
                                       width: w.rect.width, height: w.rect.height)))
        }
        focus = .null
        covered = false
        if let f = rects.first(where: { $0.1.intersects(CGRect(origin: .zero, size: size)) })?.1 {
            focus = f
            covered = f.width >= size.width - 1 && f.height >= size.height - 1
        }
        var next: [Surface] = []
        var moved = Set<Int>(), seen = Set<Int>()
        for (i, (id, r)) in rects.enumerated() {
            seen.insert(id)
            if let old = lastRects[id], old != r {
                moved.insert(id)
                if hypot(old.minX - r.minX, old.maxY - r.maxY) > 40 { shook = true }
                shed(id, old: old, new: r, dt: dt)
            }
            lastRects[id] = r
            let top = r.maxY
            guard top > 30, top < size.height - 34, r.maxX > 0, r.minX < size.width else { continue }
            var ranges: [(CGFloat, CGFloat)] = [(max(r.minX + 6, 0), min(r.maxX - 6, size.width))]
            for j in 0..<i {
                let f = rects[j].1
                guard f.minY < top + 2, f.maxY > top + 2 else { continue }
                var cut: [(CGFloat, CGFloat)] = []
                for (a, b) in ranges {
                    if f.maxX <= a || f.minX >= b { cut.append((a, b)); continue }
                    if f.minX > a { cut.append((a, f.minX)) }
                    if f.maxX < b { cut.append((f.maxX, b)) }
                }
                ranges = cut
            }
            ranges = ranges.filter { $0.1 - $0.0 > 8 }
            if !ranges.isEmpty { next.append(Surface(id: id, x0: r.minX, x1: r.maxX, y: top, ranges: ranges)) }
        }
        for id in Array(lastRects.keys) where !seen.contains(id) {
            lastRects[id] = nil
            piles[id] = nil
            pilesDirty = true
        }
        if let d = dock {
            next.append(Surface(id: -2, x0: d.minX, x1: d.maxX, y: d.maxY, ranges: [(d.minX + 8, d.maxX - 8)]))
        }
        let live = Set(next.map { $0.id })
        for p in parts where p.resting && p.restWin != -1 && (moved.contains(p.restWin) || !live.contains(p.restWin)) {
            p.resting = false
            p.restWin = 0
            p.vy = rnd(20, 90)
            p.vx = rnd(-50, 50)
        }
        surfaces = next
        if !moved.isEmpty { pilesDirty = true }
    }

    /// A window moved: the snow on it gets left behind and falls.
    private func shed(_ id: Int, old: CGRect, new: CGRect, dt: CGFloat) {
        guard var h = piles[id] else { return }
        let speed = hypot(new.minX - old.minX, new.maxY - old.maxY) / max(dt, 0.01)
        let frac = min(1, max(0.1, speed / 700))
        var budget = 140
        for c in h.indices where h[c] > 0.6 {
            let lost = h[c] * frac
            h[c] -= lost
            if budget > 0, lost > 0.4, Int.random(in: 0..<2) == 0 {
                budget -= 1
                let p = make(.flake, x: old.minX + CGFloat(c) * cw + 2, y: old.maxY + rnd(1, max(2, lost)))
                p.vx = rnd(-45, 45)
                p.vy = rnd(-10, 70)
            }
        }
        let n = Int(new.width / cw) + 1
        if h.count > n { h.removeLast(h.count - n) }
        if h.count < n { h.append(contentsOf: [CGFloat](repeating: 0, count: n - h.count)) }
        piles[id] = h
    }

    private func surfaceHit(_ x: CGFloat, _ y: CGFloat, margin: CGFloat, snow: Bool) -> (Surface, CGFloat)? {
        for s in surfaces {
            guard y >= s.y - margin, y <= s.y + maxPile + 2, s.covers(x) else { continue }
            var top = s.y
            if snow, let h = piles[s.id] {
                let c = Int((x - s.x0) / cw)
                if c >= 0 && c < h.count { top += h[c] }
            }
            if y <= top { return (s, top) }
        }
        return nil
    }

    private func addSnow(_ s: Surface, _ x: CGFloat) {
        let n = Int((s.x1 - s.x0) / cw) + 1
        var h = piles[s.id] ?? [CGFloat](repeating: 0, count: n)
        if h.count < n { h.append(contentsOf: [CGFloat](repeating: 0, count: n - h.count)) }
        let c = Int((x - s.x0) / cw)
        guard c >= 0, c < h.count else { return }
        h[c] = min(capAt(s.id, c), h[c] + 1.5)
        if c > 0 { h[c - 1] = min(capAt(s.id, c - 1), h[c - 1] + 0.8) }
        if c + 1 < h.count { h[c + 1] = min(capAt(s.id, c + 1), h[c + 1] + 0.8) }
        piles[s.id] = h
        pilesDirty = true
    }

    func refreshPiles() { pilesDirty = true }

    private func rebuildPiles() {
        let melting = Settings.shared.weather != .snow
        var any = false
        for (id, var h) in piles {
            var total: CGFloat = 0
            for c in h.indices {
                if c > 0 {
                    let d = h[c] - h[c - 1]
                    if abs(d) > 2.2 { h[c] -= d * 0.25; h[c - 1] += d * 0.25 }
                }
                if melting { h[c] *= 0.95 }
                let lim = capAt(id, c)
                if h[c] > lim { h[c] = lim }
                total += h[c]
            }
            if !h.isEmpty { h[0] *= 0.85; h[h.count - 1] *= 0.85 }
            if total < 1 { piles[id] = nil } else { piles[id] = h; any = true }
        }
        let path = CGMutablePath()
        for s in surfaces {
            guard let h = piles[s.id] else { continue }
            for (a, b) in s.ranges {
                let c0 = max(0, Int((a - s.x0) / cw)), c1 = min(h.count - 1, Int((b - s.x0) / cw))
                guard c1 > c0 else { continue }
                var open = false
                for c in c0...c1 {
                    let x = s.x0 + CGFloat(c) * cw
                    if h[c] > 0.4 {
                        if !open { path.move(to: CGPoint(x: x, y: s.y)); open = true }
                        path.addLine(to: CGPoint(x: x + cw / 2, y: s.y + h[c]))
                    } else if open {
                        path.addLine(to: CGPoint(x: x, y: s.y)); path.closeSubpath(); open = false
                    }
                }
                if open {
                    path.addLine(to: CGPoint(x: s.x0 + CGFloat(c1 + 1) * cw, y: s.y)); path.closeSubpath()
                }
            }
        }
        pileNode.path = path
        pilesDirty = melting && any
    }

    private func brushPiles(_ speed: CGFloat) {
        guard speed > 40 else { return }
        for s in surfaces where abs(mouse.y - (s.y + 6)) < 16 && mouse.x > s.x0 && mouse.x < s.x1 {
            guard var h = piles[s.id] else { continue }
            let c = Int((mouse.x - s.x0) / cw)
            for k in max(0, c - 3)...min(h.count - 1, max(0, c + 3)) where h[k] > 1 {
                h[k] *= 0.5
                if Int.random(in: 0..<3) == 0 {
                    let p = make(.flake, x: s.x0 + CGFloat(k) * cw, y: s.y + h[k] + 2)
                    p.vx = mouseV.dx * 0.15 + rnd(-30, 30)
                    p.vy = rnd(40, 120)
                }
            }
            piles[s.id] = h
            pilesDirty = true
        }
    }

    // MARK: Particles

    @discardableResult
    private func make(_ kind: Kind, x: CGFloat, y: CGFloat) -> Particle {
        let p: Particle
        if let q = pool.popLast() { p = q } else {
            let n = SKSpriteNode()
            addChild(n)
            p = Particle(node: n)
        }
        let n = p.node
        n.isHidden = false
        n.zRotation = 0
        n.colorBlendFactor = 0
        n.blendMode = .alpha
        n.zPosition = 10
        p.kind = kind; p.resting = false; p.restWin = 0
        p.vx = 0; p.vy = 0; p.tvy = 0; p.spin = 0
        p.phase = rnd(0, 6.28); p.life = 999; p.maxLife = 999; p.alpha = 1
        func use(_ s: Sprite, _ w: CGFloat, _ h: CGFloat) { n.texture = s.tex; n.size = CGSize(width: w, height: h) }
        func tint(_ hexes: [UInt32]) {
            n.color = SKColor(cgColor: rgb(hexes.randomElement()!)) ?? .white
            n.colorBlendFactor = 1
        }
        switch kind {
        case .flake:
            let d = rnd(3, 7)
            use(Art.dot, d, d)
            p.alpha = rnd(0.65, 1)
            p.tvy = -rnd(30, 60) * (d / 4.5)
            p.vy = p.tvy
        case .leaf:
            let k = rnd(0.85, 1.4)
            use(Art.leaf, 16 * k, 10 * k)
            tint([0xE2703A, 0xD9A53C, 0xC9492F, 0xB5651D, 0xE8B84A])
            p.tvy = -rnd(45, 85); p.vy = p.tvy; p.spin = rnd(-2.5, 2.5)
        case .petal:
            let k = rnd(0.8, 1.3)
            use(Art.petal, 10 * k, 8 * k)
            tint([0xFFD1E0, 0xFFB7CE, 0xFFE4EC])
            p.tvy = -rnd(28, 55); p.vy = p.tvy; p.spin = rnd(-2, 2)
        case .drop:
            use(Art.streak, 1.6, rnd(12, 20))
            tint([0xCFE6FF])
            p.alpha = 0.45
            p.vx = -150; p.vy = -rnd(1100, 1400); p.tvy = p.vy
            n.zRotation = atan2(p.vy, p.vx) + .pi / 2
        case .splash:
            use(Art.dot, 3, 3)
            p.alpha = 0.6; p.life = rnd(0.25, 0.45); p.maxLife = p.life
        case .meteor:
            use(Art.streak, 3.5, rnd(70, 120))
            n.blendMode = .add
            p.vx = -rnd(380, 560); p.vy = -rnd(300, 480); p.life = 8
            n.zRotation = atan2(p.vy, p.vx) + .pi / 2
        case .spark:
            let d = rnd(5, 11)
            use(Art.glow, d, d)
            n.blendMode = .add
            tint([0xFFF3B0, 0xBFE3FF, 0xFFD1F0])
            p.life = rnd(0.6, 1.3); p.maxLife = p.life
        case .firefly:
            let d = rnd(9, 15)
            use(Art.glow, d, d)
            n.blendMode = .add
            tint([0xE8FF8A, 0xFFF59A])
            p.spin = rnd(0, 6.28)   // blink phase
            p.tvy = 0               // fade-in progress
            p.alpha = 0
        case .heart:
            use(Art.heart, 14, 14)
            p.vy = 36; p.life = 1.3; p.maxLife = 1.3
        case .zzz:
            use(Art.zzz, 9, 9)
            p.vx = 7; p.vy = 16; p.life = 1.9; p.maxLife = 1.9
        }
        n.alpha = p.alpha
        n.position = CGPoint(x: x, y: y)
        parts.append(p)
        return p
    }

    private func spawn(_ dt: CGFloat) {
        let s = Settings.shared
        let k = CGFloat(s.intensity * s.power) * size.width / 1440 * (s.busy && s.calm ? 0.4 : 1) * (s.focusing ? 0.3 : 1)
        let w = size.width, h = size.height
        func emit(_ rate: CGFloat, _ f: () -> Void) {
            acc += rate * dt
            while acc >= 1 { acc -= 1; f() }
        }
        switch s.weather {
        case .snow: emit(22 * k) { make(.flake, x: rnd(-20, w + 20), y: h + 8) }
        case .leaves: emit(4 * k) { make(.leaf, x: rnd(-20, w + 60), y: h + 8) }
        case .sakura: emit(7 * k) { make(.petal, x: rnd(-20, w + 60), y: h + 8) }
        case .rain:
            emit(120 * k) { make(.drop, x: rnd(0, w + 160), y: h + 10) }
            nextBolt -= dt
            if nextBolt <= 0 {
                nextBolt = rnd(12, 30)
                flash.run(.sequence([.fadeAlpha(to: s.calm ? 0.05 : 0.16, duration: 0.04), .fadeAlpha(to: 0.01, duration: 0.08),
                                     .fadeAlpha(to: s.calm ? 0.03 : 0.1, duration: 0.04), .fadeAlpha(to: 0, duration: 0.3)]))
            }
        case .starfall: emit(0.7 * k) { make(.meteor, x: rnd(w * 0.2, w * 1.3), y: h + 40) }
        case .fireflies:
            if fireflyCount < Int(26 * k) { make(.firefly, x: rnd(0, w), y: rnd(40, h - 60)) }
        case .off: break
        }
    }

    private func step(_ dt: CGFloat, t: CGFloat, speed: CGFloat) {
        let w = size.width, h = size.height, weather = Settings.shared.weather
        let mouseIn = mouse.x >= 0 && mouse.x <= w && mouse.y >= 0 && mouse.y <= h
        let dim = Settings.shared.calm && !focus.isNull
        let behind = Settings.shared.behind && !focus.isNull
        var resting = 0, flies = 0
        var i = 0
        while i < parts.count {
            let p = parts[i], n = p.node
            var pos = n.position
            var dead = false
            var a = p.alpha
            switch p.kind {
            case .flake, .leaf, .petal:
                if p.resting {
                    resting += 1
                    p.life -= dt
                    if speed > 60, abs(pos.x - mouse.x) < 55, abs(pos.y - mouse.y) < 55 {
                        p.resting = false; p.restWin = 0
                        p.vx = mouseV.dx * 0.35 + rnd(-70, 70)
                        p.vy = rnd(120, 260)
                    }
                    if p.life < 2 { a = p.alpha * max(0, p.life / 2) }
                    dead = p.life <= 0
                } else {
                    let amp: CGFloat = p.kind == .flake ? 18 : 55
                    let sway = sin(p.phase + t * 1.3) * amp
                    p.vx += (sway - p.vx) * min(1, 2.5 * dt)
                    p.vy += (p.tvy - p.vy) * min(1, 2 * dt)
                    if mouseIn {
                        let dx = pos.x - mouse.x, dy = pos.y - mouse.y, d2 = dx * dx + dy * dy
                        if d2 < 8100, d2 > 1 {
                            // Pushed aside by the pointer and dragged along by its motion.
                            let d = sqrt(d2), f = (1 - d / 90) * dt
                            p.vx += (dx / d * 520 + wind.dx * 2.2) * f
                            p.vy += (dy / d * 520 + wind.dy * 2.2) * f
                        }
                    }
                    pos.x += p.vx * dt; pos.y += p.vy * dt
                    n.zRotation += p.spin * dt
                    if p.vy < 0, let (s, top) = surfaceHit(pos.x, pos.y, margin: 10, snow: p.kind == .flake) {
                        if p.kind == .flake { addSnow(s, pos.x); dead = true } else {
                            p.resting = true; p.restWin = s.id
                            pos.y = top + rnd(2, 5)
                            n.zRotation = rnd(-0.35, 0.35)
                            p.life = restCount > 220 ? 4 : (p.kind == .leaf ? rnd(40, 70) : rnd(18, 35))
                        }
                    } else if pos.y < 6 {
                        if p.kind == .flake { dead = pos.y < -8 } else {
                            p.resting = true; p.restWin = -1
                            pos.y = rnd(3, 9)
                            n.zRotation = rnd(-0.35, 0.35)
                            p.life = restCount > 220 ? 4 : rnd(25, 50)
                        }
                    }
                    if pos.x < -60 || pos.x > w + 80 { dead = true }
                }
            case .drop:
                pos.x += p.vx * dt; pos.y += p.vy * dt
                if let (_, top) = surfaceHit(pos.x, pos.y, margin: 28, snow: false) {
                    for _ in 0..<2 {
                        let s = make(.splash, x: pos.x, y: top + 1)
                        s.vx = rnd(-70, 70); s.vy = rnd(70, 170)
                    }
                    dead = true
                } else if pos.y < -20 { dead = true }
            case .splash, .spark:
                p.vy -= (p.kind == .splash ? 700 : 260) * dt
                pos.x += p.vx * dt; pos.y += p.vy * dt
                p.life -= dt
                a = p.alpha * max(0, p.life / p.maxLife)
                dead = p.life <= 0
            case .meteor:
                pos.x += p.vx * dt; pos.y += p.vy * dt
                p.life -= dt
                if Int.random(in: 0..<3) == 0 {
                    let s = make(.spark, x: pos.x + rnd(-2, 2), y: pos.y + rnd(-2, 2))
                    s.life = 0.35; s.maxLife = 0.35
                    s.node.size = CGSize(width: 4, height: 4)
                }
                let hit = surfaceHit(pos.x, pos.y, margin: 14, snow: false)
                if hit != nil || pos.y < 10 || p.life <= 0 {
                    if pos.x > -20 && pos.x < w + 20 {
                        for _ in 0..<16 {
                            let s = make(.spark, x: pos.x, y: (hit?.1 ?? pos.y) + 2)
                            let a = rnd(0.15, 2.99), v = rnd(60, 260)
                            s.vx = cos(a) * v; s.vy = sin(a) * v
                        }
                    }
                    dead = true
                }
                if pos.x < -200 { dead = true }
            case .firefly:
                flies += 1
                p.phase += dt * rnd(0.4, 1.6)
                var ax = cos(p.phase) * 30, ay = sin(p.phase * 1.3) * 22
                if stillFor > 0.8, mouseIn {
                    let dx = mouse.x - pos.x, dy = mouse.y - pos.y, d = max(1, hypot(dx, dy))
                    if d < 420 {
                        if d > 46 { ax += dx / d * 75; ay += dy / d * 75 } else { ax += -dy / d * 45; ay += dx / d * 45 }
                    }
                }
                p.vx += (ax - p.vx) * min(1, 1.5 * dt)
                p.vy += (ay - p.vy) * min(1, 1.5 * dt)
                pos.x += p.vx * dt; pos.y += p.vy * dt
                if pos.x < -20 { pos.x = w + 20 } else if pos.x > w + 20 { pos.x = -20 }
                pos.y = min(h - 20, max(20, pos.y))
                if weather == .fireflies { p.tvy = min(1, p.tvy + dt) } else { p.tvy -= dt; dead = p.tvy <= 0 }
                let blink = sin(t * 1.7 + p.spin)
                a = max(0, p.tvy) * (0.3 + 0.7 * blink * blink)
            case .heart, .zzz:
                pos.x += p.vx * dt
                pos.y += p.vy * dt
                p.life -= dt
                a = max(0, p.life / p.maxLife)
                dead = p.life <= 0
            }
            if dead {
                n.isHidden = true
                pool.append(p)
                parts.swapAt(i, parts.count - 1)
                parts.removeLast()
            } else {
                n.position = pos
                n.alpha = (dim || behind) && p.kind != .heart && p.kind != .zzz && focus.contains(pos) ? (behind ? 0 : a * 0.18) : a
                i += 1
            }
        }
        if pool.count > 400 {
            for q in pool.suffix(150) { q.node.removeFromParent() }
            pool.removeLast(150)
        }
        restCount = resting
        fireflyCount = flies
    }

    // MARK: Decorations

    @discardableResult
    func addDecor(_ kind: String, at point: CGPoint? = nil, animated: Bool = true) -> SKSpriteNode {
        let s = Art.decor(kind)
        let n = SKSpriteNode(texture: s.tex, size: s.size)
        n.anchorPoint = CGPoint(x: 0.5, y: 0)
        n.name = kind
        n.zPosition = 20
        let ground = (dock?.maxY ?? 0) - 3
        n.position = point ?? CGPoint(x: size.width / 2 + rnd(-220, 220), y: ground)
        addChild(n)
        decor.append(n)
        if kind == "bun" {
            n.run(.repeatForever(.sequence([.scaleY(to: 0.97, duration: 1.1), .scaleY(to: 1.0, duration: 1.1)])))
        }
        if animated {
            n.setScale(0.1)
            n.run(.sequence([.scale(to: 1.12, duration: 0.18), .scale(to: 1, duration: 0.1)]))
            saveDecor()
        }
        return n
    }

    func clearDecor() {
        decor.forEach { $0.removeFromParent() }
        decor = []
        saveDecor()
    }

    private func saveDecor() {
        var all = (UserDefaults.standard.array(forKey: "decor") as? [[String: Any]] ?? [])
            .filter { ($0["screen"] as? Int ?? 0) != screenIndex }
        for n in decor {
            all.append(["kind": n.name ?? "bun", "x": Double(n.position.x / size.width),
                        "y": Double(n.position.y / size.height), "screen": screenIndex])
        }
        UserDefaults.standard.set(all, forKey: "decor")
    }

    private func decorAt(_ p: CGPoint) -> SKSpriteNode? {
        decor.last { $0.frame.insetBy(dx: 4, dy: 2).contains(p) }
    }

    override func mouseDown(with event: NSEvent) {
        let p = event.location(in: self)
        if decorAt(p) == nil, let t = toyAt(p) {                   // pick up a toy
            if let c = t.carrier { face(c, 5, 0.6) }
            held = t; t.carrier = nil; t.v = .zero
            return
        }
        guard let n = decorAt(p) else { return }
        if event.modifierFlags.contains(.control) || event.modifierFlags.contains(.option) { remove(n); return }
        dragging = n
        dragOffset = CGPoint(x: n.position.x - p.x, y: n.position.y - p.y)
        n.zPosition = 21
    }

    override func mouseDragged(with event: NSEvent) {
        if let t = held {
            let q = event.location(in: self)
            t.node.position = CGPoint(x: min(size.width - 10, max(10, q.x)), y: max(groundY(q.x) + 10, q.y))
            return
        }
        guard let n = dragging else { return }
        let p = event.location(in: self)
        n.position = CGPoint(x: min(size.width - 10, max(10, p.x + dragOffset.x)),
                             y: min(size.height - 60, max(0, p.y + dragOffset.y)))
    }

    override func mouseUp(with event: NSEvent) {
        if let t = held {                                          // let go: it keeps the pointer's speed
            t.v = CGVector(dx: wind.dx * 0.6, dy: max(-200, min(520, wind.dy * 0.6)))
            held = nil
            excite(t)
            return
        }
        guard let n = dragging else { return }
        n.zPosition = 20
        dragging = nil
        saveDecor()
    }

    override func rightMouseDown(with event: NSEvent) {
        if let n = decorAt(event.location(in: self)) { remove(n) }
    }

    private func remove(_ n: SKSpriteNode) {
        decor.removeAll { $0 === n }
        n.run(.sequence([.scale(to: 0.1, duration: 0.15), .removeFromParent()]))
        for _ in 0..<8 {
            let p = make(.flake, x: n.position.x + rnd(-14, 14), y: n.position.y + rnd(10, 50))
            p.vx = rnd(-80, 80); p.vy = rnd(40, 140)
        }
        saveDecor()
    }

    // MARK: Pets

    private var spot: String { Settings.shared.petSpot }
    private var onBar: Bool { spot == "menubar" }
    private var petScale: CGFloat { onBar ? max(0.26, (barH - 3) / 84) : 0.7 }

    private func groundY(_ x: CGFloat) -> CGFloat {
        if onBar { return size.height - barH + 1 }
        if let d = dock, x > d.minX + 6, x < d.maxX - 6 { return d.maxY - 4 }
        return -3
    }

    /// The strips of desktop to the left and right of the Dock.
    private func sideZones() -> (ClosedRange<CGFloat>, ClosedRange<CGFloat>)? {
        guard let d = dock else { return nil }
        let l0 = max(30, d.minX - 300), l1 = d.minX - 24, r0 = d.maxX + 24, r1 = min(size.width - 30, d.maxX + 300)
        guard l1 - l0 > 120, r1 - r0 > 120 else { return nil }
        return (l0...l1, r0...r1)
    }

    /// Pets keep to a small home stretch so they never wander over your work.
    private func petZone(_ side: Int = 1) -> ClosedRange<CGFloat> {
        let w = size.width
        switch spot {
        case "sides":
            if let z = sideZones() { return side == 0 ? z.0 : z.1 }
            return (w - 340)...(w - 40)
        case "left": return 40...340
        case "menubar": return barZone()
        case "dock":
            if let d = dock, d.width > 160 { return (d.minX + 36)...(d.maxX - 36) }
            return (w - 340)...(w - 40)
        default: return (w - 340)...(w - 40)
        }
    }

    private var barScale: CGFloat { max(0.26, (barH - 3) / 84) }
    private func barZone() -> ClosedRange<CGFloat> {
        let w = size.width
        return 70...(w - 70)          // the whole bar; behind a notch they are simply out of sight for a moment
    }
    private func scaleOf(_ a: PetActor) -> CGFloat { onBar ? barScale : 0.7 + (barScale - 0.7) * a.barMix }
    private func groundFor(_ a: PetActor, _ x: CGFloat) -> CGFloat { a.bar ? size.height - barH + 1 : groundY(x) }
    private func zoneFor(_ a: PetActor) -> ClosedRange<CGFloat> { a.bar ? barZone() : petZone(a.side) }

    /// Send a pet up to the menu bar or back down: half the time a puff of magic, half the time a balloon ride.
    private func travel(_ a: PetActor, toBar: Bool) {
        let n = a.node
        let z = toBar ? barZone() : petZone(a.side)
        let x = toBar ? min(z.upperBound, max(z.lowerBound, n.position.x + rnd(-260, 260))) : rnd(z.lowerBound, z.upperBound)
        let dest = CGPoint(x: x, y: toBar ? size.height - barH + 1 : groundY(x))
        a.state = 4; a.goal = 0; a.sit = false
        n.removeAction(forKey: "hop")
        let sparkle: (CGPoint) -> Void = { [weak self] pt in
            self?.bits(8, at: CGPoint(x: pt.x, y: pt.y + 16), tex: Art.star, size: CGSize(width: 7, height: 7),
                       colors: [0xFFFFFF, 0xFFE9A8], up: 60...200)
        }
        let land = SKAction.run { [weak self, weak a] in
            guard let self, let a else { return }
            a.state = 0; a.timer = 1.5; a.barT = rnd(20, 45)
            self.face(a, 4, 1.4); a.squash = 0.22
            a.node.childNode(withName: "balloon")?.removeFromParent()
        }
        if Bool.random() {
            a.timer = 1.6
            face(a, 5, 0.4)
            sparkle(n.position)
            n.run(.sequence([.fadeOut(withDuration: 0.2), .wait(forDuration: 0.5),
                             .run { [weak a] in
                                 guard let a else { return }
                                 a.bar = toBar; a.barMix = toBar ? 1 : 0
                                 a.node.position = dest
                                 sparkle(dest)
                             },
                             .fadeIn(withDuration: 0.2), land]))
        } else {
            a.timer = 4.2
            a.bar = toBar
            face(a, 4, 3.4)
            let b = SKSpriteNode(texture: Art.balloon.tex, size: Art.balloon.size)
            b.name = "balloon"
            b.anchorPoint = CGPoint(x: 0.5, y: 0)
            b.position = CGPoint(x: 0, y: 86)
            b.zPosition = -1
            n.addChild(b)
            let move = SKAction.move(to: dest, duration: 3.4)
            move.timingMode = .easeInEaseOut
            n.run(.sequence([move, land]))
        }
    }

    private func zoneAt(_ x: CGFloat) -> ClosedRange<CGFloat> {
        if spot == "sides", sideZones() != nil { return petZone(x < size.width / 2 ? 0 : 1) }
        return petZone(1)
    }

    @discardableResult
    private func emote(_ sp: Sprite, x: CGFloat, y: CGFloat) -> Particle {
        let p = make(.heart, x: x, y: y)
        p.node.texture = sp.tex
        p.node.size = sp.size
        p.vx = rnd(-8, 8)
        return p
    }

    /// A burst of small tinted bits (leaves, dirt, tears) that arc and fade.
    private func bits(_ count: Int, at c: CGPoint, tex: Sprite, size: CGSize, colors: [UInt32], up: ClosedRange<CGFloat>) {
        for _ in 0..<count {
            let q = make(.splash, x: c.x + rnd(-12, 12), y: c.y + rnd(0, 8))
            q.node.texture = tex.tex
            q.node.size = size
            q.node.color = SKColor(cgColor: rgb(colors.randomElement()!)) ?? .white
            q.node.colorBlendFactor = 1
            q.node.zRotation = rnd(0, 6)
            q.alpha = 1; q.life = rnd(0.6, 1.1); q.maxLife = q.life
            q.vx = rnd(-110, 110); q.vy = rnd(up.lowerBound, up.upperBound)
        }
    }

    private func face(_ a: PetActor, _ f: Int, _ t: CGFloat) { a.faceIdx = f; a.faceTimer = t }

    /// The other pet, when it is on the same side of the Dock.
    private func buddy(_ a: PetActor) -> PetActor? { actors.first { $0 !== a && $0.side == a.side && $0.bar == a.bar } }

    private func hop(_ a: PetActor, height: CGFloat = 22, times: Int = 1) {
        guard a.state != 1, a.node.action(forKey: "hop") == nil else { return }
        let h = height * scaleOf(a) / 0.7
        let up = SKAction.moveBy(x: 0, y: h, duration: 0.17), down = SKAction.moveBy(x: 0, y: -h, duration: 0.17)
        up.timingMode = .easeOut; down.timingMode = .easeIn
        a.node.run(.repeat(.sequence([up, down, .run { [weak a] in a?.squash = 0.16 }]), count: times), withKey: "hop")
    }

    private func wiggle(_ a: PetActor, _ amp: CGFloat = 0.14, times: Int = 1) {
        a.node.run(.sequence([.repeat(.sequence([.rotate(toAngle: amp, duration: 0.09), .rotate(toAngle: -amp, duration: 0.16)]),
                                      count: times), .rotate(toAngle: 0, duration: 0.09)]), withKey: "wig")
    }

    private func secs(_ t: CGEventType) -> Double {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: t)
    }

    /// Reads only how long ago the last key, click or scroll happened, never what was typed.
    private func pollInput() {
        let key = secs(.keyDown), click = secs(.leftMouseDown), scroll = secs(.scrollWheel)
        let any = min(key, click, scroll, secs(.mouseMoved))
        evBack = userIdle > 40 && any < 1
        evAway = any > 40 && !Settings.shared.demo
        userIdle = any
        evKey = key < 0.13
        if evKey { keyStreak += 1 } else if key > 2.5 {
            evCheer = keyStreak > 120
            keyStreak = 0
        }
        evClick = click < 0.13 && lastClick >= 0.13
        lastClick = click
        if scroll < 0.13 {
            scrollT += 0.1
            if scrollT > 0.7 { evScroll = true; scrollT = -2.5 }
        } else { scrollT = min(0, scrollT + 0.1) }
    }

    // Toys. With pets on both sides of the Dock, the right side gets a burrow, leaf pile and ball and the
    // left side a little house and a food bowl; the burrow and the house are the two ends of a shortcut.
    private func syncProps() {
        let want = Settings.shared.toys && !onBar && !actors.isEmpty
        let twoSided = spot == "sides" && sideZones() != nil
        let rz = petZone(1)
        let key = want ? "\(spot)|\(twoSided)|\(Int(rz.lowerBound))" : ""
        guard key != propsKey else { return }
        propsKey = key
        [pile, hole, house, bowl].forEach { $0?.removeFromParent() }
        toys.forEach { $0.node.removeFromParent() }
        toys = []; held = nil; threadPts = []; thread.path = nil
        pile = nil; hole = nil; house = nil; bowl = nil
        guard want else { return }
        func add(_ sp: Sprite, _ zone: ClosedRange<CGFloat>, _ fx: CGFloat, _ dy: CGFloat, _ z: CGFloat) -> SKSpriteNode {
            let n = SKSpriteNode(texture: sp.tex, size: sp.size)
            let x = zone.lowerBound + (zone.upperBound - zone.lowerBound) * fx
            n.position = CGPoint(x: x, y: groundY(x) + dy)
            n.zPosition = z
            addChild(n)
            return n
        }
        if spot != "dock" { hole = add(Art.hole, rz, 0.12, 13, 19) }
        pile = add(Art.pile, rz, 0.52, 15, 23)
        func toy(_ kind: Int, _ sp: Sprite, _ zone: ClosedRange<CGFloat>, _ fx: CGFloat) {
            toys.append(Toy(node: add(sp, zone, fx, kind == 2 ? 7 : 12, 23), kind: kind))
        }
        toy(0, Art.ball, rz, 0.88)
        toy(1, Art.yarn, rz, 0.68)
        if twoSided {
            let lz = petZone(0)
            house = add(Art.house, lz, 0.82, 26, 19)
            bowl = add(Art.bowl, lz, 0.35, 10, 23)
            toy(2, Art.bone, lz, 0.58)
        } else {
            toy(2, Art.bone, rz, 0.3)
        }
    }

    private func toyAt(_ p: CGPoint) -> Toy? {
        toys.last { hypot($0.node.position.x - p.x, $0.node.position.y - p.y) < 14 }
    }

    /// Send every free pet near a toy running after it.
    private func excite(_ t: Toy) {
        let x = t.node.position.x
        for a in actors where (a.state == 0 || a.state == 3) && a.cooldown <= 0 && !a.bar {
            let z = petZone(a.side)
            guard x > z.lowerBound - 120, x < z.upperBound + 120 else { continue }
            a.state = 1; a.goal = 1; a.toy = t; a.sit = false; a.again = false
            face(a, 5, 0.4)
        }
    }

    private func updateToys(_ dt: CGFloat, speed: CGFloat) {
        let k = petScale / 0.7
        for t in toys {
            let n = t.node
            if let c = t.carrier {                                  // carried in a pet's mouth
                if c.state == 1, c.goal == 9 {
                    n.position = CGPoint(x: c.node.position.x + c.dir * 26 * k, y: c.node.position.y + 24 * k)
                    continue
                }
                t.carrier = nil
            }
            if held === t { continue }
            var p = n.position
            let zone = zoneAt(p.x), r: CGFloat = t.kind == 2 ? 7 : 12
            let floor = groundY(p.x) + r
            if abs(mouse.x - p.x) < 16, abs(mouse.y - p.y) < 16, speed > 400 {     // swat it with the pointer
                t.v = CGVector(dx: max(-280, min(280, wind.dx * 0.4)), dy: 170)
                excite(t)
            }
            guard t.v != .zero || p.y > floor + 0.5 else { continue }
            t.v.dy -= 620 * dt
            p.x += t.v.dx * dt; p.y += t.v.dy * dt
            if p.y <= floor {
                p.y = floor
                t.v.dy = abs(t.v.dy) > 50 ? -t.v.dy * (t.kind == 0 ? 0.5 : 0.22) : 0
                t.v.dx *= max(0, 1 - (t.kind == 0 ? 2.2 : 4) * dt)
                if abs(t.v.dx) < 4, t.v.dy == 0 { t.v = .zero }
            }
            if p.x < zone.lowerBound { p.x = zone.lowerBound; t.v.dx = abs(t.v.dx) }
            else if p.x > zone.upperBound { p.x = zone.upperBound; t.v.dx = -abs(t.v.dx) }
            n.zRotation -= t.v.dx / (t.kind == 2 ? 30 : 9) * dt
            n.position = p
        }
        if let h = held { excite(h) }                               // dangle a toy and they come running

        // The yarn leaves a loose thread behind it as it moves.
        if let y = toys.first(where: { $0.kind == 1 }) {
            let q = CGPoint(x: y.node.position.x, y: y.node.position.y - 8)
            if threadPts.isEmpty || hypot(q.x - threadPts.last!.x, q.y - threadPts.last!.y) > 7 {
                threadPts.append(q)
                if threadPts.count > 34 { threadPts.removeFirst() }
                let path = CGMutablePath()
                path.addLines(between: threadPts)
                thread.path = path
            }
        }
    }

    /// A snowball you roll with the pointer. It grows as it rolls and turns into a snowman when big enough.
    func addSnowball() {
        snowball?.removeFromParent()
        let n = SKSpriteNode(texture: Art.snowball.tex, size: CGSize(width: 16, height: 16))
        n.zPosition = 21
        let x = size.width / 2 + rnd(-160, 160)
        n.position = CGPoint(x: x, y: groundY(x) + 11)
        addChild(n)
        snowball = n; sbR = 8; sbV = 0
    }

    private func updateSnowball(_ dt: CGFloat) {
        guard let b = snowball else { return }
        var p = b.position
        if abs(mouse.x - p.x) < sbR + 8, abs(mouse.y - p.y) < sbR + 10, abs(wind.dx) > 60 {
            sbV = max(-340, min(340, wind.dx * 0.5))                       // push it with the pointer
        }
        if abs(sbV) > 2 {
            let d = sbV * dt
            p.x += d
            sbR = min(26, sbR + abs(d) * (Settings.shared.weather == .snow ? 0.024 : 0.012))
            b.zRotation -= d / sbR
            sbV *= max(0, 1 - 1.3 * dt)
            if p.x < 30 { p.x = 30; sbV = abs(sbV) } else if p.x > size.width - 30 { p.x = size.width - 30; sbV = -abs(sbV) }
        }
        p.y += (groundY(p.x) + 3 + sbR - p.y) * min(1, 14 * dt)
        b.size = CGSize(width: sbR * 2, height: sbR * 2)
        b.position = p
        if sbR >= 26 {
            b.removeFromParent()
            snowball = nil
            let sm = addDecor("snowman", at: CGPoint(x: p.x, y: groundY(p.x) + 2))
            bits(10, at: CGPoint(x: p.x, y: sm.position.y + 40), tex: Art.star, size: CGSize(width: 8, height: 8),
                 colors: [0xFFFFFF], up: 120...260)
            Settings.shared.cheer(5)
        }
    }

    private func updatePets(_ dt: CGFloat, t: CGFloat, speed: CGFloat) {
        guard screenIndex == 0 else { return }
        let st = Settings.shared
        let zone = petZone(1)
        for slot in 0..<2 {
            let kind = st.petKind(slot)
            let key = "\(kind)|\(st.hat(slot))|\(st.scarf(slot))|\(spot)"
            let idx = actors.firstIndex { $0.slot == slot }
            if let i = idx, actors[i].key == key { continue }
            if let i = idx {
                actors[i].node.removeFromParent(); actors[i].label.removeFromParent()
                actors.remove(at: i)
            }
            guard kind != "none" else { continue }
            let frames = Art.pet(kind, hat: st.hat(slot), scarf: st.scarf(slot))
            let n = SKSpriteNode(texture: frames[0].tex, size: frames[0].size)
            n.anchorPoint = CGPoint(x: 0.5, y: 0)
            n.zPosition = 22
            let startSide = (slot == 1 && spot == "sides" && sideZones() != nil) ? 0 : 1
            let sz = startSide == 1 ? zone : petZone(0)
            let x = (sz.lowerBound + sz.upperBound) / 2 + (slot == 0 ? -55 : 55)
            n.position = CGPoint(x: x, y: groundY(x))
            addChild(n)
            let l = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            l.fontSize = 11; l.fontColor = .white; l.alpha = 0; l.zPosition = 30
            addChild(l)
            let a = PetActor(slot: slot, node: n, label: l)
            a.key = key; a.kind = kind; a.frames = frames
            a.side = startSide
            a.faceIdx = 4; a.faceTimer = 1.2; a.squash = 0.3
            actors.append(a)
        }
        syncProps()
        updateToys(dt, speed: speed)
        updateSnowball(dt)
        guard !actors.isEmpty else { return }

        inputT += dt
        if inputT >= 0.1 { inputT = 0; pollInput() }

        if st.celebrate {                       // focus session finished
            st.celebrate = false
            for a in actors {
                a.state = 0; a.timer = 3; a.sit = false; a.goal = 0
                face(a, 4, 3); hop(a, times: 4)
                let p = a.node.position
                emote(Art.star, x: p.x - 10, y: p.y + 60); emote(Art.heart, x: p.x + 10, y: p.y + 70)
                for _ in 0..<14 {
                    let sp = make(.spark, x: p.x, y: p.y + 40)
                    let ang = rnd(0.3, 2.84), v = rnd(80, 260)
                    sp.vx = cos(ang) * v; sp.vy = sin(ang) * v
                }
            }
        }
        for a in actors { updateActor(a, dt, t: t, speed: speed, zone: zoneFor(a)) }

        if actors.count == 2 {                  // now and then one goes over to play with the other
            togetherT -= dt
            crossT -= dt
            if togetherT <= 0 { togetherT = rnd(35, 70); wantTogether = Bool.random() }
            let p0 = actors[0], p1 = actors[1]
            if house != nil, hole != nil, !p0.bar, !p1.bar, (p0.side == p1.side) != wantTogether, crossT <= 0,
               !st.busy, !st.focusing {
                let mover = Bool.random() ? p0 : p1
                if mover.state == 0, let door = mover.side == 1 ? hole : house {
                    mover.state = 1; mover.goal = 5; mover.sit = false; mover.target = door.position.x
                    crossT = 8
                }
            }
            playT -= dt
            if playT <= 0 {
                playT = rnd(7, 15)
                let a = actors[0], b = actors[1]
                if a.state == 0, b.state == 0, !st.busy, !st.focusing {
                    let ax = a.node.position.x, bx = b.node.position.x
                    if a.side == b.side, !a.bar, !b.bar {
                        a.state = 1; a.sit = false
                        a.goal = 4; a.target = bx + (ax < bx ? -58 : 58) * scaleOf(a) / 0.7
                    }
                }
            }
        }
        evKey = false; evCheer = false; evClick = false; evScroll = false; evBack = false; shook = false
    }

    /// The pet reached whatever it was walking to.
    private func arrive(_ a: PetActor, _ p: CGPoint, zone: ClosedRange<CGFloat>) {
        let st = Settings.shared, k = scaleOf(a) / 0.7, n = a.node
        let goal = a.goal
        a.goal = 0
        switch goal {
        case 1:                                  // reached a toy
            guard let t = a.toy ?? toys.first else { return }
            a.toy = t
            if held === t {                      // you're dangling it: jump for it
                face(a, 4, 0.7)
                hop(a, height: max(14, min(46, (t.node.position.y - p.y) / k)))
                a.again = true; a.timer = 0.45
                st.cheer(0.4)
            } else if t.carrier != nil {         // the other pet has it: tag along
                face(a, 5, 0.6); a.timer = 1
            } else if t.kind == 2 {              // bone: pick it up and trot off with it
                t.carrier = a; t.v = .zero
                a.state = 1; a.goal = 9; a.sit = false
                a.target = abs(zone.lowerBound - p.x) > abs(zone.upperBound - p.x) ? zone.lowerBound + 30 : zone.upperBound - 30
                face(a, 4, 1.2)
                st.cheer(1)
            } else {                             // ball or yarn: bat it away, and often go after it again
                let power: CGFloat = t.kind == 1 ? 0.6 : 1
                t.v = CGVector(dx: a.dir * rnd(140, 230) * power, dy: rnd(140, 220) * power)
                face(a, 4, 1); a.squash = 0.14; a.timer = 0.9
                a.again = Int.random(in: 0..<10) < (a.kind == "cat" && t.kind == 1 ? 8 : 5)
                if let o = buddy(a), o.state == 0, Bool.random() {         // the other one joins the chase
                    o.state = 1; o.goal = 1; o.toy = t; o.sit = false
                }
                st.cheer(1.5)
            }
        case 2:                                  // jump into the leaf pile
            guard let pl = pile else { return }
            a.state = 4; a.timer = 1.3
            face(a, 4, 1.3); hop(a)
            pl.run(.sequence([.scaleY(to: 0.6, duration: 0.1), .scaleY(to: 1, duration: 0.25)]))
            bits(12, at: pl.position, tex: Art.leaf, size: CGSize(width: 12, height: 8),
                 colors: [0xE2703A, 0xD9A53C, 0xC9492F], up: 160...300)
            st.cheer(1.5)
        case 3:                                  // dig, vanish down the burrow, pop back out
            guard let h = hole else { return }
            a.state = 4; a.timer = 3.6
            n.position.x = h.position.x
            face(a, 5, 0.6)
            bits(8, at: h.position, tex: Art.dot, size: CGSize(width: 4, height: 4), colors: [0x8A6A4F, 0x6B5544], up: 90...200)
            let depth = 84 * k
            n.run(.sequence([.rotate(toAngle: 0.1, duration: 0.1), .rotate(toAngle: -0.1, duration: 0.15),
                             .rotate(toAngle: 0.1, duration: 0.15), .rotate(toAngle: 0, duration: 0.1),
                             .moveBy(x: 0, y: -depth, duration: 0.3), .wait(forDuration: 1.3),
                             .moveBy(x: 0, y: depth, duration: 0.22),
                             .run { [weak self, weak a] in
                                 guard let self, let a else { return }
                                 self.face(a, 4, 1.2); a.squash = 0.2
                                 self.emote(Art.star, x: a.node.position.x, y: a.node.position.y + 60 * k)
                             }]))
            st.cheer(1.5)
        case 4:                                  // reached the other pet: do something together
            guard let b = actors.first(where: { $0 !== a }), b.side == a.side, b.state == 0 || b.state == 2 else { return }
            let bx = b.node.position.x, mid = (p.x + bx) / 2
            a.dir = bx > p.x ? 1 : -1; b.dir = -a.dir
            b.sit = false
            if b.state == 2 {                    // friend is asleep: wake them with a boop
                b.state = 0; b.timer = 1.6; a.timer = 1.6
                face(b, 5, 0.8); hop(b, height: 14); face(a, 4, 1.2)
                emote(Art.bang, x: bx, y: p.y + 62 * k)
                st.cheer(1)
                return
            }
            a.timer = 1.8; b.timer = 1.8
            let pick = Int.random(in: 0..<6)
            switch pick {
            case 0:                              // nuzzle
                face(a, 3, 1.6); face(b, 3, 1.6)
                for (pet, d) in [(a, a.dir), (b, b.dir)] {
                    pet.node.run(.sequence([.rotate(toAngle: -0.16 * d, duration: 0.25), .wait(forDuration: 0.9),
                                            .rotate(toAngle: 0, duration: 0.2)]), withKey: "wig")
                }
                for i in 0..<3 { emote(Art.heart, x: mid + rnd(-8, 8), y: p.y + (54 + CGFloat(i) * 9) * k) }
                st.cheer(4)
            case 1:                              // dance together
                a.state = 3; b.state = 3; a.timer = 2.2; b.timer = 2.2
                emote(Art.note, x: p.x, y: p.y + 56 * k); emote(Art.note, x: bx, y: p.y + 64 * k)
                st.cheer(3)
            case 2:                              // nap side by side
                let t = rnd(8, 12)
                for pet in [a, b] { pet.state = 2; pet.sit = true; pet.timer = t }
                a.z = 0.4; b.z = 1.1
                st.cheer(2)
            case 3 where ball != nil && zone.contains(ball!.position.x):   // fetch: one goes for the ball, then the other
                face(a, 4, 1.4)
                b.state = 1; b.goal = 1; b.toy = toys.first { $0.kind == 0 }
                a.toy = b.toy
                a.again = true; a.timer = 2.5
                st.cheer(2)
            case 4:                              // tag: one runs off, the other gives chase
                face(a, 4, 1.2); face(b, 5, 0.6)
                let far = bx - zone.lowerBound > zone.upperBound - bx ? zone.lowerBound + 20 : zone.upperBound - 20
                n.run(.sequence([.wait(forDuration: 0.7), .run { [weak a, weak b] in
                    guard let a, let b, a.state == 0, b.state == 0 else { return }
                    b.state = 1; b.goal = 0; b.target = far
                    a.state = 1; a.goal = 0; a.target = far + (far < bx ? 62 : -62) * k
                }]))
                st.cheer(2)
            default:                             // hop hello
                face(a, 4, 1.5); face(b, 4, 1.5)
                hop(a, times: 2)
                b.node.run(.sequence([.wait(forDuration: 0.17), .run { [weak self, weak b] in if let b { self?.hop(b, times: 2) } }]))
                emote(Art.heart, x: mid, y: p.y + 62 * k)
                st.cheer(3)
            }
        case 5:                                  // shortcut to the other side of the Dock
            guard let from = a.side == 1 ? hole : house, let to = a.side == 1 ? house : hole else { return }
            a.state = 4; a.timer = 2.2
            face(a, 5, 0.4)
            n.position.x = from.position.x
            bits(6, at: from.position, tex: Art.star, size: CGSize(width: 7, height: 7), colors: [0xFFFFFF], up: 80...190)
            n.run(.sequence([.fadeOut(withDuration: 0.22), .wait(forDuration: 0.45),
                             .run { [weak self, weak a] in
                                 guard let self, let a else { return }
                                 a.side = 1 - a.side
                                 a.node.position = CGPoint(x: to.position.x, y: self.groundY(to.position.x))
                                 self.bits(6, at: to.position, tex: Art.star, size: CGSize(width: 7, height: 7),
                                           colors: [0xFFFFFF], up: 80...190)
                             },
                             .fadeIn(withDuration: 0.22),
                             .run { [weak self, weak a] in
                                 guard let self, let a else { return }
                                 self.face(a, 4, 1.2); a.squash = 0.2
                             }]))
            st.cheer(1)
        case 6:                                  // nap inside the little house
            guard let hs = house else { return }
            a.state = 4; a.timer = 6.2; a.inHouse = true; a.z = 0.6
            n.position.x = hs.position.x
            n.run(.sequence([.fadeOut(withDuration: 0.25), .wait(forDuration: 5), .fadeIn(withDuration: 0.25),
                             .run { [weak self, weak a] in
                                 guard let self, let a else { return }
                                 a.inHouse = false; a.squash = -0.18; self.face(a, 3, 0.8)
                             }]))
            st.cheer(1)
        case 7:                                  // eat from the bowl
            guard let bw = bowl else { return }
            a.state = 4; a.timer = 2.6
            a.dir = bw.position.x > p.x ? 1 : -1
            face(a, 3, 2.2); wiggle(a, 0.07, times: 7)
            bits(4, at: bw.position, tex: Art.dot, size: CGSize(width: 3, height: 3), colors: [0xC98A4B], up: 60...120)
            n.run(.sequence([.wait(forDuration: 2.2), .run { [weak self, weak a] in
                guard let self, let a else { return }
                self.face(a, 4, 1.2)
                self.emote(Art.heart, x: a.node.position.x, y: a.node.position.y + 58 * k)
            }]))
            st.cheer(4)
        case 8:                                  // give the snowball a push
            guard snowball != nil else { return }
            sbV = a.dir * rnd(150, 240)
            face(a, 4, 1); a.squash = 0.14; a.timer = 1
            st.cheer(1.5)
        case 9:                                  // put the bone down and have a chew
            toys.first { $0.carrier === a }?.carrier = nil
            a.state = 4; a.timer = 2.4
            face(a, 3, 2); wiggle(a, 0.06, times: 6)
            n.run(.sequence([.wait(forDuration: 2), .run { [weak self, weak a] in
                guard let self, let a else { return }
                self.face(a, 4, 1)
                self.emote(Art.heart, x: a.node.position.x, y: a.node.position.y + 58 * k)
            }]))
            st.cheer(3)
        default: break
        }
    }

    private func updateActor(_ a: PetActor, _ dt: CGFloat, t: CGFloat, speed: CGFloat, zone: ClosedRange<CGFloat>) {
        a.barMix += ((a.bar ? 1 : 0) - a.barMix) * min(1, 1.5 * dt)
        let st = Settings.shared, n = a.node, k = scaleOf(a) / 0.7
        var p = n.position
        a.cooldown -= dt; a.timer -= dt; a.faceTimer -= dt; a.blinkT -= dt
        if a.blinkT < -0.13 { a.blinkT = rnd(2, 5.5) }
        a.squash += (0 - a.squash) * min(1, 7 * dt)
        let sad = st.happy < 35
        let resting = evAway || st.focusing

        if evBack, !st.focusing {                // you came back: wake up and say hello
            a.state = 0; a.timer = 2.5; a.sit = false
            face(a, 4, 1.6); hop(a, times: 2)
            emote(Art.heart, x: p.x, y: p.y + 56 * k)
            st.cheer(2)
        } else if resting, a.state == 0 || a.state == 3 {
            a.state = 2; a.timer = 9999; a.z = 0.5; a.sit = true      // nap while you're away or focusing
        } else if !resting, a.state == 2, a.timer > 5000 {
            a.state = 0; a.timer = 1
        }

        if a.state != 2, a.state != 4 {
            if evKey {
                a.squash = max(a.squash, 0.09)                          // taps along with your typing
                if keyStreak % 28 == 0, (keyStreak / 28) % actors.count == actors.firstIndex(where: { $0 === a }) {
                    emote(Art.note, x: p.x + a.dir * 14 * k, y: p.y + 52 * k); face(a, 4, 0.7)
                }
            }
            if evCheer { face(a, 4, 1.5); hop(a, times: 2); emote(Art.star, x: p.x, y: p.y + 58 * k) }
            if evClick {
                if hypot(mouse.x - p.x, mouse.y - p.y) < 260 {
                    face(a, 5, 0.5); hop(a, height: 12)
                    a.dir = mouse.x > p.x ? 1 : -1
                } else { a.blinkT = 0; a.squash = max(a.squash, 0.06) }
            }
            if evScroll { face(a, 5, 0.9); wiggle(a, 0.2, times: 2) }
        }

        // Petting: rest the pointer on the pet for a moment.
        let near = abs(mouse.x - p.x) < 30 * k && mouse.y > p.y - 4 && mouse.y < p.y + 66 * k
        a.hover = near ? a.hover + dt : 0
        if a.hover > 0.3, a.cooldown <= 0, a.state != 4 {
            a.cooldown = 2.2
            for i in 0..<3 { emote(Art.heart, x: p.x + rnd(-14, 14), y: p.y + (50 + CGFloat(i) * 9) * k) }
            wiggle(a)
            face(a, 4, 1.6)
            st.cheer(6)
            if let o = buddy(a), o.state == 0 {                           // the other one wants attention too
                let tx = p.x + (o.node.position.x < p.x ? -60 : 60) * k
                o.state = 1; o.goal = 0; o.sit = false
                o.target = min(zone.upperBound, max(zone.lowerBound, tx))
                face(o, 5, 0.6)
            }
            if a.state == 2, !st.focusing { a.state = 0; a.timer = 3 }
            let name = st.name(a.slot)
            if !name.isEmpty {
                a.label.text = name
                a.label.position = CGPoint(x: p.x, y: (onBar || a.bar) ? p.y - 14 : p.y + 76 * k)
                a.label.removeAllActions()
                a.label.alpha = 1
                a.label.run(.sequence([.wait(forDuration: 1.8), .fadeOut(withDuration: 0.4)]))
            }
        } else if a.state != 2, a.state != 4, a.cooldown <= 0 {
            if shook {                           // a window got flung nearby
                a.cooldown = 4; face(a, 5, 0.8); hop(a, height: 14)
                emote(Art.bang, x: p.x + a.dir * 12 * k, y: p.y + 60 * k)
            } else if speed > 1500, abs(mouse.x - p.x) < 170, abs(mouse.y - p.y) < 170 {   // pointer whooshed past
                a.cooldown = 1.5; face(a, 5, 0.5); a.squash = 0.18
                a.dir = mouse.x > p.x ? 1 : -1
            }
        }

        switch a.state {
        case 1:
            let egg = a.kind == "egg"
            a.anim += dt
            n.texture = a.frames[Int(a.anim / (egg ? 0.22 : 0.16)) % 2].tex
            if a.goal == 1, let t = a.toy ?? toys.first {
                a.target = min(zone.upperBound, max(zone.lowerBound, t.node.position.x))
            }
            if a.goal == 8, let sb = snowball { a.target = sb.position.x }
            a.dir = a.target > p.x ? 1 : -1
            p.x += a.dir * (egg ? 24 : 46) * (sad ? 0.6 : 1) * k * dt
            p.y += (groundFor(a, p.x) - p.y) * min(1, 12 * dt)
            n.position = p
            if egg { n.zRotation = sin(a.anim * 9) * 0.1 }
            if abs(a.target - p.x) < (a.goal == 0 ? 3 : 18 * k) {
                n.zRotation = 0
                a.state = 0; a.timer = rnd(1.5, 4)
                arrive(a, p, zone: zone)
            }
        case 4:
            n.texture = a.frames[a.faceTimer > 0 ? a.faceIdx : 0].tex
            if a.inHouse, let hs = house {
                a.z -= dt
                if a.z <= 0 { a.z = 1.4; make(.zzz, x: hs.position.x + 12, y: hs.position.y + 22) }
            }
            if a.timer <= 0 { a.state = 0; a.goal = 0; a.timer = rnd(1.5, 3) }
        default:
            if a.state == 3 {
                a.anim += dt
                n.texture = a.frames[Int(a.anim / 0.12) % 2].tex          // happy feet
                if a.timer <= 0 { a.state = 0; a.timer = rnd(1.5, 3.5) }
                break
            }
            let idle = a.sit ? 6 : (sad ? 7 : 0)
            let f = a.state == 2 ? 2 : (a.faceTimer > 0 ? a.faceIdx : (a.blinkT < 0 ? 3 : idle))
            n.texture = a.frames[f].tex
            if a.state == 2 {
                a.z -= dt
                if a.z <= 0 { a.z = 1.5; make(.zzz, x: p.x + a.dir * 16 * k, y: p.y + 48 * k) }
                if a.timer <= 0 { a.state = 0; a.timer = 2; a.sit = false; a.squash = -0.18; face(a, 3, 0.7) }
                break
            }
            if abs(mouse.x - p.x) < 320, abs(mouse.x - p.x) > 12, mouse.y < p.y + 260, speed > 20 {
                a.dir = mouse.x > p.x ? 1 : -1                             // watch the pointer
            }
            if let o = buddy(a), abs(o.node.position.x - p.x) < 46 * k, a.slot > o.slot || o.state != 0 {
                let ox = o.node.position.x
                var tx = ox + (p.x >= ox ? 1 : -1) * 66 * k                // give each other room
                if !zone.contains(tx) { tx = ox - (p.x >= ox ? 1 : -1) * 66 * k }
                a.state = 1; a.goal = 0; a.sit = false
                a.target = min(zone.upperBound, max(zone.lowerBound, tx))
                break
            }
            if a.bar {
                a.barT -= dt
                if a.barT <= 0 { travel(a, toBar: false); break }
            }
            guard a.timer <= 0 else { break }
            if a.again, ball != nil { a.again = false; a.state = 1; a.goal = 1; a.sit = false; break }
            let r = Int.random(in: 0..<100)
            if st.busy {                                                   // you're typing: stay put
                a.sit = r < 55
                a.timer = rnd(3, 6)
                if r > 93 { a.state = 2; a.timer = rnd(6, 12); a.z = 0.5 }
                break
            }
            if sad, r < 45 {                                               // lonely: mopes until petted
                a.sit = false; a.timer = rnd(3, 6); face(a, 7, 3)
                if r < 15 {
                    bits(1, at: CGPoint(x: p.x + a.dir * 16 * k, y: p.y + 40 * k), tex: Art.dot,
                         size: CGSize(width: 4, height: 5), colors: [0x8FD0FF], up: 0...10)
                }
                break
            }
            if st.happy > 70, r < 12 {                                     // very happy: little dance
                emote(Art.heart, x: p.x, y: p.y + 56 * k)
                a.state = 3; a.timer = 1.4; a.sit = false
                break
            }
            if a.bar || onBar, r < 60 {                                    // up on the bar they mostly stroll
                a.state = 1; a.sit = false; a.target = rnd(zone.lowerBound, zone.upperBound)
                break
            }
            if (76..<97).contains(r), st.toys {
                func mine(_ node: SKSpriteNode?) -> SKSpriteNode? {
                    guard let node, zone.contains(node.position.x) else { return nil }
                    return node
                }
                var goals: [(Int, SKSpriteNode)] = []
                for t in toys where t.carrier == nil { if let node = mine(t.node) { goals.append((1, node)) } }
                if let pl = mine(pile) { goals.append((2, pl)) }
                if let h = mine(hole) { goals.append((3, h)) }
                if house != nil, hole != nil, let door = mine(a.side == 1 ? hole : house) {
                    if actors.count == 1 { goals.append((5, door)) }
                }
                if let hs = mine(house) { goals.append((6, hs)) }
                if let bw = mine(bowl) { goals.append((7, bw)) }
                if let sb = mine(snowball) { goals.append((8, sb)); goals.append((8, sb)) }
                if let g = goals.randomElement() {
                    a.goal = g.0; a.state = 1; a.sit = false; a.target = g.1.position.x
                    a.toy = toys.first { $0.node === g.1 }
                    break
                }
            }
            switch r {
            case 0..<16:
                var tx = rnd(zone.lowerBound, zone.upperBound)
                if let o = buddy(a) {
                    for _ in 0..<5 where abs(tx - o.node.position.x) < 64 * k || (o.state == 1 && abs(tx - o.target) < 64 * k) {
                        tx = rnd(zone.lowerBound, zone.upperBound)
                    }
                }
                a.state = 1; a.sit = false; a.target = tx
            case 16..<24:
                a.sit.toggle(); a.timer = rnd(3, 6); a.squash = 0.12
            case 24..<32:
                hop(a, times: Int.random(in: 1...2)); face(a, 4, 0.9); a.timer = 2
                if let o = buddy(a), o.state == 0, Bool.random() {         // the other one copies
                    o.node.run(.sequence([.wait(forDuration: 0.3), .run { [weak self, weak o] in
                        if let o { self?.hop(o); self?.face(o, 4, 0.8) }
                    }]))
                }
            case 32..<40:
                a.state = 3; a.timer = 1.4; a.sit = false
            case 40..<46:
                a.dir = -a.dir; a.timer = 2
                n.run(.sequence([.wait(forDuration: 0.6), .run { [weak a] in a?.dir *= -1 }]))
            case 46..<52:
                a.squash = -0.2; face(a, 3, 0.9); a.timer = 2.2             // big stretch
            case 52..<58:
                a.state = 2; a.sit = true; a.timer = rnd(8, 16); a.z = 0.5
            case 58..<64:
                hop(a, height: 28); face(a, 4, 0.8); a.timer = 2
                n.run(.sequence([.wait(forDuration: 0.17), .run { [weak a] in a?.dir *= -1 }]))
            case 64..<76:
                a.timer = 2.4
                switch Int.random(in: 0..<6) {
                case 0:                                               // backflip
                    hop(a, height: 34); face(a, 4, 1)
                    n.run(.rotate(byAngle: -2 * .pi * a.dir, duration: 0.34))
                case 1:                                               // sneeze
                    face(a, 3, 0.5); a.squash = 0.25
                    n.run(.sequence([.wait(forDuration: 0.35), .run { [weak self, weak a] in
                        guard let self, let a else { return }
                        self.face(a, 5, 0.7); a.squash = -0.15
                        self.bits(5, at: CGPoint(x: a.node.position.x + a.dir * 22 * k, y: a.node.position.y + 34 * k),
                                  tex: Art.dot, size: CGSize(width: 3, height: 3), colors: [0xFFFFFF], up: 20...80)
                    }]))
                case 2:                                               // dig up a little treasure
                    a.state = 4; a.timer = 2.2
                    wiggle(a, 0.08, times: 5)
                    bits(8, at: CGPoint(x: p.x + a.dir * 18 * k, y: p.y + 4), tex: Art.dot, size: CGSize(width: 4, height: 4),
                         colors: [0x8A6A4F, 0x6B5544], up: 80...190)
                    n.run(.sequence([.wait(forDuration: 1.5), .run { [weak self, weak a] in
                        guard let self, let a else { return }
                        self.face(a, 4, 1.2)
                        self.emote(Bool.random() ? Art.star : Art.heart, x: a.node.position.x + a.dir * 16 * k,
                                   y: a.node.position.y + 40 * k)
                    }]))
                case 3:                                               // chase its own tail
                    a.state = 3; a.timer = 1.8
                    n.run(.repeat(.sequence([.wait(forDuration: 0.22), .run { [weak a] in a?.dir *= -1 }]), count: 7))
                case 4:                                               // sing a little tune
                    face(a, 4, 2); wiggle(a, 0.07, times: 4)
                    for i in 0..<3 {
                        n.run(.sequence([.wait(forDuration: Double(i) * 0.45), .run { [weak self, weak a] in
                            guard let self, let a else { return }
                            self.emote(Art.note, x: a.node.position.x + a.dir * 14 * k, y: a.node.position.y + 54 * k)
                        }]))
                    }
                default:                                              // peekaboo: duck out of sight, pop back up
                    guard !a.bar, groundFor(a, p.x) < 0 else { hop(a); break }
                    a.state = 4; a.timer = 2.4
                    n.run(.sequence([.moveBy(x: 0, y: -56 * k, duration: 0.25), .wait(forDuration: 0.9),
                                     .moveBy(x: 0, y: 56 * k, duration: 0.16),
                                     .run { [weak self, weak a] in
                                         guard let self, let a else { return }
                                         self.face(a, 5, 0.8); a.squash = 0.2
                                     }]))
                }
            case 97..<100 where st.barVisits && !a.bar && !onBar && !sad:   // pop up to the menu bar for a while
                travel(a, toBar: true)
            default:
                a.timer = 2.4
                switch st.weather {
                case .snow, .leaves, .sakura:                              // jump to catch one
                    face(a, 4, 1.2); hop(a, height: 30); emote(Art.star, x: p.x, y: p.y + 70 * k)
                case .rain:                                                // shake the rain off
                    face(a, 3, 1); wiggle(a, 0.08, times: 5)
                    bits(5, at: CGPoint(x: p.x, y: p.y + 30 * k), tex: Art.dot, size: CGSize(width: 3, height: 3),
                         colors: [0xCFE6FF], up: 40...130)
                case .starfall, .fireflies:
                    face(a, 5, 1.3); emote(Art.star, x: p.x + a.dir * 10 * k, y: p.y + 60 * k)
                case .off:
                    wiggle(a, 0.12, times: 2); face(a, 4, 0.9)
                }
            }
        }
        let breath = sin(t * (a.state == 2 ? 1.6 : 2.6)) * (a.state == 2 ? 0.035 : 0.02)
        let sc = scaleOf(a)
        n.yScale = sc * (1 + breath - a.squash)
        n.xScale = sc * a.dir * (1 - breath * 0.5 + a.squash * 0.6)
    }

    // MARK: Demo scene (a stand-alone window with a mock desktop, used to record the README clips)

    private(set) var demoWindow = CGRect.zero

    func enterDemo(frame: CGRect, time: DayTime) {
        screenFrame = frame
        let w = frame.width, h = frame.height
        barH = 26; notch = false
        let d = CGRect(x: w / 2 - 250, y: 0, width: 500, height: 56)
        dock = d
        let img = Wallpapers.render(width: Int(w * 2), height: Int(h * 2), time: time, season: Settings.shared.weather.season)
        let bg = SKSpriteNode(texture: SKTexture(cgImage: img), size: frame.size)
        bg.anchorPoint = .zero
        bg.zPosition = -100
        addChild(bg)
        func box(_ r: CGRect, _ radius: CGFloat, _ hex: UInt32, _ a: CGFloat, _ z: CGFloat) {
            let n = SKShapeNode(rect: r, cornerRadius: radius)
            n.fillColor = SKColor(cgColor: rgb(hex, a)) ?? .gray
            n.strokeColor = .clear
            n.zPosition = z
            addChild(n)
        }
        box(CGRect(x: 0, y: h - 26, width: w, height: 26), 0, 0x000000, 0.28, -60)
        box(CGRect(x: d.minX, y: 5, width: d.width, height: 50), 14, 0xFFFFFF, 0.28, -60)
        for (i, c) in ([0x4FB7A8, 0xF4727E, 0xF7C948, 0x6FB7E9, 0xB58AE0, 0x57AD8C, 0xF39445, 0x8A93B8] as [UInt32]).enumerated() {
            box(CGRect(x: d.minX + 16 + CGFloat(i) * 59.5, y: 11, width: 38, height: 38), 9, c, 0.95, -55)
        }
        let win = CGRect(x: w * 0.5, y: h * 0.36, width: w * 0.38, height: h * 0.4)
        demoWindow = win
        box(win, 10, 0x20222E, 0.97, -50)
        box(CGRect(x: win.minX, y: win.maxY - 28, width: win.width, height: 28), 10, 0x2C2F3F, 1, -49)
        for (i, c) in ([0xFF5F57, 0xFEBC2E, 0x28C840] as [UInt32]).enumerated() {
            box(CGRect(x: win.minX + 12 + CGFloat(i) * 18, y: win.maxY - 19.5, width: 11, height: 11), 5.5, c, 1, -48)
        }
        for i in 0..<6 {
            box(CGRect(x: win.minX + 20, y: win.maxY - 62 - CGFloat(i) * 26, width: win.width * (i % 3 == 2 ? 0.45 : 0.75), height: 9),
                4.5, 0x8A93B8, 0.35, -48)
        }
    }

    // MARK: Frame loop

    override func update(_ currentTime: TimeInterval) {
        let dt = CGFloat(min(0.05, lastTime == 0 ? 0.016 : currentTime - lastTime))
        lastTime = currentTime
        lastFrame = CACurrentMediaTime()
        let m = NSEvent.mouseLocation
        let np = CGPoint(x: m.x - screenFrame.minX, y: m.y - screenFrame.minY)
        mouseV = CGVector(dx: (np.x - mouse.x) / max(dt, 0.001), dy: (np.y - mouse.y) / max(dt, 0.001))
        mouse = np
        let speed = hypot(mouseV.dx, mouseV.dy)
        stillFor = speed < 4 ? stillFor + dt : 0

        wind = CGVector(dx: max(-900, min(900, mouseV.dx)), dy: max(-900, min(900, mouseV.dy)))

        // Clicks pass through everywhere except on a decoration.
        let pass = !(dragging != nil || held != nil || (!decor.isEmpty && decorAt(mouse) != nil) || toyAt(mouse) != nil)
        if pass != passThrough { passThrough = pass; view?.window?.ignoresMouseEvents = pass }

        spawn(dt)
        step(dt, t: CGFloat(currentTime.truncatingRemainder(dividingBy: 3600)), speed: speed)
        brushPiles(speed)
        pileTimer += dt
        if pileTimer > 0.2 {
            pileTimer = 0
            if pilesDirty { rebuildPiles() }
        }
        updatePets(dt, t: CGFloat(currentTime.truncatingRemainder(dividingBy: 3600)), speed: speed)

        if debug {
            debugTimer += dt
            if debugTimer > 2 {
                debugTimer = 0
                let snow = piles.values.reduce(0) { $0 + $1.reduce(0, +) }
                print("screen \(screenIndex): particles=\(parts.count) pooled=\(pool.count) surfaces=\(surfaces.count) "
                      + "piled=\(Int(snow)) resting=\(restCount) decor=\(decor.count) pets=\(actors.count) mood=\(Int(Settings.shared.happy)) busy=\(Settings.shared.busy)")
                fflush(stdout)
            }
        }
    }
}
