import AppKit
import SpriteKit

// MARK: - Drawing helpers (all coordinates are y-up, like SpriteKit)

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func mixHex(_ a: UInt32, _ b: UInt32, _ t: CGFloat) -> UInt32 {
    let t = max(0, min(1, t))
    func ch(_ s: UInt32) -> UInt32 {
        let x = CGFloat((a >> s) & 0xFF), y = CGFloat((b >> s) & 0xFF)
        return UInt32(x + (y - x) * t) & 0xFF
    }
    return (ch(16) << 16) | (ch(8) << 8) | ch(0)
}

func rnd(_ a: CGFloat, _ b: CGFloat) -> CGFloat { CGFloat.random(in: a...b) }

func makeImage(_ w: CGFloat, _ h: CGFloat, scale: CGFloat = 3, _ draw: (CGContext) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: Int(w * scale), height: Int(h * scale), bitsPerComponent: 8,
                        bytesPerRow: 0, space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    draw(ctx)
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

func ovalPath(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2), transform: nil)
}

func roundRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
    let rr = max(0, min(r, min(w, h) / 2 - 0.01))
    return CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: rr, cornerHeight: rr, transform: nil)
}

/// A chubby rounded cone: flat base, soft tip.
func gumdrop(_ cx: CGFloat, _ baseY: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let l = cx - w / 2, r = cx + w / 2, k = min(w, h) * 0.12
    p.move(to: CGPoint(x: l + k, y: baseY))
    p.addQuadCurve(to: CGPoint(x: l, y: baseY + k), control: CGPoint(x: l, y: baseY))
    p.addCurve(to: CGPoint(x: cx, y: baseY + h), control1: CGPoint(x: l, y: baseY + h * 0.55),
               control2: CGPoint(x: cx - w * 0.2, y: baseY + h))
    p.addCurve(to: CGPoint(x: r, y: baseY + k), control1: CGPoint(x: cx + w * 0.2, y: baseY + h),
               control2: CGPoint(x: r, y: baseY + h * 0.55))
    p.addQuadCurve(to: CGPoint(x: r - k, y: baseY), control: CGPoint(x: r, y: baseY))
    p.closeSubpath()
    return p
}

func starPath(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ inner: CGFloat) -> CGPath {
    let p = CGMutablePath()
    for i in 0..<10 {
        let a = CGFloat(i) * .pi / 5 + .pi / 2
        let rr = i % 2 == 0 ? r : inner
        let pt = CGPoint(x: cx + cos(a) * rr, y: cy + sin(a) * rr)
        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
    }
    p.closeSubpath()
    return p
}

func heartPath(_ cx: CGFloat, _ cy: CGFloat, _ s: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: cx, y: cy - s))
    p.addCurve(to: CGPoint(x: cx - s, y: cy + s * 0.3), control1: CGPoint(x: cx - s * 0.4, y: cy - s * 0.6),
               control2: CGPoint(x: cx - s, y: cy - s * 0.2))
    p.addArc(center: CGPoint(x: cx - s * 0.5, y: cy + s * 0.3), radius: s * 0.5, startAngle: .pi, endAngle: 0, clockwise: true)
    p.addArc(center: CGPoint(x: cx + s * 0.5, y: cy + s * 0.3), radius: s * 0.5, startAngle: .pi, endAngle: 0, clockwise: true)
    p.addCurve(to: CGPoint(x: cx, y: cy - s), control1: CGPoint(x: cx + s, y: cy - s * 0.2),
               control2: CGPoint(x: cx + s * 0.4, y: cy - s * 0.6))
    p.closeSubpath()
    return p
}

extension CGContext {
    func oval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ hex: UInt32, _ a: CGFloat = 1) {
        setFillColor(rgb(hex, a))
        fillEllipse(in: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    func paint(_ p: CGPath, _ hex: UInt32, _ a: CGFloat = 1) {
        addPath(p); setFillColor(rgb(hex, a)); fillPath()
    }

    /// Fill with a soft shadow crescent along the lower right edge.
    /// Soft volume: a light-to-shade gradient from the upper left to the lower right.
    func shaded(_ p: CGPath, _ base: UInt32, _ shade: UInt32, dx: CGFloat = -0.09, dy: CGFloat = 0.09) {
        let b = p.boundingBox
        saveGState()
        addPath(p); clip()
        let g = CGGradient(colorsSpace: sRGB, colors: [rgb(mixHex(base, 0xFFFFFF, 0.25)), rgb(base), rgb(shade)] as CFArray,
                           locations: [0, 0.48, 1])!
        drawLinearGradient(g, start: CGPoint(x: b.minX + b.width * 0.2, y: b.maxY),
                           end: CGPoint(x: b.maxX - b.width * 0.1, y: b.minY),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        restoreGState()
    }

    func glow(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ hex: UInt32, _ a: CGFloat) {
        let g = CGGradient(colorsSpace: sRGB, colors: [rgb(hex, a), rgb(hex, 0)] as CFArray, locations: [0, 1])!
        drawRadialGradient(g, startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                           endCenter: CGPoint(x: cx, y: cy), endRadius: r, options: [])
    }
}

// MARK: - Characters and decorations (original art, drawn in code)

enum Draw {
    /// Snow bun: a round snow bunny in a teal scarf. Box 72 x 90.
    static func bun(_ c: CGContext) {
        c.oval(36, 6, 24, 5, 0x1B2050, 0.16)
        for x in [26.0, 46.0] as [CGFloat] {
            c.shaded(ovalPath(x, 70, 6.5, 15), 0xFFFFFF, 0xD3E0F5)
            c.oval(x, 69, 3, 10, 0xF9C5D1)
        }
        c.shaded(ovalPath(36, 25, 25, 21), 0xFFFFFF, 0xD3E0F5)
        c.shaded(ovalPath(36, 50, 18, 17), 0xFFFFFF, 0xDCE7F8)
        c.paint(roundRect(43, 22, 9, 16, 4), 0x3E9C90)
        c.paint(roundRect(17, 33, 38, 9, 4.5), 0x4FB7A8)
        c.oval(36, 22, 2, 2, 0x9DB4D6); c.oval(36, 14, 2, 2, 0x9DB4D6)
        for x in [29.0, 43.0] as [CGFloat] {
            c.oval(x, 52, 2.5, 2.8, 0x3A3550)
            c.oval(x + 0.8, 53, 0.8, 0.8, 0xFFFFFF)
        }
        c.oval(36, 47.5, 2.2, 1.5, 0xF08FA8)
        c.oval(24.5, 47, 3.4, 2.4, 0xFFA8BE, 0.55); c.oval(47.5, 47, 3.4, 2.4, 0xFFA8BE, 0.55)
    }

    /// Chubby decorated tree. Box 80 x 112.
    static func tree(_ c: CGContext) {
        c.oval(40, 6, 26, 5, 0x1B2050, 0.16)
        c.paint(roundRect(35, 4, 10, 16, 3), 0x8A5A3C)
        let tiers: [(CGFloat, CGFloat, CGFloat)] = [(14, 66, 44), (38, 52, 38), (60, 38, 34)]
        for t in tiers {
            let g = gumdrop(40, t.0, t.1, t.2)
            c.shaded(g, 0x57AD8C, 0x377F6C)
            c.saveGState(); c.addPath(g); c.clip()
            c.oval(40, t.0 + t.2, t.1 * 0.34, t.2 * 0.4, 0xFFFFFF)
            c.restoreGState()
        }
        let baubles: [(CGFloat, CGFloat, UInt32)] = [(22, 24, 0xF4727E), (40, 20, 0xF7C948), (57, 25, 0x6FB7E9),
                                                     (30, 46, 0xF7C948), (50, 44, 0xF4727E), (40, 66, 0x6FB7E9)]
        for b in baubles {
            c.oval(b.0, b.1, 3.4, 3.4, b.2)
            c.oval(b.0 - 1, b.1 + 1, 1, 1, 0xFFFFFF, 0.8)
        }
        c.glow(40, 99, 16, 0xFFE08A, 0.6)
        c.paint(starPath(40, 99, 9, 4.2), 0xFFD65A)
    }

    /// Little post lantern with a warm light. Box 48 x 76.
    static func lantern(_ c: CGContext) {
        c.glow(24, 38, 30, 0xFFC96B, 0.55)
        c.oval(24, 5, 12, 3.5, 0x1B2050, 0.16)
        c.paint(roundRect(22, 4, 4, 20, 2), 0x4A4763)
        c.paint(roundRect(13, 22, 22, 4, 2), 0x4A4763)
        c.paint(roundRect(14, 25, 20, 24, 4), 0xFFD977)
        c.oval(24, 36, 6, 8, 0xFFF6C8)
        c.paint(roundRect(23.2, 25, 1.6, 24, 0.8), 0x4A4763)
        c.paint(gumdrop(24, 48, 30, 14), 0x4A4763)
        c.saveGState(); c.addPath(gumdrop(24, 48, 30, 14)); c.clip()
        c.oval(24, 63, 10, 6, 0xFFFFFF)
        c.restoreGState()
        c.oval(24, 64, 2, 2, 0x4A4763)
    }

    /// Wrapped gift. Box 56 x 54.
    static func gift(_ c: CGContext) {
        c.oval(28, 5, 22, 4, 0x1B2050, 0.16)
        c.shaded(roundRect(9, 4, 38, 28, 5), 0xF4727E, 0xD9566A)
        c.paint(roundRect(24.5, 4, 7, 28, 0), 0xFFE9A8)
        c.shaded(roundRect(6, 29, 44, 10, 4), 0xFF8C96, 0xE86C7C)
        c.paint(roundRect(24.5, 29, 7, 10, 0), 0xFFF2C4)
        c.shaded(ovalPath(20, 43, 8, 5.5), 0xFFE9A8, 0xF2CF7A)
        c.shaded(ovalPath(36, 43, 8, 5.5), 0xFFE9A8, 0xF2CF7A)
        c.oval(28, 42, 3.6, 3.6, 0xF7C948)
    }

    struct Coat {
        var body: UInt32, shade: UInt32, legs: UInt32
        var earTip: UInt32? = nil
        var innerEar: UInt32 = 0xFFD9C2
        var floppy = false
        var tail = 0            // 0 fluffy, 1 thin, 2 stub
        var scarf: UInt32
        var collar = false
        var patch: UInt32? = nil
        var whiskers = false
        var tongue = false
        var iris: UInt32 = 0x5A3A22
        var stripes: UInt32? = nil
        var fluff = false
        var earKind = 0         // 0 pointed, 2 long, 3 round
        var earColor: UInt32? = nil
        var eyePatch: UInt32? = nil
    }

    static let mixable = ["fox", "cat", "dog", "bunny", "hamster"]

    static func coat(_ kind: String) -> Coat {
        // A baby of two different parents, "fox+cat": the build of the first in the colours of the second.
        let pair = kind.split(separator: "+").map(String.init)
        if pair.count == 2 {
            var k = coat(pair[0])
            let o = coat(pair[1])
            k.body = o.body; k.shade = o.shade; k.legs = o.legs; k.stripes = o.stripes; k.patch = o.patch
            k.innerEar = o.innerEar; k.iris = o.iris
            if k.earTip != nil { k.earTip = o.legs }
            if k.earColor != nil { k.earColor = o.legs }
            return k
        }
        switch kind {
        case "cat": return Coat(body: 0xA4ADC4, shade: 0x848DA8, legs: 0x6F7893, innerEar: 0xFFC9D6, tail: 1,
                                scarf: 0xF4727E, collar: true, whiskers: true, iris: 0x4E9A63, stripes: 0x7C849E, fluff: true)
        case "dog": return Coat(body: 0xEBC48A, shade: 0xD0A468, legs: 0xB88A50, floppy: true, tail: 2,
                                scarf: 0x6FB7E9, collar: true, patch: 0x9A6B4F, tongue: true)
        case "bunny": return Coat(body: 0xFFF3E6, shade: 0xEAD3BF, legs: 0xE2C4AC, innerEar: 0xFFC9D6, tail: 2,
                                  scarf: 0x8CC8F2, iris: 0x7A4B3A, fluff: true, earKind: 2)
        case "panda": return Coat(body: 0xFFFFFF, shade: 0xD9E0EC, legs: 0x2E2B38, innerEar: 0x4A4658, tail: 2,
                                  scarf: 0xE8607A, iris: 0x3A2A22, earKind: 3, earColor: 0x2E2B38, eyePatch: 0x2E2B38)
        case "hamster": return Coat(body: 0xF2C27E, shade: 0xD9A35C, legs: 0xD9A35C, innerEar: 0xFFC9D6, tail: 3,
                                    scarf: 0x57AD8C, collar: true, iris: 0x3A2A22, fluff: true, earKind: 3)
        default: return Coat(body: 0xF39445, shade: 0xDB7430, legs: 0x5A3A2E, earTip: 0x5A3A2E, scarf: 0xF7C948, iris: 0x9A5A1F, fluff: true)
        }
    }

    /// Pets face right. Box 100 x 80. phase 0/1 = walk frames, 2 = sitting / eyes closed.
    static var iris: UInt32 = 0x5A3A22
    static var shadow = true           // off when the app draws the shadow itself
    static var ink: UInt32 = 0x3A3550  // line colour for drawn eyes
    static var rim: UInt32 = 0x2A2438

    /// eyes: 0 open, 1 happy, 2 wide (surprised), 3 closed, 4 sad, 5 laughing, 6 crying, 7 hearts, 8 dizzy.
    static func eyes(_ c: CGContext, _ xs: [CGFloat], _ y: CGFloat, _ mode: Int, _ r: CGFloat) {
        c.setStrokeColor(rgb(Draw.ink)); c.setLineWidth(1.7); c.setLineCap(.round); c.setLineJoin(.round)
        let mid = xs.reduce(0, +) / CGFloat(xs.count)
        for x in xs {
            let d: CGFloat = x < mid ? 1 : -1                  // points toward the nose
            switch mode {
            case 5:                                            // squeezed shut with laughter: > <
                c.move(to: CGPoint(x: x - d * r * 0.8, y: y + r * 0.95)); c.addLine(to: CGPoint(x: x + d * r * 0.8, y: y))
                c.addLine(to: CGPoint(x: x - d * r * 0.8, y: y - r * 0.95)); c.strokePath()
            case 6:                                            // shut tight, tears running
                c.paint(roundRect(x - d * r * 0.45 - 1.4, y - r * 3.1, 2.8, r * 2.9, 1.4), 0x8FD0FF, 0.92)
                c.oval(x - d * r * 0.45, y - r * 3.2, 2, 2.4, 0x8FD0FF)
                c.oval(x - d * r * 0.45 - 0.5, y - r * 2.9, 0.6, 0.8, 0xFFFFFF, 0.9)
                c.move(to: CGPoint(x: x - d * r * 1.05, y: y - r * 0.4))
                c.addQuadCurve(to: CGPoint(x: x + d * r * 0.95, y: y + r * 0.5), control: CGPoint(x: x, y: y + r * 0.55))
                c.strokePath()
            case 7:
                c.paint(heartPath(x, y - r * 0.1, r * 1.15), 0xFF5C8A)
                c.oval(x - r * 0.45, y + r * 0.5, r * 0.3, r * 0.3, 0xFFFFFF, 0.9)
            case 8:                                            // swirls
                c.addArc(center: CGPoint(x: x, y: y), radius: r, startAngle: 0, endAngle: 4.9, clockwise: false); c.strokePath()
                c.addArc(center: CGPoint(x: x, y: y), radius: r * 0.4, startAngle: 2, endAngle: 6.6, clockwise: false); c.strokePath()
            case 1:
                c.addArc(center: CGPoint(x: x, y: y - 1), radius: r * 0.85, startAngle: 0.25, endAngle: .pi - 0.25, clockwise: false)
                c.strokePath()
            case 3:
                c.addArc(center: CGPoint(x: x, y: y + 1.5), radius: r * 0.8, startAngle: .pi + 0.35, endAngle: 2 * .pi - 0.35, clockwise: false)
                c.strokePath()
            case 2:
                c.oval(x, y, r * 1.2, r * 1.3, 0xFFFFFF)
                c.oval(x, y, r * 0.55, r * 0.6, 0x3A3550)
                c.oval(x + r * 0.2, y + r * 0.25, r * 0.18, r * 0.18, 0xFFFFFF)
            case 4:   // sad: worried brows over normal eyes
                let sg: CGFloat = -d
                c.move(to: CGPoint(x: x + sg * r, y: y + r * 1.5)); c.addLine(to: CGPoint(x: x - sg * r * 0.5, y: y + r * 2.1))
                c.strokePath()
                fallthrough
            default:                                   // dark rim, coloured iris, pupil, two catchlights
                c.oval(x, y, r * 1.08, r * 1.22, Draw.rim)
                c.oval(x, y - r * 0.1, r * 0.86, r * 0.98, Draw.iris)
                c.oval(x, y, r * 0.52, r * 0.62, 0x1A1522)
                c.oval(x + r * 0.34, y + r * 0.46, r * 0.4, r * 0.4, 0xFFFFFF)
                c.oval(x - r * 0.36, y - r * 0.42, r * 0.2, r * 0.2, 0xFFFFFF, 0.9)
            }
        }
    }

    /// The mouth for each expression; `y` is the line of the resting smile.
    static func mouth(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ mode: Int, dark: UInt32 = 0x5A3A2E, tongue: Bool = false) {
        c.setStrokeColor(rgb(dark)); c.setLineWidth(1.15); c.setLineCap(.round); c.setLineJoin(.round)
        switch mode {
        case 1: c.paint(roundRect(x - 2.6, y - 4.2, 5.2, 4.6, 2.3), 0xE8607A)
        case 2: c.oval(x, y - 2.2, 1.5, 1.8, dark)
        case 4:
            c.addArc(center: CGPoint(x: x, y: y - 4.2), radius: 2.2, startAngle: 0.4, endAngle: .pi - 0.4, clockwise: false)
            c.strokePath()
        case 5:                                                // wide open laugh
            let p = CGMutablePath()
            p.move(to: CGPoint(x: x - 4.6, y: y + 0.2)); p.addLine(to: CGPoint(x: x + 4.6, y: y + 0.2))
            p.addCurve(to: CGPoint(x: x - 4.6, y: y + 0.2), control1: CGPoint(x: x + 4.4, y: y - 8.2), control2: CGPoint(x: x - 4.4, y: y - 8.2))
            c.paint(p, 0x8A2F45)
            c.saveGState(); c.addPath(p); c.clip()
            c.oval(x, y - 6.2, 3.2, 2.4, 0xFF8FA3)
            c.restoreGState()
        case 6:                                                // wobbly wail
            c.oval(x, y - 3.4, 3, 3.4, 0x8A2F45)
            c.oval(x, y - 5.4, 2, 1.3, 0xFF8FA3)
        case 8:
            c.move(to: CGPoint(x: x - 4, y: y - 2.6)); c.addLine(to: CGPoint(x: x - 2, y: y - 1.2))
            c.addLine(to: CGPoint(x: x, y: y - 2.6)); c.addLine(to: CGPoint(x: x + 2, y: y - 1.2)); c.addLine(to: CGPoint(x: x + 4, y: y - 2.6))
            c.strokePath()
        default:
            if tongue && mode != 3 { c.paint(roundRect(x - 1.8, y - 4.7, 3.6, 4.6, 1.8), 0xFF8FA3) }
            for sgn in [-1.0, 1.0] as [CGFloat] {              // tiny "w" smile
                c.addArc(center: CGPoint(x: x + sgn * 1.7, y: y), radius: 1.7, startAngle: .pi + 0.2,
                         endAngle: 2 * .pi - 0.2, clockwise: false)
                c.strokePath()
            }
        }
    }

    /// Hats sit on the head: 1 beanie, 2 party hat, 3 crown, 4 flower.
    static func hat(_ c: CGContext, _ type: Int, _ cx: CGFloat, _ by: CGFloat) {
        switch type {
        case 1:
            let dome = CGMutablePath()
            dome.move(to: CGPoint(x: cx - 15, y: by))
            dome.addCurve(to: CGPoint(x: cx + 15, y: by), control1: CGPoint(x: cx - 14, y: by + 17), control2: CGPoint(x: cx + 14, y: by + 17))
            dome.closeSubpath()
            c.shaded(dome, 0xE8607A, 0xC9475F)
            c.paint(roundRect(cx - 16.5, by - 2.5, 33, 5.5, 2.7), 0xFFF1DC)
            c.oval(cx, by + 13.5, 4.2, 4.2, 0xFFFFFF)
        case 2:
            c.shaded(gumdrop(cx, by - 1, 15, 21), 0x6FB7E9, 0x4F97CC)
            c.oval(cx - 2.5, by + 5, 1.5, 1.5, 0xFFD65A); c.oval(cx + 2, by + 10, 1.3, 1.3, 0xFFA8BE)
            c.oval(cx, by + 20, 3.2, 3.2, 0xFFD65A)
        case 3:
            let p = CGMutablePath()
            for (i, pt) in ([(-10, -1), (-11.5, 10), (-5.5, 5), (0, 12), (5.5, 5), (11.5, 10), (10, -1)] as [(CGFloat, CGFloat)]).enumerated() {
                let q = CGPoint(x: cx + pt.0, y: by + pt.1)
                if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
            }
            p.closeSubpath()
            c.shaded(p, 0xFFD65A, 0xE8B22E)
            c.oval(cx, by + 3, 1.6, 1.6, 0xF4727E); c.oval(cx - 6, by + 2.5, 1.2, 1.2, 0x6FB7E9); c.oval(cx + 6, by + 2.5, 1.2, 1.2, 0x6FB7E9)
        case 4:
            for i in 0..<5 {
                let a = CGFloat(i) * 2 * .pi / 5 + 0.3
                c.oval(cx + 9 + cos(a) * 3.8, by + 3 + sin(a) * 3.8, 3.1, 3.1, 0xFFB7CE)
            }
            c.oval(cx + 9, by + 3, 2.5, 2.5, 0xFFD65A)
        default: break
        }
    }

    static func pet(_ c: CGContext, _ kind: String, phase: Int, eyes: Int = 0, hat: Int = 0, scarf: UInt32? = nil) {
        if kind == "egg" { egg(c, phase: phase, eyes: eyes, hat: hat); return }
        if kind == "penguin" { penguin(c, phase: phase, eyes: eyes, hat: hat); return }
        var k = coat(kind)
        if let sc = scarf { k.scarf = sc }
        if kind == "panda" { panda(c, phase: phase, eyes: eyes, hat: hat, scarf: k.scarf); return }
        Draw.iris = k.iris
        let dark: UInt32 = 0x5A3A2E
        let sit = phase == 2
        if Draw.shadow { c.oval(50, 5, 28, 4, 0x1B2050, 0.16) }
        // tail
        switch k.tail {
        case 3: break                                              // no tail to speak of
        case 1:
            c.setStrokeColor(rgb(k.body)); c.setLineWidth(6.5); c.setLineCap(.round)
            if sit {
                c.move(to: CGPoint(x: 40, y: 9)); c.addQuadCurve(to: CGPoint(x: 15, y: 17), control: CGPoint(x: 20, y: 3))
            } else {
                c.move(to: CGPoint(x: 29, y: 30))
                c.addQuadCurve(to: CGPoint(x: 13, y: phase == 0 ? 56 : 51), control: CGPoint(x: 7, y: 30))
            }
            c.strokePath()
        case 2:
            c.saveGState()
            if sit { c.translateBy(x: 33, y: 13); c.rotate(by: 0.15) } else {
                c.translateBy(x: 27, y: 37); c.rotate(by: phase == 0 ? 0.5 : 1.0)
            }
            c.shaded(ovalPath(-4, 0, 9, 4.5), k.body, k.shade)
            c.restoreGState()
        default:
            if sit {
                c.shaded(ovalPath(30, 14, 18, 9), k.body, k.shade)
                c.oval(15, 14, 7, 6, 0xFFF6EA)
            } else {
                c.saveGState()
                c.translateBy(x: 20, y: 34); c.rotate(by: phase == 0 ? 0.45 : 0.6)
                c.shaded(ovalPath(0, 0, 17, 10), k.body, k.shade)
                c.oval(-11, 0, 7.5, 7, 0xFFF6EA)
                c.restoreGState()
            }
        }
        // legs
        if sit {
            for x in [52.0, 62.0] as [CGFloat] { c.paint(roundRect(x, 5, 7, 14, 3.5), k.legs) }
        } else {
            let offs: [CGFloat] = phase == 0 ? [3, -2, 3, -2] : [-2, 3, -2, 3]
            let lift: [CGFloat] = phase == 0 ? [0, 2.5, 0, 2.5] : [2.5, 0, 2.5, 0]
            for (i, x) in ([34, 42, 55, 63] as [CGFloat]).enumerated() {
                c.paint(roundRect(x + offs[i], 5 + lift[i], 6.5, 14, 3.2), k.legs)
            }
        }
        // body
        let body = sit ? ovalPath(50, 25, 17, 18) : ovalPath(49, 26, 21.5, 13.5)
        c.shaded(body, k.body, k.shade)
        c.saveGState(); c.addPath(body); c.clip()
        c.oval(sit ? 56 : 52, sit ? 20 : 19, sit ? 10 : 15, sit ? 14 : 7, 0xFFF6EA)
        if let st = k.stripes {                                    // tabby stripes along the back
            for (x, y) in (sit ? [(40, 34), (45, 40)] : [(36, 37), (44, 39), (52, 39)]) as [(CGFloat, CGFloat)] {
                c.saveGState(); c.translateBy(x: x, y: y); c.rotate(by: -0.25)
                c.oval(0, 0, 2, 6, st, 0.65)
                c.restoreGState()
            }
        }
        c.restoreGState()
        if k.fluff {                                               // chest fluff
            for (x, y, r) in [(57, 28, 4.6), (62, 26, 5.2), (66, 28, 4.4)] as [(CGFloat, CGFloat, CGFloat)] {
                c.oval(x, sit ? y + 1 : y, r, r * 1.1, 0xFFF6EA)
            }
        }
        // scarf or collar
        if k.collar {
            c.paint(roundRect(55, 33.5, 19, 5.5, 2.7), k.scarf)
            c.oval(63, 32, 2.8, 2.8, 0xF7C948)
        } else {
            c.paint(roundRect(54, 33, 20, 7, 3.5), k.scarf)
            c.paint(roundRect(55, 24, 7, 12, 3), mixHex(k.scarf, 0x8A5A00, 0.18))
        }
        let hx: CGFloat = 70, hy: CGFloat = sit ? 52 : 50
        if !k.floppy {
            for (ex, tilt) in [(hx - 12.5, -0.28), (hx + 12.5, 0.28)] as [(CGFloat, CGFloat)] {
                c.saveGState()
                c.translateBy(x: ex, y: hy + 11); c.rotate(by: -tilt)
                if k.earKind == 2 {                                    // long bunny ears
                    c.shaded(ovalPath(0, 13, 5.6, 15.5), k.earColor ?? k.body, k.shade)
                    c.oval(0, 13, 2.7, 11, k.innerEar)
                } else if k.earKind == 3 {                             // small round ears
                    c.oval(0, 1.5, 8, 8, k.earColor ?? k.body)
                    c.oval(0, 1.5, 4.2, 4.2, k.innerEar)
                } else {
                    c.paint(gumdrop(0, 0, 13, 17), k.body)
                    if let tip = k.earTip {
                        c.saveGState(); c.addPath(gumdrop(0, 0, 13, 17)); c.clip()
                        c.oval(0, 17, 6, 6, tip)
                        c.restoreGState()
                    }
                    c.paint(gumdrop(0, 0, 6, 9), k.innerEar)
                }
                c.restoreGState()
            }
        }
        // head
        let head = ovalPath(hx, hy, 21.5, 18.5)
        c.shaded(head, k.body, k.shade, dx: -0.06, dy: 0.06)
        c.saveGState(); c.addPath(head); c.clip()
        if k.floppy { c.oval(hx, hy - 10.5, 13.5, 10.5, 0xFFF6EA) } else {
            c.oval(hx - 10, hy - 10.5, 12, 10, 0xFFF6EA); c.oval(hx + 10, hy - 10.5, 12, 10, 0xFFF6EA)
        }
        if let patch = k.patch { c.oval(hx + 10, hy + 3, 8.5, 9.5, patch) }
        c.oval(hx - 6, hy + 9, 8, 4.5, 0xFFFFFF, 0.16)             // soft forehead light
        if let st = k.stripes {
            c.setStrokeColor(rgb(st, 0.75)); c.setLineWidth(1.6); c.setLineCap(.round)
            for dx in [-4.5, 0, 4.5] as [CGFloat] {
                c.move(to: CGPoint(x: hx + dx, y: hy + 18)); c.addLine(to: CGPoint(x: hx + dx * 0.8, y: hy + 12.5))
            }
            c.strokePath()
        }
        c.restoreGState()
        if k.fluff {                                               // cheek tufts
            for sgn in [-1.0, 1.0] as [CGFloat] {
                c.saveGState()
                c.translateBy(x: hx + sgn * 17, y: hy - 8.5); c.rotate(by: -sgn * 2.15)
                c.paint(gumdrop(0, -2, 7.5, 8), 0xFFF6EA)
                c.restoreGState()
            }
        }
        if k.floppy {
            for sgn in [-1.0, 1.0] as [CGFloat] {
                c.saveGState()
                c.translateBy(x: hx + sgn * 20, y: hy + 3); c.rotate(by: sgn * 0.22)
                c.shaded(ovalPath(0, 0, 6.2, 11.5), 0x9A6B4F, 0x7E543B)
                c.restoreGState()
            }
        }
        if let ep = k.eyePatch {                                   // panda eye patches
            for sgn in [-1.0, 1.0] as [CGFloat] {
                c.saveGState(); c.translateBy(x: hx + sgn * 9.5, y: hy); c.rotate(by: sgn * 0.35)
                c.oval(0, 0, 6.2, 7.8, ep)
                c.restoreGState()
            }
        }
        Draw.eyes(c, [hx - 9.5, hx + 9.5], hy + 0.5, eyes, 3.7)
        c.oval(hx, hy - 5.5, 2.3, 1.6, dark)
        c.oval(hx - 0.7, hy - 5, 0.8, 0.5, 0xFFFFFF, 0.7)
        Draw.mouth(c, hx, hy - 7.3, eyes, dark: dark, tongue: k.tongue)
        if k.whiskers {
            c.setStrokeColor(rgb(0xFFFFFF, 0.85)); c.setLineWidth(0.8); c.setLineCap(.round)
            for sgn in [-1.0, 1.0] as [CGFloat] {
                for dy in [1.5, -2.5] as [CGFloat] {
                    c.move(to: CGPoint(x: hx + sgn * 14, y: hy - 7)); c.addLine(to: CGPoint(x: hx + sgn * 25, y: hy - 7 + dy))
                }
            }
            c.strokePath()
        }
        c.oval(hx - 16, hy - 6, 4, 2.7, 0xFF9DB0, 0.7); c.oval(hx + 16, hy - 6, 4, 2.7, 0xFF9DB0, 0.7)
        Draw.hat(c, hat, hx, hy + 14)
    }

    /// Panda pet: a round bear that sits up and waddles on two feet.
    static func panda(_ c: CGContext, phase: Int, eyes: Int = 0, hat: Int = 0, scarf: UInt32 = 0xE8607A) {
        let sit = phase == 2, blk: UInt32 = 0x3A3646, blkS: UInt32 = 0x211F2B, fur: UInt32 = 0xFFFFFF, furS: UInt32 = 0xD3DBEA
        if Draw.shadow { c.oval(50, 5, 26, 4, 0x1B2050, 0.16) }
        c.saveGState()
        c.translateBy(x: 50, y: 6); c.rotate(by: sit ? 0 : (phase == 0 ? -0.07 : 0.07))
        if sit {                                                       // feet out in front, soles showing
            for s in [-1.0, 1.0] as [CGFloat] {
                c.shaded(ovalPath(s * 15, 5.5, 8.5, 7.2), blk, blkS)
                c.oval(s * 15, 4.6, 4.2, 3.3, 0x7A748C)
                for dx in [-3.6, 0, 3.6] as [CGFloat] { c.oval(s * 15 + dx, 9.6, 1.35, 1.25, 0x7A748C) }
            }
        } else {
            c.shaded(ovalPath(-10.5, phase == 0 ? 2.5 : 5.5, 9.5, 6.5), blk, blkS)
            c.shaded(ovalPath(10.5, phase == 0 ? 5.5 : 2.5, 9.5, 6.5), blk, blkS)
        }
        if !sit {
            for s in [-1.0, 1.0] as [CGFloat] {                        // arms swing as it walks
                c.saveGState()
                c.translateBy(x: s * 19, y: 30); c.rotate(by: s * 0.3 + (phase == 0 ? 0.16 : -0.16))
                c.shaded(ovalPath(0, -7, 6.5, 12), blk, blkS)
                c.restoreGState()
            }
        }
        let body = ovalPath(0, 22, 21.5, 20)
        c.shaded(body, fur, furS)
        c.saveGState(); c.addPath(body); c.clip()
        c.oval(0, 42, 26, 10.5, blk)                                   // the dark band across the shoulders
        c.restoreGState()
        if sit {
            for s in [-1.0, 1.0] as [CGFloat] {                        // paws resting on the tummy
                c.saveGState()
                c.translateBy(x: s * 15, y: 27); c.rotate(by: -s * 0.75)
                c.shaded(ovalPath(0, -4, 6, 11), blk, blkS)
                c.restoreGState()
            }
        }
        c.paint(roundRect(-15, 34.5, 30, 6.5, 3.2), scarf)
        c.paint(roundRect(6, 25.5, 7, 12, 3), mixHex(scarf, 0x8A5A00, 0.18))
        let hy: CGFloat = 51
        for s in [-1.0, 1.0] as [CGFloat] {
            c.shaded(ovalPath(s * 17.5, hy + 14.5, 8.2, 8.2), blk, blkS)
            c.oval(s * 17.5, hy + 14, 3.6, 3.6, 0x5E5870)
        }
        let head = ovalPath(0, hy, 24, 19.5)
        c.shaded(head, fur, furS, dx: -0.06, dy: 0.06)
        for s in [-1.0, 1.0] as [CGFloat] {                            // teardrop patches, tilted toward the nose
            c.saveGState()
            c.translateBy(x: s * 10, y: hy + 0.5); c.rotate(by: s * 0.5)
            c.shaded(ovalPath(0, 0, 6.4, 8.4), blk, blkS)
            c.restoreGState()
        }
        let keep = (Draw.ink, Draw.rim, Draw.iris)
        Draw.ink = 0xFFFFFF; Draw.rim = 0x9A94B2; Draw.iris = 0x4A4560
        Draw.eyes(c, [-9.4, 9.4], hy + 1.2, eyes, 3.2)
        (Draw.ink, Draw.rim, Draw.iris) = keep
        c.oval(0, hy - 6.6, 8.4, 6, 0xFFFFFF)                          // muzzle
        c.paint(roundRect(-3.1, hy - 5.6, 6.2, 3.7, 1.8), 0x2A2733)
        c.oval(-0.9, hy - 3, 0.9, 0.55, 0xFFFFFF, 0.7)
        Draw.mouth(c, 0, hy - 8.4, eyes, dark: 0x2A2733)
        c.oval(-17, hy - 6.5, 4, 2.6, 0xFF9DB0, 0.75); c.oval(17, hy - 6.5, 4, 2.6, 0xFF9DB0, 0.75)
        Draw.hat(c, hat, 0, hy + 15.5)
        c.restoreGState()
    }

    /// Penguin pet: stands upright and waddles.
    static func penguin(_ c: CGContext, phase: Int, eyes: Int = 0, hat: Int = 0) {
        Draw.iris = 0x3A2A22
        let sit = phase == 2
        if Draw.shadow { c.oval(50, 5, 22, 4, 0x1B2050, 0.16) }
        c.oval(sit ? 43 : (phase == 0 ? 41 : 44), sit ? 7 : (phase == 0 ? 6 : 8.5), 6.5, 3.4, 0xF7A84A)
        c.oval(sit ? 57 : (phase == 0 ? 57 : 60), sit ? 7 : (phase == 0 ? 8.5 : 6), 6.5, 3.4, 0xF7A84A)
        c.saveGState()
        c.translateBy(x: 50, y: 7); c.rotate(by: sit ? 0 : (phase == 0 ? -0.08 : 0.08))
        for sgn in [-1.0, 1.0] as [CGFloat] {                          // flippers
            c.saveGState()
            c.translateBy(x: sgn * 20, y: 32); c.rotate(by: sgn * (sit ? 0.2 : (phase == 0 ? 0.55 : 0.15)))
            c.shaded(ovalPath(0, -7, 5, 13), 0x44558C, 0x2A3760)
            c.restoreGState()
        }
        let body = ovalPath(0, 30, 22, 30)
        c.shaded(body, 0x4A5C96, 0x2A3760)
        c.saveGState(); c.addPath(body); c.clip()
        c.oval(0, 21, 15.5, 25, 0xFFF9F0)
        c.restoreGState()
        Draw.eyes(c, [-8, 8], 39, eyes, 3.5)
        if eyes == 5 || eyes == 6 { c.oval(0, 28.6, 3.4, 2.8, 0x8A2F45) }   // beak open
        c.paint(gumdrop(0, 29.5, 8, 5.5), 0xF7A84A)                    // beak
        c.oval(-14.5, 32, 3.6, 2.4, 0xFF9DB0, 0.7); c.oval(14.5, 32, 3.6, 2.4, 0xFF9DB0, 0.7)
        Draw.hat(c, hat, 0, 57)
        c.restoreGState()
    }

    /// Egg pet: a speckled egg on two little feet with a sprout on top.
    static func egg(_ c: CGContext, phase: Int, eyes: Int = 0, hat: Int = 0) {
        Draw.iris = 0x6B4A2E
        let sit = phase == 2
        if Draw.shadow { c.oval(50, 5, 20, 4, 0x1B2050, 0.16) }
        if sit {
            c.oval(43, 7, 5, 3, 0xF7A84A); c.oval(57, 7, 5, 3, 0xF7A84A)
        } else {
            c.oval(phase == 0 ? 40 : 44, phase == 0 ? 6 : 8.5, 5.5, 3.2, 0xF7A84A)
            c.oval(phase == 0 ? 56 : 60, phase == 0 ? 8.5 : 6, 5.5, 3.2, 0xF7A84A)
        }
        c.saveGState()
        c.translateBy(x: 50, y: 8); c.rotate(by: sit ? 0 : (phase == 0 ? -0.09 : 0.09))
        let e = CGMutablePath()
        e.move(to: CGPoint(x: 0, y: 0))
        e.addCurve(to: CGPoint(x: -22, y: 24), control1: CGPoint(x: -14, y: 0), control2: CGPoint(x: -22, y: 10))
        e.addCurve(to: CGPoint(x: 0, y: 60), control1: CGPoint(x: -22, y: 44), control2: CGPoint(x: -12, y: 60))
        e.addCurve(to: CGPoint(x: 22, y: 24), control1: CGPoint(x: 12, y: 60), control2: CGPoint(x: 22, y: 44))
        e.addCurve(to: CGPoint(x: 0, y: 0), control1: CGPoint(x: 22, y: 10), control2: CGPoint(x: 14, y: 0))
        c.paint(gumdrop(0, 58, 7, 9), 0x6FCB8E)
        c.shaded(e, 0xFFF6E0, 0xEBD9B4)
        c.saveGState(); c.addPath(e); c.clip()
        c.oval(-13, 45, 4, 3, 0xBFE3F5); c.oval(10, 51, 3, 2.4, 0xFFC9D6)
        c.oval(15, 12, 4, 3, 0xCDEBC0); c.oval(-14, 10, 3, 2.5, 0xFFE08A)
        c.restoreGState()
        Draw.eyes(c, [-8.5, 8.5], 28, eyes, 3.6)
        Draw.mouth(c, 0, 23.5, eyes, dark: 0x3A3550)
        c.oval(-15, 22, 3.8, 2.6, 0xFF9DB0, 0.7); c.oval(15, 22, 3.8, 2.6, 0xFF9DB0, 0.7)
        Draw.hat(c, hat, 0, 55)
        c.restoreGState()
    }

    /// Snowman made by rolling a snowball. Box 64 x 96.
    static func snowman(_ c: CGContext) {
        c.oval(32, 6, 26, 5, 0x1B2050, 0.16)
        c.setStrokeColor(rgb(0x8A5A3C)); c.setLineWidth(2.2); c.setLineCap(.round)
        c.move(to: CGPoint(x: 12, y: 36)); c.addLine(to: CGPoint(x: 1, y: 50))
        c.move(to: CGPoint(x: 5, y: 45)); c.addLine(to: CGPoint(x: 1, y: 42))
        c.move(to: CGPoint(x: 52, y: 36)); c.addLine(to: CGPoint(x: 63, y: 50))
        c.move(to: CGPoint(x: 59, y: 45)); c.addLine(to: CGPoint(x: 63, y: 42))
        c.strokePath()
        c.shaded(ovalPath(32, 27, 24, 23), 0xFFFFFF, 0xD3E0F5)
        c.shaded(ovalPath(32, 60, 16.5, 15.5), 0xFFFFFF, 0xDCE7F8)
        c.paint(roundRect(40, 32, 8, 16, 4), 0xC9475F)
        c.paint(roundRect(15, 44, 34, 8, 4), 0xE8607A)
        for y in [20.0, 30.0] as [CGFloat] { c.oval(32, y, 2.2, 2.2, 0x3A3550) }
        c.oval(26, 63, 2.3, 2.6, 0x3A3550); c.oval(38, 63, 2.3, 2.6, 0x3A3550)
        let nose = CGMutablePath()
        nose.move(to: CGPoint(x: 31, y: 60)); nose.addLine(to: CGPoint(x: 31, y: 55.5)); nose.addLine(to: CGPoint(x: 44, y: 57))
        nose.closeSubpath()
        c.paint(nose, 0xF7A84A)
        c.oval(22, 57, 3, 2.2, 0xFFA8BE, 0.6)
        c.paint(roundRect(18, 72, 28, 4, 2), 0x3A4A7A)
        c.shaded(roundRect(22, 74, 20, 15, 3), 0x4A5C92, 0x3A4A7A)
        c.paint(roundRect(22, 76, 20, 3.5, 0), 0xF7C948)
    }

    static func icon(_ c: CGContext) {
        let r = roundRect(46, 46, 932, 932, 210)
        c.saveGState(); c.addPath(r); c.clip()
        let g = CGGradient(colorsSpace: sRGB, colors: [rgb(0xF6A6B8), rgb(0x6D5BB5), rgb(0x1E2456)] as CFArray,
                           locations: [0, 0.45, 1])!
        c.drawLinearGradient(g, start: CGPoint(x: 0, y: 120), end: CGPoint(x: 0, y: 1000), options: [])
        for s in [(210, 800, 9), (330, 890, 6), (820, 760, 7), (700, 880, 5), (540, 820, 5)] as [(CGFloat, CGFloat, CGFloat)] {
            c.oval(s.0, s.1, s.2, s.2, 0xFFFFFF, 0.9)
        }
        c.glow(770, 800, 150, 0xFFF3C4, 0.35)
        c.oval(770, 800, 62, 62, 0xFFF3C4)
        c.oval(512, 30, 760, 290, 0xFFFFFF)
        c.translateBy(x: 512 - 36 * 7.6, y: 190); c.scaleBy(x: 7.6, y: 7.6)
        bun(c)
        c.restoreGState()
    }
}

// MARK: - Textures

struct Sprite {
    let tex: SKTexture
    let size: CGSize
    init(_ w: CGFloat, _ h: CGFloat, _ draw: (CGContext) -> Void) {
        tex = SKTexture(cgImage: makeImage(w, h, scale: 2, draw))
        size = CGSize(width: w, height: h)
    }
}

enum Art {
    static let dot = Sprite(8, 8) { c in c.glow(4, 4, 4, 0xFFFFFF, 1); c.oval(4, 4, 2.4, 2.4, 0xFFFFFF, 0.9) }
    static let glow = Sprite(24, 24) { c in c.glow(12, 12, 12, 0xFFFFFF, 0.9); c.oval(12, 12, 2.5, 2.5, 0xFFFFFF) }
    static let streak = Sprite(4, 40) { c in
        let g = CGGradient(colorsSpace: sRGB, colors: [rgb(0xFFFFFF, 1), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
        c.addPath(roundRect(0.6, 0, 2.8, 40, 1.4)); c.clip()
        c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: 40), options: [])
    }
    /// A soft flake with a faint blue underside, so it still reads against a white window.
    static let snowDot = Sprite(8, 8) { c in
        c.glow(4, 4, 4, 0xFFFFFF, 0.8)
        c.oval(4, 3.6, 2.7, 2.7, 0x9FBFE8, 0.55)
        c.oval(4, 4.2, 2.5, 2.5, 0xFFFFFF)
    }
    /// Three six-armed snow crystals.
    static let flakes: [Sprite] = (0..<3).map { v in
        Sprite(16, 16) { c in
            c.translateBy(x: 8, y: 8)
            for pass in 0..<2 {
                c.setStrokeColor(pass == 0 ? rgb(0x7FA6DC, 0.6) : rgb(0xFFFFFF))
                c.setLineWidth(pass == 0 ? 2.3 : 1.1); c.setLineCap(.round)
                for i in 0..<6 {
                    c.saveGState(); c.rotate(by: CGFloat(i) * .pi / 3)
                    c.move(to: .zero); c.addLine(to: CGPoint(x: 0, y: 7))
                    let b: CGFloat = v == 2 ? 2.3 : 1.7
                    for y in (v == 0 ? [4.2] : (v == 1 ? [2.6, 4.9] : [5])) as [CGFloat] {
                        c.move(to: CGPoint(x: 0, y: y)); c.addLine(to: CGPoint(x: b, y: y + b * 0.8))
                        c.move(to: CGPoint(x: 0, y: y)); c.addLine(to: CGPoint(x: -b, y: y + b * 0.8))
                    }
                    c.strokePath(); c.restoreGState()
                }
            }
            c.oval(0, 0, 1.3, 1.3, 0xFFFFFF)
        }
    }
    /// Maple, beech and ginkgo leaves, drawn pale with veins and shading so a tint keeps the detail.
    static let leaves: [Sprite] = (0..<3).map { v in
        Sprite(22, 22) { c in
            let p = CGMutablePath()
            switch v {
            case 0:
                for i in 0...90 {
                    let a = CGFloat(i) / 90 * 2 * .pi
                    let r = 4.6 + 5.9 * pow(1 - abs(sin(2.5 * (a - .pi / 2))), 0.6)
                    let q = CGPoint(x: 11 + cos(a) * r, y: 10.5 + sin(a) * r)
                    if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
                }
            case 1:
                p.move(to: CGPoint(x: 11, y: 1.5))
                p.addQuadCurve(to: CGPoint(x: 11, y: 20.5), control: CGPoint(x: 21.5, y: 9))
                p.addQuadCurve(to: CGPoint(x: 11, y: 1.5), control: CGPoint(x: 0.5, y: 9))
            default:
                p.move(to: CGPoint(x: 11, y: 2)); p.addLine(to: CGPoint(x: 2, y: 13))
                p.addQuadCurve(to: CGPoint(x: 11, y: 17), control: CGPoint(x: 4, y: 21.5))
                p.addQuadCurve(to: CGPoint(x: 20, y: 13), control: CGPoint(x: 18, y: 21.5))
            }
            p.closeSubpath()
            c.paint(p, 0xFFFFFF)
            c.saveGState(); c.addPath(p); c.clip()
            let g = CGGradient(colorsSpace: sRGB, colors: [rgb(0x000000, 0), rgb(0x000000, 0.36)] as CFArray, locations: [0.3, 1])!
            c.drawLinearGradient(g, start: CGPoint(x: 4, y: 19), end: CGPoint(x: 19, y: 3), options: [.drawsAfterEndLocation])
            c.setStrokeColor(rgb(0x000000, 0.32)); c.setLineWidth(0.7); c.setLineCap(.round)
            c.move(to: CGPoint(x: 11, y: 2)); c.addLine(to: CGPoint(x: 11, y: v == 2 ? 16 : 19))
            switch v {
            case 0:
                for k in [1, 2, 3, 4] {
                    let a = .pi / 2 + CGFloat(k) * 2 * .pi / 5
                    c.move(to: CGPoint(x: 11, y: 9)); c.addLine(to: CGPoint(x: 11 + cos(a) * 8, y: 10.5 + sin(a) * 8))
                }
            case 1:
                for y in [5.5, 9.5, 13.5] as [CGFloat] {
                    c.move(to: CGPoint(x: 11, y: y)); c.addLine(to: CGPoint(x: 15.5, y: y + 3.4))
                    c.move(to: CGPoint(x: 11, y: y)); c.addLine(to: CGPoint(x: 6.5, y: y + 3.4))
                }
            default:
                for x in [4.5, 7.5, 14.5, 17.5] as [CGFloat] { c.move(to: CGPoint(x: 11, y: 2)); c.addLine(to: CGPoint(x: x, y: 16.5)) }
            }
            c.strokePath()
            c.restoreGState()
            c.setStrokeColor(rgb(0x000000, 0.5)); c.setLineWidth(1.1)
            c.move(to: CGPoint(x: 11, y: 2.4)); c.addLine(to: CGPoint(x: 11, y: 0.4)); c.strokePath()
        }
    }
    static let leaf = leaves[1]
    static let petal = Sprite(12, 10) { c in
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0.6, y: 5))
        p.addCurve(to: CGPoint(x: 11.4, y: 7), control1: CGPoint(x: 2.5, y: 11), control2: CGPoint(x: 9.5, y: 10.5))
        p.addLine(to: CGPoint(x: 9.6, y: 5)); p.addLine(to: CGPoint(x: 11.4, y: 3))
        p.addCurve(to: CGPoint(x: 0.6, y: 5), control1: CGPoint(x: 9.5, y: -0.5), control2: CGPoint(x: 2.5, y: -1))
        c.saveGState(); c.addPath(p); c.clip()
        let g = CGGradient(colorsSpace: sRGB, colors: [rgb(0xFFFFFF), rgb(0xFFD3E2), rgb(0xFF9FC0)] as CFArray, locations: [0, 0.5, 1])!
        c.drawLinearGradient(g, start: CGPoint(x: 0, y: 5), end: CGPoint(x: 12, y: 5), options: [])
        c.setStrokeColor(rgb(0xF27FA8, 0.6)); c.setLineWidth(0.6)
        c.move(to: CGPoint(x: 1.5, y: 5)); c.addLine(to: CGPoint(x: 8.5, y: 5)); c.strokePath()
        c.restoreGState()
    }
    /// A whole cherry blossom, mixed in among the loose petals.
    static let blossom = Sprite(18, 18) { c in
        for i in 0..<5 {
            c.saveGState(); c.translateBy(x: 9, y: 9); c.rotate(by: CGFloat(i) * 2 * .pi / 5)
            c.shaded(ovalPath(0, 4.7, 3.1, 4.1), 0xFFD6E4, 0xFFA4C4)
            c.setStrokeColor(rgb(0xF27FA8, 0.5)); c.setLineWidth(0.5)
            c.move(to: CGPoint(x: 0, y: 2)); c.addLine(to: CGPoint(x: 0, y: 6)); c.strokePath()
            c.restoreGState()
        }
        c.oval(9, 9, 2, 2, 0xFFE08A)
        for i in 0..<5 { let a = CGFloat(i) * 2 * .pi / 5 + 0.6; c.oval(9 + cos(a) * 3, 9 + sin(a) * 3, 0.5, 0.5, 0xE85C8E) }
    }
    /// A raindrop: bright rounded head at the bottom, tail fading upward.
    static let drop = Sprite(4, 28) { c in
        let p = CGMutablePath()
        p.addEllipse(in: CGRect(x: 0.3, y: 0.3, width: 3.4, height: 3.4))
        p.move(to: CGPoint(x: 0.4, y: 2.2)); p.addLine(to: CGPoint(x: 2, y: 28)); p.addLine(to: CGPoint(x: 3.6, y: 2.2)); p.closeSubpath()
        c.addPath(p); c.clip()
        let g = CGGradient(colorsSpace: sRGB, colors: [rgb(0xFFFFFF, 1), rgb(0xFFFFFF, 0.55), rgb(0xFFFFFF, 0)] as CFArray,
                           locations: [0, 0.25, 1])!
        c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: 28), options: [])
    }
    static let ring = Sprite(20, 8) { c in
        c.setStrokeColor(rgb(0xFFFFFF, 0.9)); c.setLineWidth(1)
        c.strokeEllipse(in: CGRect(x: 1, y: 1, width: 18, height: 6))
    }
    /// A four-point sparkle.
    static let twinkle = Sprite(14, 14) { c in
        c.glow(7, 7, 6, 0xFFFFFF, 0.55)
        let p = CGMutablePath()
        for i in 0..<8 {
            let a = CGFloat(i) * .pi / 4, r: CGFloat = i % 2 == 0 ? 6.6 : 1.5
            let q = CGPoint(x: 7 + cos(a) * r, y: 7 + sin(a) * r)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        c.paint(p, 0xFFFFFF)
    }
    /// A shooting star: sparkle head at the bottom, tapering tail.
    static let meteor = Sprite(12, 110) { c in
        c.saveGState()
        let t = CGMutablePath()
        t.move(to: CGPoint(x: 3.4, y: 7)); t.addLine(to: CGPoint(x: 6, y: 110)); t.addLine(to: CGPoint(x: 8.6, y: 7)); t.closeSubpath()
        c.addPath(t); c.clip()
        let g = CGGradient(colorsSpace: sRGB, colors: [rgb(0xFFFFFF, 0.95), rgb(0xCFE2FF, 0.5), rgb(0x9FC4FF, 0)] as CFArray,
                           locations: [0, 0.35, 1])!
        c.drawLinearGradient(g, start: CGPoint(x: 0, y: 7), end: CGPoint(x: 0, y: 110), options: [])
        c.restoreGState()
        c.glow(6, 7, 6, 0xFFFFFF, 0.9)
        let p = CGMutablePath()
        for i in 0..<8 {
            let a = CGFloat(i) * .pi / 4, r: CGFloat = i % 2 == 0 ? 5.8 : 1.6
            let q = CGPoint(x: 6 + cos(a) * r, y: 7 + sin(a) * r)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        c.paint(p, 0xFFFFFF)
    }
    static let firefly = Sprite(24, 24) { c in
        c.glow(12, 12, 12, 0xFFFFFF, 0.8)
        c.glow(12, 12, 6, 0xFFFFFF, 0.9)
        c.oval(12, 12, 2.6, 2.6, 0xFFFFFF)
    }
    static let shadow = Sprite(60, 10) { c in c.oval(30, 5, 28, 4, 0x1B2050, 0.2) }

    // Things the pets hold, wear and ride.
    static let laptop = Sprite(36, 30) { c in
        c.glow(18, 25, 17, 0xBFE8FF, 0.4)
        c.shaded(roundRect(4, 5, 28, 19, 3.5), 0x8FA6EA, 0x6680CC)
        c.paint(heartPath(18, 14.5, 3.6), 0xFFD3E0)
        c.shaded(roundRect(1, 1, 34, 5.5, 2.7), 0x6F86CF, 0x5068B0)
    }
    static let book = Sprite(32, 22) { c in
        c.shaded(roundRect(1, 2, 14.5, 18, 2.5), 0x6FB7E9, 0x4F97CC)
        c.shaded(roundRect(16.5, 2, 14.5, 18, 2.5), 0x6FB7E9, 0x4F97CC)
        c.paint(roundRect(14.6, 1, 2.8, 20, 1.4), 0x3F7FB0)
        c.paint(roundRect(2.5, 19, 27, 2, 1), 0xFFF6E4)
        c.paint(starPath(23.5, 11, 3.6, 1.6), 0xFFD65A)
    }
    static let phones = Sprite(60, 46) { c in
        c.setStrokeColor(rgb(0x4A4763)); c.setLineWidth(3.4); c.setLineCap(.round)
        c.addArc(center: CGPoint(x: 30, y: 16), radius: 24.5, startAngle: 0.2, endAngle: .pi - 0.2, clockwise: false); c.strokePath()
        for x in [1.0, 50.0] as [CGFloat] {
            c.shaded(roundRect(x, 6, 9, 18, 4.5), 0xF4727E, 0xC9475F)
            c.oval(x + 4.5, 15, 2, 4.5, 0xFFFFFF, 0.35)
        }
    }
    static let umbrella = Sprite(56, 58) { c in
        c.setStrokeColor(rgb(0x6B5544)); c.setLineWidth(2); c.setLineCap(.round)
        c.move(to: CGPoint(x: 28, y: 34)); c.addLine(to: CGPoint(x: 28, y: 7))
        c.addArc(center: CGPoint(x: 24.5, y: 7), radius: 3.5, startAngle: 0, endAngle: .pi, clockwise: true); c.strokePath()
        let dome = CGMutablePath()
        dome.move(to: CGPoint(x: 2, y: 32))
        dome.addCurve(to: CGPoint(x: 54, y: 32), control1: CGPoint(x: 4, y: 64), control2: CGPoint(x: 52, y: 64))
        for i in 0..<4 {
            let x = 54 - CGFloat(i + 1) * 13
            dome.addQuadCurve(to: CGPoint(x: x, y: 32), control: CGPoint(x: x + 6.5, y: 38))
        }
        dome.closeSubpath()
        c.shaded(dome, 0xF4727E, 0xC9475F)
        c.saveGState(); c.addPath(dome); c.clip()
        c.oval(28, 44, 7, 22, 0xFFE9A8, 0.9); c.oval(6, 40, 5, 20, 0xFFE9A8, 0.75); c.oval(50, 40, 5, 20, 0xFFE9A8, 0.75)
        c.restoreGState()
        c.oval(28, 57, 1.6, 1.6, 0x6B5544)
    }
    static let rocket = Sprite(30, 62) { c in
        for s in [-1.0, 1.0] as [CGFloat] {
            let f = CGMutablePath()
            f.move(to: CGPoint(x: 15 + s * 7, y: 24)); f.addLine(to: CGPoint(x: 15 + s * 14, y: 6)); f.addLine(to: CGPoint(x: 15 + s * 5, y: 12))
            f.closeSubpath()
            c.paint(f, 0xE8607A)
        }
        c.shaded(gumdrop(15, 9, 20, 52), 0xF6F8FC, 0xC3CCDD)
        c.saveGState(); c.addPath(gumdrop(15, 9, 20, 52)); c.clip()
        c.oval(15, 62, 12, 13, 0xE8607A)
        c.restoreGState()
        c.oval(15, 34, 5.4, 5.4, 0x4A5C92); c.oval(15, 34, 4, 4, 0x9FD4FF); c.oval(13.6, 35.4, 1.2, 1.2, 0xFFFFFF, 0.9)
        c.paint(roundRect(9.5, 5, 11, 5, 2), 0x4A4763)
    }
    static let cloud = Sprite(84, 34) { c in
        for (x, y, r) in [(20, 13, 12), (38, 18, 15), (58, 16, 13), (70, 11, 9), (44, 9, 14)] as [(CGFloat, CGFloat, CGFloat)] {
            c.oval(x, y - 2, r, r * 0.86, 0xC9D8F0)
        }
        for (x, y, r) in [(20, 13, 12), (38, 18, 15), (58, 16, 13), (70, 11, 9), (44, 9, 14)] as [(CGFloat, CGFloat, CGFloat)] {
            c.oval(x, y, r, r * 0.86, 0xFFFFFF)
        }
    }
    static let bubble = Sprite(120, 120) { c in
        c.oval(60, 60, 56, 56, 0xFFFFFF, 0.1)
        c.setStrokeColor(rgb(0xDDF1FF, 0.85)); c.setLineWidth(1.8)
        c.strokeEllipse(in: CGRect(x: 4, y: 4, width: 112, height: 112))
        c.setStrokeColor(rgb(0xFFFFFF, 0.9)); c.setLineWidth(3); c.setLineCap(.round)
        c.addArc(center: CGPoint(x: 60, y: 60), radius: 46, startAngle: 1.9, endAngle: 2.6, clockwise: false); c.strokePath()
    }
    static let wheel = Sprite(16, 16) { c in
        c.oval(8, 8, 7.6, 7.6, 0x3A3550)
        c.oval(8, 8, 3.8, 3.8, 0xE4E8F2)
        c.setStrokeColor(rgb(0x3A3550)); c.setLineWidth(1.2)
        c.move(to: CGPoint(x: 4.4, y: 8)); c.addLine(to: CGPoint(x: 11.6, y: 8))
        c.move(to: CGPoint(x: 8, y: 4.4)); c.addLine(to: CGPoint(x: 8, y: 11.6)); c.strokePath()
    }
    private static var carCache: [UInt32: Sprite] = [:]
    /// An open-top toy car, facing right.
    static func car(_ hex: UInt32) -> Sprite {
        if let s = carCache[hex] { return s }
        let dk = mixHex(hex, 0x000000, 0.22)
        let s = Sprite(90, 34) { c in
            let glass = CGMutablePath()
            glass.move(to: CGPoint(x: 60, y: 25)); glass.addQuadCurve(to: CGPoint(x: 73, y: 25), control: CGPoint(x: 72, y: 37))
            glass.closeSubpath()
            c.paint(glass, 0xCFEFFF, 0.8)
            c.shaded(roundRect(3, 7, 84, 20, 10), hex, dk)
            c.paint(roundRect(18, 16, 44, 3, 1.5), 0xFFFFFF, 0.75)
            c.oval(83, 18, 3.2, 3.2, 0xFFF3B0); c.oval(6.5, 18, 2.4, 2.4, 0xFF6B6B)
            c.paint(roundRect(1, 8, 6, 3.5, 1.7), 0xDDE2EE); c.paint(roundRect(83, 8, 6, 3.5, 1.7), 0xDDE2EE)
        }
        carCache[hex] = s
        return s
    }
    static let wagon = Sprite(78, 30) { c in
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 5, y: 26)); p.addLine(to: CGPoint(x: 73, y: 26)); p.addLine(to: CGPoint(x: 65, y: 5)); p.addLine(to: CGPoint(x: 13, y: 5))
        p.closeSubpath()
        c.shaded(p, 0xD49A5A, 0xA66B32)
        c.saveGState(); c.addPath(p); c.clip()
        c.setStrokeColor(rgb(0x8A5A3C, 0.6)); c.setLineWidth(1)
        for x in stride(from: 16, to: 70, by: 11) { c.move(to: CGPoint(x: CGFloat(x), y: 4)); c.addLine(to: CGPoint(x: CGFloat(x), y: 27)) }
        c.strokePath()
        c.restoreGState()
        c.shaded(roundRect(2, 23.5, 74, 5.5, 2.7), 0x9A6B4F, 0x7E543B)
    }
    static let board = Sprite(74, 10) { c in
        c.shaded(roundRect(2, 3.5, 70, 5, 2.5), 0xF7C948, 0xD9A53C)
        c.paint(roundRect(24, 5, 26, 2, 1), 0xF4727E)
    }
    static let sled = Sprite(84, 22) { c in
        c.setStrokeColor(rgb(0xE8607A)); c.setLineWidth(2.6); c.setLineCap(.round)
        c.move(to: CGPoint(x: 6, y: 3)); c.addLine(to: CGPoint(x: 66, y: 3))
        c.addQuadCurve(to: CGPoint(x: 78, y: 15), control: CGPoint(x: 80, y: 3)); c.strokePath()
        for x in [18.0, 54.0] as [CGFloat] { c.paint(roundRect(x, 3, 3, 9, 1.5), 0xC9475F) }
        c.shaded(roundRect(8, 11, 60, 6, 3), 0xD49A5A, 0xA66B32)
    }
    static let butterfly = Sprite(20, 16) { c in
        for s in [-1.0, 1.0] as [CGFloat] {
            c.shaded(ovalPath(10 + s * 4.6, 10, 4.6, 5.2), 0xFFB7CE, 0xF27FA8)
            c.shaded(ovalPath(10 + s * 3.6, 4.2, 3.4, 3.4), 0x9FD4FF, 0x6FB7E9)
            c.oval(10 + s * 4.8, 10.5, 1.4, 1.6, 0xFFFFFF, 0.8)
        }
        c.paint(roundRect(9.1, 2, 1.8, 12, 0.9), 0x4A4763)
    }
    static let heart = Sprite(14, 14) { c in c.paint(heartPath(7, 7, 5.5), 0xFF7FA0) }
    static let bun = Sprite(72, 90, Draw.bun)
    static let tree = Sprite(80, 112, Draw.tree)
    static let lantern = Sprite(48, 76, Draw.lantern)
    static let gift = Sprite(56, 54, Draw.gift)
    static let zzz = Sprite(10, 10) { c in
        c.setStrokeColor(rgb(0xDCE4FF)); c.setLineWidth(1.7); c.setLineCap(.round); c.setLineJoin(.round)
        c.move(to: CGPoint(x: 2, y: 8)); c.addLine(to: CGPoint(x: 8, y: 8))
        c.addLine(to: CGPoint(x: 2, y: 2)); c.addLine(to: CGPoint(x: 8, y: 2)); c.strokePath()
    }

    private static var petCache: [String: [Sprite]] = [:]
    static let note = Sprite(12, 14) { c in
        c.oval(4, 3.5, 3.2, 2.6, 0xBFE3FF)
        c.paint(roundRect(6, 3, 1.6, 9.5, 0.8), 0xBFE3FF)
        c.paint(roundRect(6, 9.5, 5, 3, 1.5), 0xBFE3FF)
    }
    static let bang = Sprite(8, 16) { c in
        c.paint(roundRect(2.2, 6, 3.6, 9.5, 1.8), 0xFFD65A); c.oval(4, 2.4, 2, 2, 0xFFD65A)
    }
    static let star = Sprite(14, 14) { c in c.paint(starPath(7, 7, 6.5, 3), 0xFFD65A) }

    static let ball = Sprite(18, 18) { c in
        c.shaded(ovalPath(9, 9, 8.5, 8.5), 0xF4727E, 0xD9566A)
        c.saveGState(); c.addPath(ovalPath(9, 9, 8.5, 8.5)); c.clip()
        c.paint(roundRect(-2, 6.5, 22, 5, 0), 0xFFF6EA)
        c.restoreGState()
        c.oval(6, 13, 2, 1.5, 0xFFFFFF, 0.8)
    }
    static let pile = Sprite(44, 20) { c in
        let cols: [UInt32] = [0xE2703A, 0xD9A53C, 0xC9492F, 0xE8B84A, 0xB5651D]
        var r = RNG(s: 7)
        for i in 0..<18 {
            let x = r.r(6, 38), y = r.r(2, 6) + (1 - abs(x - 22) / 18) * 9
            c.saveGState(); c.translateBy(x: x, y: y); c.rotate(by: r.r(-1, 1))
            c.oval(0, 0, 6, 3.4, cols[i % 5])
            c.restoreGState()
        }
    }
    static let snowball = Sprite(52, 52) { c in
        c.shaded(ovalPath(26, 26, 25, 25), 0xFFFFFF, 0xCFDDF2)
        c.setStrokeColor(rgb(0xB9CBE6, 0.7)); c.setLineWidth(1.4); c.setLineCap(.round)
        for (x, y, r, a0) in [(18, 30, 9, 0.4), (32, 18, 7, 3.2), (34, 34, 6, 1.6)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            c.addArc(center: CGPoint(x: x, y: y), radius: r, startAngle: a0, endAngle: a0 + 1.3, clockwise: false)
            c.strokePath()
        }
    }
    static let snowman = Sprite(64, 96, Draw.snowman)
    static let house = Sprite(50, 46) { c in
        c.oval(25, 4, 23, 4, 0x1B2050, 0.16)
        c.shaded(roundRect(7, 3, 36, 26, 4), 0xE9C9A0, 0xCFA878)
        c.paint(roundRect(17, 3, 16, 18, 8), 0x3A2A33)
        let roof = CGMutablePath()
        roof.move(to: CGPoint(x: 2, y: 26)); roof.addLine(to: CGPoint(x: 25, y: 45)); roof.addLine(to: CGPoint(x: 48, y: 26))
        roof.closeSubpath()
        c.shaded(roof, 0xE8607A, 0xC9475F)
        c.paint(roundRect(1, 24, 48, 5, 2.5), 0xF4838F)
        c.oval(25, 33, 3, 3, 0xFFF1DC)
    }
    static let bowl = Sprite(24, 12) { c in
        c.oval(12, 8, 8, 3.5, 0xC98A4B)
        c.shaded(roundRect(2, 1, 20, 8, 3.5), 0x6FB7E9, 0x4F97CC)
        c.paint(roundRect(1, 6.5, 22, 3, 1.5), 0x8CC8F2)
    }
    static let yarn = Sprite(20, 20) { c in
        let ballPath = ovalPath(10, 10, 8.5, 8.5)
        c.shaded(ballPath, 0xF79BB8, 0xE0779A)
        c.saveGState(); c.addPath(ballPath); c.clip()
        c.setStrokeColor(rgb(0xFFD3E0, 0.9)); c.setLineWidth(1.1); c.setLineCap(.round)
        for a0 in [0.3, 1.2, 2.1] as [CGFloat] {
            c.addArc(center: CGPoint(x: 10 + cos(a0) * 5, y: 10 + sin(a0) * 5), radius: 8, startAngle: a0 + 2.2, endAngle: a0 + 4,
                     clockwise: false)
            c.strokePath()
        }
        c.restoreGState()
    }
    static let bone = Sprite(26, 14) { c in
        for (x, y) in [(5, 4.5), (5, 9.5), (21, 4.5), (21, 9.5)] as [(CGFloat, CGFloat)] { c.oval(x, y, 3.6, 3.6, 0xFFF6E4) }
        c.paint(roundRect(5, 4.5, 16, 5, 2), 0xFFF6E4)
        c.paint(roundRect(6, 4.5, 14, 1.6, 0.8), 0xE6D7B8)
    }
    static let cup = Sprite(16, 18) { c in
        c.setStrokeColor(rgb(0xFFFFFF, 0.8)); c.setLineWidth(1); c.setLineCap(.round)
        for x in [5.0, 9.0] as [CGFloat] {
            c.move(to: CGPoint(x: x, y: 12)); c.addQuadCurve(to: CGPoint(x: x, y: 17), control: CGPoint(x: x + 2, y: 14.5))
        }
        c.strokePath()
        c.setStrokeColor(rgb(0xFFF1DC)); c.setLineWidth(1.6)
        c.addArc(center: CGPoint(x: 11.5, y: 6), radius: 2.8, startAngle: -1.3, endAngle: 1.3, clockwise: false); c.strokePath()
        c.shaded(roundRect(2.5, 1, 9.5, 10, 2.5), 0xFFF1DC, 0xE6CDAE)
        c.paint(roundRect(3.5, 8.6, 7.5, 1.6, 0.8), 0x8A5A3C)
    }
    static let balloon = Sprite(26, 46) { c in
        c.setStrokeColor(rgb(0xFFFFFF, 0.8)); c.setLineWidth(0.9)
        c.move(to: CGPoint(x: 13, y: 0)); c.addQuadCurve(to: CGPoint(x: 13, y: 18), control: CGPoint(x: 16, y: 9)); c.strokePath()
        c.paint(gumdrop(13, 15.5, 5, 4), 0xD9566A)
        c.shaded(ovalPath(13, 31, 11.5, 13.5), 0xF4727E, 0xD9566A)
        c.oval(9, 36, 2.6, 4, 0xFFFFFF, 0.5)
    }
    static let puddle = Sprite(70, 12) { c in
        c.oval(35, 6, 34, 5.2, 0x7FB4E8, 0.5)
        c.oval(35, 6.4, 29, 3.8, 0xA9D2F7, 0.55)
        c.oval(24, 7.6, 10, 1.2, 0xFFFFFF, 0.5)
        c.oval(47, 4.6, 6, 0.9, 0xFFFFFF, 0.35)
    }
    static let mound = Sprite(54, 18) { c in
        c.shaded(gumdrop(27, 0, 52, 17), 0xFFFFFF, 0xCFDDF2)
        c.shaded(gumdrop(13, 0, 22, 9), 0xFFFFFF, 0xD6E2F4)
        c.oval(20, 11, 5, 1.6, 0xFFFFFF, 0.9)
    }
    static let petalHeap = Sprite(52, 18) { c in
        let cols: [UInt32] = [0xFFD1E0, 0xFFB7CF, 0xFFFFFF, 0xFFE4EC, 0xF79BB8]
        var r = RNG(s: 11)
        for i in 0..<26 {
            let x = r.r(5, 47), y = r.r(1.5, 5) + (1 - abs(x - 26) / 22) * 9
            c.saveGState(); c.translateBy(x: x, y: y); c.rotate(by: r.r(-1.2, 1.2))
            c.oval(0, 0, 4.6, 2.6, cols[i % 5])
            c.restoreGState()
        }
    }
    static let fallenStar = Sprite(26, 26) { c in
        c.glow(13, 11, 13, 0xFFE9A8, 0.75)
        c.paint(starPath(13, 10, 8, 3.6), 0xFFE27A)
        c.paint(starPath(13, 10, 4.2, 1.9), 0xFFFBE0)
    }
    static let mushroom = Sprite(22, 24) { c in
        c.glow(11, 13, 11, 0x9CFFD0, 0.6)
        c.paint(roundRect(8.6, 0, 4.8, 11, 2), 0xEFFFF4)
        let cap = CGMutablePath()
        cap.move(to: CGPoint(x: 2, y: 10)); cap.addQuadCurve(to: CGPoint(x: 20, y: 10), control: CGPoint(x: 11, y: 27)); cap.closeSubpath()
        c.paint(cap, 0x58D6A6)
        for (x, y, d) in [(7.5, 13.5, 1.5), (12.5, 16.5, 1.8), (15.5, 12.5, 1.2)] as [(CGFloat, CGFloat, CGFloat)] { c.oval(x, y, d, d, 0xEFFFF4) }
    }
    static let plane = Sprite(26, 14) { c in                  // a folded paper dart, nose to the right
        let top = CGMutablePath()
        top.move(to: CGPoint(x: 25, y: 7)); top.addLine(to: CGPoint(x: 1, y: 13)); top.addLine(to: CGPoint(x: 8, y: 6.5)); top.closeSubpath()
        c.paint(top, 0xFFFFFF)
        let under = CGMutablePath()
        under.move(to: CGPoint(x: 25, y: 7)); under.addLine(to: CGPoint(x: 8, y: 6.5)); under.addLine(to: CGPoint(x: 10, y: 1)); under.closeSubpath()
        c.paint(under, 0xC9D6EA)
        let fold = CGMutablePath()
        fold.move(to: CGPoint(x: 25, y: 7)); fold.addLine(to: CGPoint(x: 8, y: 6.5)); fold.addLine(to: CGPoint(x: 3, y: 4)); fold.closeSubpath()
        c.paint(fold, 0xE6EDF8)
    }
    static let castle = Sprite(56, 44) { c in                 // a sandcastle with a little flag
        c.oval(28, 4, 27, 4, 0xE9CF95)
        c.shaded(roundRect(8, 3, 40, 18, 2), 0xF2D79C, 0xD9B56E)
        c.shaded(roundRect(4, 3, 12, 26, 2), 0xF6DDA6, 0xD9B56E)
        c.shaded(roundRect(40, 3, 12, 26, 2), 0xF6DDA6, 0xD9B56E)
        c.shaded(roundRect(21, 14, 14, 20, 2), 0xF6DDA6, 0xD9B56E)
        for x in [4.0, 9.0, 13.0, 40.0, 45.0, 49.0, 21.0, 26.5, 32.0] as [CGFloat] {
            c.paint(roundRect(x, x > 20 && x < 36 ? 33 : 28, 3, 3, 0.6), 0xF6DDA6)
        }
        c.paint(roundRect(24, 3, 8, 9, 4), 0x9A7440)
        c.setStrokeColor(rgb(0x8A6A4F)); c.setLineWidth(1)
        c.move(to: CGPoint(x: 28, y: 35)); c.addLine(to: CGPoint(x: 28, y: 43)); c.strokePath()
        let flag = CGMutablePath()
        flag.move(to: CGPoint(x: 28, y: 43)); flag.addLine(to: CGPoint(x: 36, y: 40.5)); flag.addLine(to: CGPoint(x: 28, y: 38)); flag.closeSubpath()
        c.paint(flag, 0xF4727E)
    }
    static let hole = Sprite(40, 12) { c in c.oval(20, 6, 19, 5.5, 0x6B5544); c.oval(20, 5.2, 16, 4, 0x2A2233) }

    /// Frames for a pet: 0 walk A, 1 walk B, 2 asleep, 3 blink, 4 happy, 5 surprised, 6 sitting, 7 sad,
    /// 8 laughing, 9 crying, 10 heart eyes, 11 dizzy, 12 sitting and happy.
    static func pet(_ kind: String, hat: Int = 0, scarf: Int = 0) -> [Sprite] {
        let key = "\(kind)|\(hat)|\(scarf)"
        if let f = petCache[key] { return f }
        let spec: [(Int, Int)] = [(0, 0), (1, 0), (2, 3), (0, 3), (0, 1), (0, 2), (2, 0), (0, 4),
                                  (0, 5), (0, 6), (0, 7), (0, 8), (2, 1)]
        Draw.shadow = false
        defer { Draw.shadow = true }
        let sc: UInt32? = scarf == 0 ? nil : UInt32(scarf)
        let f = spec.map { sp in Sprite(100, 96) { Draw.pet($0, kind, phase: sp.0, eyes: sp.1, hat: hat, scarf: sc) } }
        petCache[key] = f
        return f
    }

    static func decor(_ kind: String) -> Sprite {
        switch kind {
        case "tree": return tree
        case "lantern": return lantern
        case "gift": return gift
        case "snowman": return snowman
        default: return bun
        }
    }
}
