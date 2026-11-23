import AppKit

let args = CommandLine.arguments

func argValue(_ flag: String) -> String? {
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    return args[i + 1]
}

// `--icon <file.png>` writes the app icon; `--preview <dir>` writes every wallpaper and a character sheet.
if let path = argValue("--icon") {
    writePNG(makeImage(1024, 1024, scale: 1, Draw.icon), to: URL(fileURLWithPath: path))
    exit(0)
}

if CommandLine.arguments.contains("--check-update") {            // prints what "Check for updates…" would find
    Updates.latest { tag in
        print("current \(Updates.current) latest \(tag ?? "unreachable") newer \(tag.map { Updates.newer($0, than: Updates.current) } ?? false)")
        print(Updates.newer("v2.0.1", than: "2.0.0"), Updates.newer("2.0.0", than: "2.0.0"), Updates.newer("1.9.9", than: "2.0"), Updates.newer("2.1", than: "2.0.9"))
        exit(0)
    }
    RunLoop.main.run()
}
if let dir = argValue("--preview") {
    let out = URL(fileURLWithPath: dir, isDirectory: true)
    for t in DayTime.allCases {
        writePNG(Wallpapers.render(width: 1440, height: 900, time: t, season: .winter, theme: "snow"),
                 to: out.appendingPathComponent("winter-\(t.rawValue)-\(t.title.lowercased().replacingOccurrences(of: " ", with: "-")).png"))
    }
    for (s, t) in [(Season.autumn, DayTime.golden), (.spring, .morning), (.summer, .dusk)] {
        writePNG(Wallpapers.render(width: 1440, height: 900, time: t, season: s, theme: ["autumn": "autumn", "spring": "sky", "summer": "fireflies"][s.rawValue] ?? ""),
                 to: out.appendingPathComponent("\(s.rawValue)-\(t.title.lowercased().replacingOccurrences(of: " ", with: "-")).png"))
    }
    let sheet = makeImage(960, 960, scale: 2) { c in
        c.setFillColor(rgb(0x2A2F66)); c.fill(CGRect(x: 0, y: 0, width: 960, height: 960))
        for (row, kind) in ["fox", "cat", "dog", "bunny", "panda", "hamster", "penguin", "egg"].enumerated() {
            for (col, sp) in [(0, 0, 0), (0, 1, row + 1), (0, 5, 0), (0, 7, 0), (0, 2, 0), (0, 4, 0), (0, 6, 0), (0, 8, 0), (2, 3, 0)].enumerated() {
                c.saveGState(); c.translateBy(x: 10 + CGFloat(col) * 105, y: 850 - CGFloat(row) * 104)
                Draw.pet(c, kind, phase: sp.0, eyes: sp.1, hat: sp.2 > 4 ? sp.2 - 4 : sp.2, scarf: col == 1 ? 0x4FB7A8 : nil); c.restoreGState()
            }
        }
        let items: [(CGFloat, (CGContext) -> Void)] = [(10, Draw.bun), (90, Draw.tree), (178, Draw.lantern), (232, Draw.gift)]
        for (x, draw) in items { c.saveGState(); c.translateBy(x: x, y: 6); draw(c); c.restoreGState() }
    }
    writePNG(sheet, to: out.appendingPathComponent("characters.png"))
    // Falling things and props, enlarged on a dark and a light ground, for checking the art.
    let bits: [Sprite] = [Art.snowDot] + Art.flakes + Art.leaves + [Art.petal, Art.blossom, Art.drop, Art.ring, Art.twinkle, Art.meteor,
                          Art.firefly, Art.laptop, Art.book, Art.phones, Art.umbrella, Art.rocket, Art.cloud, Art.bubble, Art.wheel,
                          Art.car(0xF4727E), Art.wagon, Art.board, Art.sled, Art.butterfly]
    let parts = makeImage(1200, 520, scale: 2) { c in
        c.setFillColor(rgb(0x2A2F66)); c.fill(CGRect(x: 0, y: 260, width: 1200, height: 260))
        c.setFillColor(rgb(0xF2F3F7)); c.fill(CGRect(x: 0, y: 0, width: 1200, height: 260))
        for row in 0..<2 {
            var x: CGFloat = 12
            for (i, sp) in bits.enumerated() {
                let k: CGFloat = i < 14 ? 4 : 1.1
                let w = sp.size.width * k, h = min(230, sp.size.height * k), ww = w * h / (sp.size.height * k)
                if x + ww > 1190 { break }
                let tint: UInt32? = (4...6).contains(i) ? [0xE2703A, 0xD9A53C, 0xC9492F][i - 4] : nil
                let img = sp.tex.cgImage()
                let r = CGRect(x: x, y: CGFloat(row) * 260 + 15, width: ww, height: h)
                c.draw(img, in: r)
                if let t = tint { c.saveGState(); c.clip(to: r, mask: img); c.setBlendMode(.multiply); c.setFillColor(rgb(t)); c.fill(r); c.restoreGState() }
                x += ww + 10
            }
        }
    }
    writePNG(parts, to: out.appendingPathComponent("_parts.png"))
    writePNG(makeImage(1024, 1024, scale: 1, Draw.icon), to: out.appendingPathComponent("icon.png"))
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
delegate.debug = args.contains("--debug")
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
