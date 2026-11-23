import AppKit
import CoreImage

enum Season: String { case winter, autumn, spring, summer }

struct Look {
    let top, mid, bot, tint: UInt32
    let dark: CGFloat
    let sun: CGPoint?
    let moon: CGPoint?
    let stars: CGFloat
    let glow: CGFloat
}

enum DayTime: Int, CaseIterable {
    case dawn, sunrise, morning, midday, golden, sunset, dusk, night

    var title: String {
        ["Dawn", "Sunrise", "Morning", "Midday", "Golden hour", "Sunset", "Dusk", "Night"][rawValue]
    }

    static func current() -> DayTime {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5: return .dawn
        case 6..<8: return .sunrise
        case 8..<11: return .morning
        case 11..<15: return .midday
        case 15..<17: return .golden
        case 17..<18: return .sunset
        case 18..<20: return .dusk
        default: return .night
        }
    }

    var look: Look {
        switch self {
        case .dawn: return Look(top: 0x2B2D5B, mid: 0x7A5C8E, bot: 0xF2A7A0, tint: 0x2A2A5E, dark: 0.45,
                                sun: nil, moon: nil, stars: 0.35, glow: 0.8)
        case .sunrise: return Look(top: 0x5673B5, mid: 0xF6B38E, bot: 0xFFE0A8, tint: 0x5A3F6E, dark: 0.22,
                                   sun: CGPoint(x: 0.24, y: 0.6), moon: nil, stars: 0, glow: 0.4)
        case .morning: return Look(top: 0x6FB7E9, mid: 0xA9D8F2, bot: 0xE9F6FB, tint: 0x35508A, dark: 0.04,
                                   sun: CGPoint(x: 0.3, y: 0.8), moon: nil, stars: 0, glow: 0)
        case .midday: return Look(top: 0x3F9BE6, mid: 0x86C5F2, bot: 0xD8F0FB, tint: 0x35508A, dark: 0,
                                  sun: CGPoint(x: 0.52, y: 0.9), moon: nil, stars: 0, glow: 0)
        case .golden: return Look(top: 0x5C8FD0, mid: 0xF7C47B, bot: 0xFFE2A0, tint: 0x8A4A3A, dark: 0.12,
                                  sun: CGPoint(x: 0.74, y: 0.68), moon: nil, stars: 0, glow: 0.2)
        case .sunset: return Look(top: 0x4A3F8C, mid: 0xE9727E, bot: 0xFFB56B, tint: 0x4A2E5E, dark: 0.32,
                                  sun: CGPoint(x: 0.78, y: 0.58), moon: nil, stars: 0.1, glow: 0.6)
        case .dusk: return Look(top: 0x1E2456, mid: 0x5A4A93, bot: 0xD98BA6, tint: 0x1F2258, dark: 0.52,
                                sun: nil, moon: CGPoint(x: 0.82, y: 0.84), stars: 0.55, glow: 1)
        case .night: return Look(top: 0x0B1033, mid: 0x1B2157, bot: 0x3A3B7C, tint: 0x141A4A, dark: 0.7,
                                 sun: nil, moon: CGPoint(x: 0.8, y: 0.84), stars: 1, glow: 1)
        }
    }
}

struct RNG {
    var s: UInt64
    mutating func next() -> CGFloat {
        s &+= 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return CGFloat(z >> 11) / CGFloat(1 << 53)
    }
    mutating func r(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * next() }
}

private struct Palette {
    let mountain, mountain2, hillFar, ground, fore: UInt32
    let trees: [UInt32]
    let treeShade: UInt32
}

enum Painter {
    private static func palette(_ s: Season) -> Palette {
        switch s {
        case .winter: return Palette(mountain: 0x8E9FD4, mountain2: 0xA9B8E3, hillFar: 0xD5E0F5, ground: 0xE9F0FC,
                                     fore: 0xFAFCFF, trees: [0x57AD8C, 0x4FA088], treeShade: 0x377F6C)
        case .autumn: return Palette(mountain: 0x9A8FB8, mountain2: 0xB59CB5, hillFar: 0xE0A85A, ground: 0xEBC06A,
                                     fore: 0xF3D48A, trees: [0xE2703A, 0xE9A23B, 0xD4523A], treeShade: 0xB8482A)
        case .spring: return Palette(mountain: 0x8FB0D9, mountain2: 0xA6C8E0, hillFar: 0x9BD18F, ground: 0xB4E09A,
                                     fore: 0xCBEBAE, trees: [0xF7B6CF, 0xFFCADB], treeShade: 0xE690B5)
        case .summer: return Palette(mountain: 0x7FA8CF, mountain2: 0x8FC0CF, hillFar: 0x6FBF7E, ground: 0x86D184,
                                     fore: 0xA3DE96, trees: [0x3E9C78, 0x4BAE80], treeShade: 0x2B7D63)
        }
    }

    static func paint(width: Int, height: Int, time: DayTime, season: Season) -> CGImage {
        let w = CGFloat(width), h = CGFloat(height), u = h / 100
        let lk = time.look, pal = palette(season)
        var rng = RNG(s: 42)
        let winter = season == .winter

        return makeImage(w, h, scale: 1) { c in
            // Land colours get darker and bluer at night, hazier with distance.
            func L(_ hex: UInt32, _ far: CGFloat = 0) -> UInt32 {
                mixHex(mixHex(hex, lk.mid, far), lk.tint, lk.dark * 0.82)
            }
            func ridge(_ x: CGFloat, _ base: CGFloat, _ amp: CGFloat, _ k: CGFloat) -> CGFloat {
                let n = x / w
                if k < 2 {   // mountain layers: soft pointed peaks
                    let a = 1 - abs(sin(n * 3.4 * k + k * 2.3)), b = 1 - abs(sin(n * 7.9 * k + k * 0.7))
                    return h * (base + amp * (1.5 * pow(a, 1.6) + 0.55 * pow(b, 1.4) - 0.9))
                }
                return h * (base + amp * (0.55 * sin(n * 5.1 * k + k * 1.7) + 0.3 * sin(n * 11.3 * k + k * 4.1)
                                          + 0.15 * sin(n * 23.7 + k * 9)))
            }
            func land(_ base: CGFloat, _ amp: CGFloat, _ k: CGFloat, lift: CGFloat = 0) -> CGPath {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 0, y: 0))
                var x: CGFloat = 0
                while x <= w + 8 { p.addLine(to: CGPoint(x: x, y: ridge(x, base, amp, k) + lift)); x += 8 }
                p.addLine(to: CGPoint(x: w, y: 0))
                p.closeSubpath()
                return p
            }
            func capped(_ base: CGFloat, _ amp: CGFloat, _ k: CGFloat, _ color: UInt32, cap: CGFloat, far: CGFloat) {
                let m = land(base, amp, k)
                c.paint(m, L(color, far))
                guard cap > 0 else { return }
                c.saveGState(); c.addPath(m); c.clip()
                c.addRect(CGRect(x: 0, y: 0, width: w, height: h))
                c.addPath(land(base - 0.012, amp * 1.25, k, lift: -cap))
                c.setFillColor(rgb(L(0xFFFFFF, far * 0.6)))
                c.fillPath(using: .evenOdd)
                c.restoreGState()
            }
            func tree(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ far: CGFloat = 0, _ v: Int = 0) {
                let col = L(pal.trees[v % pal.trees.count], far), sh = L(pal.treeShade, far)
                c.paint(roundRect(x - s * 0.06, y - s * 0.03, s * 0.12, s * 0.28, s * 0.03), L(0x8A5A3C, far))
                if season == .spring {
                    c.shaded(ovalPath(x - s * 0.17, y + s * 0.42, s * 0.2, s * 0.19), col, sh)
                    c.shaded(ovalPath(x + s * 0.17, y + s * 0.44, s * 0.2, s * 0.19), col, sh)
                    c.shaded(ovalPath(x, y + s * 0.6, s * 0.3, s * 0.3), col, sh)
                } else {
                    let tiers: [(CGFloat, CGFloat, CGFloat)] = [(0.16, 0.62, 0.42), (0.38, 0.5, 0.38), (0.6, 0.36, 0.34)]
                    for t in tiers {
                        let g = gumdrop(x, y + s * t.0, s * t.1, s * t.2)
                        c.shaded(g, col, sh)
                        if winter {
                            c.saveGState(); c.addPath(g); c.clip()
                            c.oval(x, y + s * (t.0 + t.2), s * t.1 * 0.36, s * t.2 * 0.42, L(0xFFFFFF, far))
                            c.restoreGState()
                        }
                    }
                }
            }

            // Sky
            let sky = CGGradient(colorsSpace: sRGB, colors: [rgb(lk.bot), rgb(lk.mid), rgb(lk.top)] as CFArray,
                                 locations: [0, 0.45, 1])!
            c.drawLinearGradient(sky, start: CGPoint(x: 0, y: h * 0.32), end: CGPoint(x: 0, y: h),
                                 options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            if lk.stars > 0 {
                for _ in 0..<260 {
                    let r = rng.r(0.08, 0.26) * u
                    c.oval(rng.r(0, w), rng.r(h * 0.42, h), r, r, 0xFFFFFF, rng.r(0.25, 1) * lk.stars)
                }
                for _ in 0..<9 {
                    let x = rng.r(0, w), y = rng.r(h * 0.6, h * 0.97)
                    c.glow(x, y, 1.6 * u, 0xFFFFFF, 0.5 * lk.stars)
                    c.paint(starPath(x, y, 0.7 * u, 0.22 * u), 0xFFFFFF, lk.stars)
                }
            }
            if let s = lk.sun {
                c.glow(s.x * w, s.y * h, 26 * u, 0xFFF3C4, 0.55)
                c.oval(s.x * w, s.y * h, 5 * u, 5 * u, 0xFFF6D6)
            }
            if let m = lk.moon {
                c.glow(m.x * w, m.y * h, 18 * u, 0xFFF3C4, 0.3)
                c.saveGState()
                c.addRect(CGRect(x: 0, y: 0, width: w, height: h))
                c.addPath(ovalPath(m.x * w + 1.9 * u, m.y * h + 1.1 * u, 3.7 * u, 3.7 * u))
                c.clip(using: .evenOdd)
                c.oval(m.x * w, m.y * h, 4.2 * u, 4.2 * u, 0xFFF6D8)
                c.restoreGState()
            }
            // Clouds
            let cloud = mixHex(0xFFFFFF, lk.bot, 0.35 + lk.dark * 0.4)
            for i in 0..<5 {
                let cx = (CGFloat(i) + rng.r(0.1, 0.9)) * w / 5, cy = rng.r(0.66, 0.92) * h, s = rng.r(3, 5.5) * u
                let a = 0.75 - lk.dark * 0.55
                c.saveGState()
                c.setAlpha(a)
                c.beginTransparencyLayer(auxiliaryInfo: nil)
                c.paint(roundRect(cx - s * 2.2, cy - s * 0.6, s * 4.4, s * 1.2, s * 0.6), cloud)
                c.oval(cx - s * 0.9, cy + s * 0.3, s * 1.0, s * 0.9, cloud)
                c.oval(cx + s * 0.5, cy + s * 0.5, s * 1.3, s * 1.2, cloud)
                c.endTransparencyLayer()
                c.restoreGState()
            }

            // Mountains and hills, far to near
            capped(0.56, 0.12, 1.0, pal.mountain, cap: 4.5 * u, far: 0.45)
            capped(0.46, 0.08, 1.9, pal.mountain2, cap: winter ? 3 * u : 0, far: 0.28)
            c.paint(land(0.37, 0.035, 3.1), L(pal.hillFar, 0.15))
            var x = rng.r(0, 3) * u
            while x < w {
                tree(x, ridge(x, 0.37, 0.035, 3.1) - 0.4 * u, rng.r(3.2, 5.2) * u, 0.18, Int(rng.r(0, 3)))
                x += rng.r(2.2, 7) * u
            }

            c.paint(land(0.27, 0.05, 2.3), L(pal.ground))
            let hx = w * 0.36, hy = ridge(hx, 0.27, 0.05, 2.3) - 1.2 * u
            x = rng.r(2, 8) * u
            while x < w {
                if abs(x - hx) > 16 * u {
                    tree(x, ridge(x, 0.27, 0.05, 2.3) - 0.8 * u, rng.r(7, 12) * u, 0.05, Int(rng.r(0, 3)))
                }
                x += rng.r(7, 16) * u
            }

            // Cottage: round roof, round door, two porthole windows
            c.paint(roundRect(hx + 3.4 * u, hy + 9 * u, 2.4 * u, 6.5 * u, 0.5 * u), L(0xB5705A))
            for (i, d) in ([(0.6, 17.5, 1.1), (1.6, 20, 1.5), (0.4, 23, 1.9)] as [(CGFloat, CGFloat, CGFloat)]).enumerated() {
                c.oval(hx + (4.6 + d.0) * u, hy + d.1 * u, d.2 * u, d.2 * u, L(0xFFFFFF), 0.5 - CGFloat(i) * 0.12)
            }
            c.shaded(roundRect(hx - 7 * u, hy, 14 * u, 9 * u, 1.6 * u), L(0xFFF1DC), L(0xE9CDB0))
            let roof = CGMutablePath()
            roof.move(to: CGPoint(x: hx - 9 * u, y: hy + 8 * u))
            roof.addCurve(to: CGPoint(x: hx + 9 * u, y: hy + 8 * u), control1: CGPoint(x: hx - 8.5 * u, y: hy + 19 * u),
                          control2: CGPoint(x: hx + 8.5 * u, y: hy + 19 * u))
            roof.closeSubpath()
            c.shaded(roof, L(0xEE7C86), L(0xD45F72))
            if winter {
                c.saveGState(); c.addPath(roof); c.clip()
                c.oval(hx, hy + 17 * u, 8.2 * u, 6.4 * u, L(0xFFFFFF))
                c.restoreGState()
            }
            c.paint(roundRect(hx - 1.7 * u, hy, 3.4 * u, 5.4 * u, 1.7 * u), L(0x9A6B4F))
            c.oval(hx + 0.8 * u, hy + 2.4 * u, 0.3 * u, 0.3 * u, L(0xFFD977))
            let pane = mixHex(L(0xBFE3F5), 0xFFD977, lk.glow)
            for dx in [-4.4, 4.4] as [CGFloat] {
                if lk.glow > 0 { c.glow(hx + dx * u, hy + 4.6 * u, 7 * u, 0xFFC45A, 0.5 * lk.glow) }
                c.oval(hx + dx * u, hy + 4.6 * u, 1.7 * u, 1.7 * u, L(0x9A6B4F))
                c.oval(hx + dx * u, hy + 4.6 * u, 1.3 * u, 1.3 * u, pane)
            }

            // Foreground hill and framing trees, kept low so the Dock and icons stay readable
            c.paint(land(0.12, 0.04, 1.3), L(pal.fore))
            for (fx, s, v) in [(0.05, 30, 0), (0.15, 20, 1), (0.9, 22, 1), (0.975, 32, 0)] as [(CGFloat, CGFloat, Int)] {
                tree(fx * w, ridge(fx * w, 0.12, 0.04, 1.3) - 2 * u, s * u, 0, v)
            }

            // Painterly grain
            for i in 0..<4200 {
                c.setFillColor(i % 2 == 0 ? rgb(0xFFFFFF, 0.03) : rgb(0x1B2050, 0.025))
                c.fillEllipse(in: CGRect(x: rng.r(0, w), y: rng.r(0, h), width: rng.r(0.5, 2.2) * u, height: rng.r(0.2, 0.7) * u))
            }
        }
    }
}

enum Wallpapers {
    static var dir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tuft/wallpapers", isDirectory: true)
    }

    /// Uses the painted scene bundled with the app (one day and one night painting per season), washed with
    /// colour for the time of day. Falls back to the code-drawn scene when the paintings are missing.
    /// A folder where you can drop your own pictures, named like "winter-night.jpg".
    static var customDir: URL { dir.deletingLastPathComponent().appendingPathComponent("My Wallpapers", isDirectory: true) }

    static func custom(_ name: String) -> URL? {
        for ext in ["jpg", "jpeg", "png", "heic"] {
            let u = customDir.appendingPathComponent("\(name).\(ext)")
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        return nil
    }

    static let timeKeys = ["dawn", "sunrise", "morning", "midday", "golden", "sunset", "dusk", "night"]

    /// One of your own pictures for an exact scene and time of day, named like "snow-night.jpg".
    static func themed(_ theme: String, _ time: DayTime) -> URL? {
        if theme.isEmpty { return nil }
        let name = "\(theme)-\(timeKeys[time.rawValue])"
        return custom(name) ?? Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "wallpapers")
    }

    /// Scene names found in your pictures folder (anything that has a "-night" picture).
    static func themes() -> [String] {
        var files = (try? FileManager.default.contentsOfDirectory(atPath: customDir.path)) ?? []
        if let built = Bundle.main.resourceURL?.appendingPathComponent("wallpapers").path {
            files += (try? FileManager.default.contentsOfDirectory(atPath: built)) ?? []
        }
        let seasons: Set<String> = ["winter", "autumn", "spring", "summer"]
        var found = Set<String>()
        for f in files {
            let base = (f as NSString).deletingPathExtension
            if base.hasSuffix("-night") {
                let name = String(base.dropLast(6))
                if !(seasons.contains(name) && themed(name, .dawn) == nil) { found.insert(name) }
            }
        }
        return found.sorted()
    }

    /// A small picture stretched over a big screen goes soft. Enlarge it with a Lanczos filter and put a little edge
    /// contrast back, which keeps painted lines crisp without inventing anything that is not in the picture.
    static func enlarged(_ img: CGImage, by k: CGFloat) -> CGImage {
        guard k > 1.15, let scale = CIFilter(name: "CILanczosScaleTransform"), let sharpen = CIFilter(name: "CIUnsharpMask") else { return img }
        scale.setValue(CIImage(cgImage: img), forKey: kCIInputImageKey)
        scale.setValue(k, forKey: kCIInputScaleKey)
        scale.setValue(1.0, forKey: kCIInputAspectRatioKey)
        guard let big = scale.outputImage else { return img }
        sharpen.setValue(big, forKey: kCIInputImageKey)
        sharpen.setValue(min(4, 0.9 * k), forKey: kCIInputRadiusKey)
        sharpen.setValue(0.5, forKey: kCIInputIntensityKey)
        let out = sharpen.outputImage ?? big
        let rect = CGRect(x: 0, y: 0, width: (CGFloat(img.width) * k).rounded(.down), height: (CGFloat(img.height) * k).rounded(.down))
        return CIContext().createCGImage(out, from: rect) ?? img
    }

    static func render(width: Int, height: Int, time: DayTime, season: Season, theme: String = "") -> CGImage {
        if let u = themed(theme, time), let src = CGImageSourceCreateWithURL(u as CFURL, nil),
           let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
            let w = CGFloat(width), h = CGFloat(height)
            return makeImage(w, h, scale: 1) { c in                // already painted for this time: no tint
                c.interpolationQuality = .high
                let k = max(w / CGFloat(img.width), h / CGFloat(img.height))
                let dw = CGFloat(img.width) * k, dh = CGFloat(img.height) * k
                c.draw(enlarged(img, by: k), in: CGRect(x: (w - dw) / 2, y: (h - dh) / 2, width: dw, height: dh))
            }
        }
        let night = time == .dusk || time == .night
        let name = "\(season.rawValue)-\(night ? "night" : "day")"
        guard let url = custom(name) ?? Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "wallpapers"),
              let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let base = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            return Painter.paint(width: width, height: height, time: time, season: season)
        }
        let w = CGFloat(width), h = CGFloat(height)
        return makeImage(w, h, scale: 1) { c in
            c.interpolationQuality = .high
            let k = max(w / CGFloat(base.width), h / CGFloat(base.height))
            let dw = CGFloat(base.width) * k, dh = CGFloat(base.height) * k
            c.draw(enlarged(base, by: k), in: CGRect(x: (w - dw) / 2, y: (h - dh) / 2, width: dw, height: dh))
            func wash(_ mode: CGBlendMode, _ hex: UInt32, _ a: CGFloat) {
                c.setBlendMode(mode); c.setFillColor(rgb(hex, a)); c.fill(CGRect(x: 0, y: 0, width: w, height: h))
            }
            switch time {
            case .dawn: wash(.multiply, 0x7C7FC4, 0.6); wash(.softLight, 0xFFB7A8, 0.35)
            case .sunrise: wash(.multiply, 0xFFD2B0, 0.55); wash(.softLight, 0xFFB56B, 0.25)
            case .morning: wash(.softLight, 0xDFF2FF, 0.15)
            case .golden: wash(.multiply, 0xFFDDA6, 0.5); wash(.softLight, 0xFFB347, 0.2)
            case .sunset: wash(.multiply, 0xF09A86, 0.6); wash(.softLight, 0xFF7A59, 0.25)
            case .dusk: wash(.screen, 0x5A3F8A, 0.22); wash(.softLight, 0xE38BB0, 0.2)
            case .midday, .night: break
            }
            c.setBlendMode(.normal)
        }
    }

    static func apply(time: DayTime, season: Season, theme: String = "") {
        let d = UserDefaults.standard
        var orig = d.dictionary(forKey: "origWallpapers") as? [String: String] ?? [:]
        var jobs: [(NSScreen, URL, Int, Int)] = []
        var stamp = ""          // re-render when one of your own pictures is swapped
        let night = time == .dusk || time == .night
        if let c = custom("\(season.rawValue)-\(night ? "night" : "day")"),
           let m = (try? FileManager.default.attributesOfItem(atPath: c.path))?[.modificationDate] as? Date {
            stamp = "-c\(Int(m.timeIntervalSince1970))"
        }
        if let c = themed(theme, time),
           let m = (try? FileManager.default.attributesOfItem(atPath: c.path))?[.modificationDate] as? Date {
            stamp = "-t\(theme)\(Int(m.timeIntervalSince1970))"
        }
        for (i, screen) in NSScreen.screens.enumerated() {
            if orig["\(i)"] == nil, let cur = NSWorkspace.shared.desktopImageURL(for: screen),
               !cur.path.hasPrefix(dir.path) {
                orig["\(i)"] = cur.path
            }
            var pw = screen.frame.width * screen.backingScaleFactor, ph = screen.frame.height * screen.backingScaleFactor
            if pw > 3840 { ph *= 3840 / pw; pw = 3840 }
            let url = dir.appendingPathComponent("tuft-\(season.rawValue)-\(time.rawValue)-\(Int(pw))x\(Int(ph))-v3\(stamp).png")
            jobs.append((screen, url, Int(pw), Int(ph)))
        }
        d.set(orig, forKey: "origWallpapers")
        DispatchQueue.global(qos: .userInitiated).async {
            for j in jobs where !FileManager.default.fileExists(atPath: j.1.path) {
                writePNG(render(width: j.2, height: j.3, time: time, season: season, theme: theme), to: j.1)
            }
            DispatchQueue.main.async {
                for j in jobs { try? NSWorkspace.shared.setDesktopImageURL(j.1, for: j.0, options: [:]) }
            }
        }
    }

    static func restore() {
        let orig = UserDefaults.standard.dictionary(forKey: "origWallpapers") as? [String: String] ?? [:]
        for (i, screen) in NSScreen.screens.enumerated() {
            if let p = orig["\(i)"], FileManager.default.fileExists(atPath: p) {
                try? NSWorkspace.shared.setDesktopImageURL(URL(fileURLWithPath: p), for: screen, options: [:])
            }
        }
        UserDefaults.standard.removeObject(forKey: "origWallpapers")
    }
}
