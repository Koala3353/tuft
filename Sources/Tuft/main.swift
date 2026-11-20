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

if let dir = argValue("--preview") {
    let out = URL(fileURLWithPath: dir, isDirectory: true)
    for t in DayTime.allCases {
        writePNG(Wallpapers.render(width: 1440, height: 900, time: t, season: .winter),
                 to: out.appendingPathComponent("winter-\(t.rawValue)-\(t.title.lowercased().replacingOccurrences(of: " ", with: "-")).png"))
    }
    for (s, t) in [(Season.autumn, DayTime.golden), (.spring, .morning), (.summer, .dusk)] {
        writePNG(Wallpapers.render(width: 1440, height: 900, time: t, season: s),
                 to: out.appendingPathComponent("\(s.rawValue)-\(t.title.lowercased().replacingOccurrences(of: " ", with: "-")).png"))
    }
    let sheet = makeImage(540, 540, scale: 3) { c in
        c.setFillColor(rgb(0x2A2F66)); c.fill(CGRect(x: 0, y: 0, width: 540, height: 540))
        for (row, kind) in ["fox", "cat", "dog", "egg"].enumerated() {
            for (col, sp) in [(0, 0, 0), (0, 1, row + 1), (0, 2, 0), (0, 4, 0), (2, 3, 0)].enumerated() {
                c.saveGState(); c.translateBy(x: 10 + CGFloat(col) * 105, y: 430 - CGFloat(row) * 104)
                Draw.pet(c, kind, phase: sp.0, eyes: sp.1, hat: sp.2, scarf: col == 1 ? 0x4FB7A8 : nil); c.restoreGState()
            }
        }
        let items: [(CGFloat, (CGContext) -> Void)] = [(10, Draw.bun), (90, Draw.tree), (178, Draw.lantern), (232, Draw.gift)]
        for (x, draw) in items { c.saveGState(); c.translateBy(x: x, y: 6); draw(c); c.restoreGState() }
    }
    writePNG(sheet, to: out.appendingPathComponent("characters.png"))
    writePNG(makeImage(1024, 1024, scale: 1, Draw.icon), to: out.appendingPathComponent("icon.png"))
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
delegate.debug = args.contains("--debug")
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
