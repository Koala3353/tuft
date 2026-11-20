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
    func shaded(_ p: CGPath, _ base: UInt32, _ shade: UInt32, dx: CGFloat = -0.09, dy: CGFloat = 0.09) {
        let b = p.boundingBox
        paint(p, shade)
        saveGState()
        addPath(p); clip()
        translateBy(x: b.width * dx, y: b.height * dy)
        paint(p, base)
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
    }

    static func coat(_ kind: String) -> Coat {
        switch kind {
        case "cat": return Coat(body: 0xA4ADC4, shade: 0x848DA8, legs: 0x6F7893, innerEar: 0xFFC9D6, tail: 1,
                                scarf: 0xF4727E, collar: true, whiskers: true)
        case "dog": return Coat(body: 0xEBC48A, shade: 0xD0A468, legs: 0xB88A50, floppy: true, tail: 2,
                                scarf: 0x6FB7E9, collar: true, patch: 0x9A6B4F, tongue: true)
        default: return Coat(body: 0xF39445, shade: 0xDB7430, legs: 0x5A3A2E, earTip: 0x5A3A2E, scarf: 0xF7C948)
        }
    }

    /// Pets face right. Box 100 x 80. phase 0/1 = walk frames, 2 = sitting / eyes closed.
    /// eyes: 0 open, 1 happy, 2 wide (surprised), 3 closed.
    static func eyes(_ c: CGContext, _ xs: [CGFloat], _ y: CGFloat, _ mode: Int, _ r: CGFloat) {
        c.setStrokeColor(rgb(0x3A3550)); c.setLineWidth(1.7); c.setLineCap(.round)
        for x in xs {
            switch mode {
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
                let sg: CGFloat = x < (xs.reduce(0, +) / CGFloat(xs.count)) ? -1 : 1
                c.move(to: CGPoint(x: x + sg * r, y: y + r * 1.5)); c.addLine(to: CGPoint(x: x - sg * r * 0.5, y: y + r * 2.1))
                c.strokePath()
                fallthrough
            default:
                c.oval(x, y, r, r * 1.15, 0x3A3550)
                c.oval(x + r * 0.32, y + r * 0.42, r * 0.4, r * 0.4, 0xFFFFFF)
                c.oval(x - r * 0.35, y - r * 0.4, r * 0.2, r * 0.2, 0xFFFFFF, 0.9)
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
        var k = coat(kind)
        if let sc = scarf { k.scarf = sc }
        let dark: UInt32 = 0x5A3A2E
        let sit = phase == 2
        c.oval(50, 5, 28, 4, 0x1B2050, 0.16)
        // tail
        switch k.tail {
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
        c.restoreGState()
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
                c.paint(gumdrop(0, 0, 13, 17), k.body)
                if let tip = k.earTip {
                    c.saveGState(); c.addPath(gumdrop(0, 0, 13, 17)); c.clip()
                    c.oval(0, 17, 6, 6, tip)
                    c.restoreGState()
                }
                c.paint(gumdrop(0, 0, 6, 9), k.innerEar)
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
        c.restoreGState()
        if k.floppy {
            for sgn in [-1.0, 1.0] as [CGFloat] {
                c.saveGState()
                c.translateBy(x: hx + sgn * 20, y: hy + 3); c.rotate(by: sgn * 0.22)
                c.shaded(ovalPath(0, 0, 6.2, 11.5), 0x9A6B4F, 0x7E543B)
                c.restoreGState()
            }
        }
        Draw.eyes(c, [hx - 9.5, hx + 9.5], hy + 0.5, eyes, 3.7)
        c.oval(hx, hy - 5.5, 2.3, 1.6, dark)
        if eyes == 1 {
            c.paint(roundRect(hx - 2.6, hy - 11.5, 5.2, 4.6, 2.3), 0xE8607A)          // open, happy mouth
        } else if eyes == 2 {
            c.oval(hx, hy - 9.5, 1.5, 1.8, dark)                                       // little "o"
        } else if eyes == 4 {
            c.setStrokeColor(rgb(dark)); c.setLineWidth(1.2); c.setLineCap(.round)     // small frown
            c.addArc(center: CGPoint(x: hx, y: hy - 11.5), radius: 2.2, startAngle: 0.4, endAngle: .pi - 0.4, clockwise: false)
            c.strokePath()
        } else {
            if k.tongue && eyes != 3 { c.paint(roundRect(hx - 1.8, hy - 12, 3.6, 4.6, 1.8), 0xFF8FA3) }
            c.setStrokeColor(rgb(dark)); c.setLineWidth(1.1); c.setLineCap(.round)
            for sgn in [-1.0, 1.0] as [CGFloat] {                                      // tiny "w" smile
                c.addArc(center: CGPoint(x: hx + sgn * 1.7, y: hy - 7.3), radius: 1.7, startAngle: .pi + 0.2,
                         endAngle: 2 * .pi - 0.2, clockwise: false)
                c.strokePath()
            }
        }
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

    /// Egg pet: a speckled egg on two little feet with a sprout on top.
    static func egg(_ c: CGContext, phase: Int, eyes: Int = 0, hat: Int = 0) {
        let sit = phase == 2
        c.oval(50, 5, 20, 4, 0x1B2050, 0.16)
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
        if eyes == 1 { c.paint(roundRect(-2.4, 19, 4.8, 4.4, 2.2), 0xE8607A) } else if eyes == 2 { c.oval(0, 21.5, 1.5, 1.8, 0x3A3550) } else if eyes == 4 {
            c.setStrokeColor(rgb(0x3A3550)); c.setLineWidth(1.3)
            c.addArc(center: CGPoint(x: 0, y: 19.5), radius: 2.2, startAngle: 0.4, endAngle: .pi - 0.4, clockwise: false)
            c.strokePath()
        } else {
            c.setStrokeColor(rgb(0x3A3550)); c.setLineWidth(1.3)
            c.addArc(center: CGPoint(x: 0, y: 23.5), radius: 2.2, startAngle: .pi + 0.4, endAngle: 2 * .pi - 0.4, clockwise: false)
            c.strokePath()
        }
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
    static let leaf = Sprite(16, 10) { c in
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 1, y: 5))
        p.addQuadCurve(to: CGPoint(x: 15, y: 5), control: CGPoint(x: 8, y: 13))
        p.addQuadCurve(to: CGPoint(x: 1, y: 5), control: CGPoint(x: 8, y: -3))
        c.paint(p, 0xFFFFFF)
        c.setStrokeColor(rgb(0x000000, 0.22)); c.setLineWidth(0.7)
        c.move(to: CGPoint(x: 1, y: 5)); c.addLine(to: CGPoint(x: 14, y: 5)); c.strokePath()
    }
    static let petal = Sprite(10, 8) { c in
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0.5, y: 4))
        p.addCurve(to: CGPoint(x: 9.5, y: 5.5), control1: CGPoint(x: 2, y: 9), control2: CGPoint(x: 8, y: 8.5))
        p.addLine(to: CGPoint(x: 8.2, y: 4))
        p.addLine(to: CGPoint(x: 9.5, y: 2.5))
        p.addCurve(to: CGPoint(x: 0.5, y: 4), control1: CGPoint(x: 8, y: -0.5), control2: CGPoint(x: 2, y: -1))
        c.paint(p, 0xFFFFFF)
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
    static let hole = Sprite(40, 12) { c in c.oval(20, 6, 19, 5.5, 0x6B5544); c.oval(20, 5.2, 16, 4, 0x2A2233) }

    /// Frames for a pet: 0 walk A, 1 walk B, 2 asleep, 3 blink, 4 happy, 5 surprised, 6 sitting, 7 sad.
    static func pet(_ kind: String, hat: Int = 0, scarf: Int = 0) -> [Sprite] {
        let key = "\(kind)|\(hat)|\(scarf)"
        if let f = petCache[key] { return f }
        let spec: [(Int, Int)] = [(0, 0), (1, 0), (2, 3), (0, 3), (0, 1), (0, 2), (2, 0), (0, 4)]
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
