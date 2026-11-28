import AppKit
import SpriteKit

/// Something the weather leaves along the bottom of the screen: a puddle in rain, a heap of leaves in autumn,
/// a drift of petals under sakura, a snow mound, a fallen star, a glowing mushroom on a firefly night.
final class GroundSpot {
    let node: SKSpriteNode
    let kind: Weather
    var level: CGFloat      // 0 just starting ... 1 full size
    var bounce: CGFloat = 0 // a squash when something lands in it
    init(node: SKSpriteNode, kind: Weather, level: CGFloat) { self.node = node; self.kind = kind; self.level = level }
}

extension WeatherScene {

    /// The strip along the bottom of the screen that snow settles on, leaving out the Dock (which has its own).
    func groundSurface() -> Surface? {
        guard Settings.shared.ground else { return nil }
        var r: [(CGFloat, CGFloat)] = [(0, size.width)]
        if let d = dock { r = [(0, d.minX - 4), (d.maxX + 4, size.width)].filter { $0.1 - $0.0 > 8 } }
        return Surface(id: -3, x0: 0, x1: size.width, y: 0, ranges: r)
    }

    private func spotArt(_ w: Weather) -> (Sprite, CGFloat)? {
        switch w {
        case .snow: return (Art.mound, 54)
        case .rain: return (Art.puddle, 70)
        case .leaves: return (Art.pile, 52)
        case .sakura: return (Art.petalHeap, 52)
        case .starfall: return (Art.fallenStar, 20)
        case .fireflies: return (Art.mushroom, 18)
        case .off: return nil
        }
    }

    /// A place for a new spot: clear of the Dock and of the other spots, and for the first few, where the pets live.
    private func freeSpotX(_ kind: Weather) -> CGFloat? {
        let mine = spots.filter { $0.kind == kind }
        for i in 0..<14 {
            var x = rnd(40, size.width - 40)
            if screenIndex == 0, !onBar, !actors.isEmpty, i < 5, mine.count < 3 {
                let z = petZone(mine.count % 2 == 0 ? 1 : 0)
                x = rnd(z.lowerBound + 10, max(z.lowerBound + 11, z.upperBound - 10))
            }
            if let d = dock, x > d.minX - 36, x < d.maxX + 36 { continue }
            if mine.contains(where: { abs($0.node.position.x - x) < 84 }) { continue }
            if let h = hole, abs(h.position.x - x) < 34 { continue }
            if let hs = house, abs(hs.position.x - x) < 40 { continue }
            return x
        }
        return nil
    }

    func updateGround(_ dt: CGFloat, t: CGFloat) {
        let st = Settings.shared, w = st.weather
        let on = st.ground && w != .off
        groundAge += dt
        spotT -= dt
        if on, spotT <= 0, let (sp, width) = spotArt(w) {
            spotT = groundAge < 4 ? 0.1 : 3
            let want = max(3, Int(size.width / 320))
            if spots.filter({ $0.kind == w }).count < want, let x = freeSpotX(w) {
                let n = SKSpriteNode(texture: sp.tex, size: CGSize(width: width, height: width * sp.size.height / sp.size.width))
                n.anchorPoint = CGPoint(x: 0.5, y: 0)
                n.position = CGPoint(x: x, y: w == .rain ? 0 : -1)
                n.zPosition = 6
                n.alpha = 0
                if w == .starfall || w == .fireflies { n.blendMode = .add }
                addChild(n)
                // On launch they are already partly there; after that each one grows from nothing.
                spots.append(GroundSpot(node: n, kind: w, level: groundAge < 4 ? rnd(0.45, 0.9) : 0.02))
            }
        }
        var i = 0
        while i < spots.count {
            let s = spots[i], n = s.node, x = n.position.x
            var live = on && s.kind == w
            if let d = dock, x > d.minX - 20, x < d.maxX + 20 { live = false }     // the Dock grew over it
            s.level = max(0, min(1, s.level + (live ? 0.02 : -0.06) * dt))
            s.bounce += (0 - s.bounce) * min(1, 5 * dt)
            if s.level <= 0, !live {
                n.removeFromParent()
                spots.remove(at: i)
                continue
            }
            let g = 0.35 + 0.65 * s.level
            n.xScale = g * (1 + s.bounce * 0.25)
            n.yScale = (s.kind == .rain ? 1 : g) * (1 - s.bounce * 0.45)
            var a = min(1, s.level * 2.5)
            switch s.kind {
            case .starfall: a *= 0.55 + 0.45 * abs(sin(t * 1.9 + x))             // twinkling
            case .fireflies: a *= 0.6 + 0.4 * abs(sin(t * 1.1 + x * 0.7))        // a slow glow
            case .rain:
                if w == .rain, s.level > 0.25, Int.random(in: 0..<50) == 0 {      // a drop lands in it
                    make(.ring, x: x + rnd(-0.3, 0.3) * n.size.width * g, y: 2.5)
                }
            default: break
            }
            n.alpha = a
            i += 1
        }
    }

    /// A card in the upper middle of the screen, for things you should not miss. `party` adds confetti.
    func banner(_ title: String, _ sub: String, seconds: Double, party: Bool) {
        childNode(withName: "banner")?.removeFromParent()
        let box = SKNode()
        box.name = "banner"; box.zPosition = 60
        box.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        let t = SKLabelNode(fontNamed: "AvenirNext-Bold")
        t.text = title; t.fontSize = party ? 34 : 24; t.fontColor = .white; t.verticalAlignmentMode = .center
        t.position.y = 13
        let l = SKLabelNode(fontNamed: "AvenirNext-Medium")
        l.text = sub; l.fontSize = 15; l.fontColor = SKColor(white: 1, alpha: 0.85); l.verticalAlignmentMode = .center
        l.position.y = -19
        let w = max(t.frame.width, l.frame.width) + 72
        let bg = SKShapeNode(rect: CGRect(x: -w / 2, y: -46, width: w, height: 94), cornerRadius: 24)
        bg.fillColor = SKColor(cgColor: rgb(party ? 0x2B2550 : 0x20222E, 0.94)) ?? .black
        bg.strokeColor = SKColor(white: 1, alpha: party ? 0.5 : 0.18); bg.lineWidth = party ? 2 : 1
        bg.zPosition = -1
        box.addChild(bg); box.addChild(t); box.addChild(l)
        addChild(box)
        box.setScale(0.6); box.alpha = 0
        var seq: [SKAction] = [.group([.fadeIn(withDuration: 0.25), .scale(to: 1.06, duration: 0.25)]), .scale(to: 1, duration: 0.12)]
        if party {                                                       // a slow pulse so it catches the eye
            seq.append(.repeat(.sequence([.scale(to: 1.05, duration: 0.5), .scale(to: 1, duration: 0.5)]), count: max(1, Int(seconds))))
        } else { seq.append(.wait(forDuration: seconds)) }
        seq += [.fadeOut(withDuration: 0.6), .removeFromParent()]
        box.run(.sequence(seq))
        guard party else { return }
        partyT = CGFloat(seconds)
        let colors: [UInt32] = [0xF4727E, 0xF7C948, 0x4FB7A8, 0x6FB7E9, 0xB58AE0, 0xFFFFFF]
        run(.repeat(.sequence([.run { [weak self] in
            guard let self else { return }
            for _ in 0..<34 {                                            // confetti from the top of the screen
                let p = self.make(.splash, x: rnd(0, self.size.width), y: self.size.height - rnd(20, 120))
                p.node.texture = Art.dot.tex
                p.node.size = CGSize(width: rnd(8, 14), height: rnd(8, 14))
                p.node.color = SKColor(cgColor: rgb(colors.randomElement()!)) ?? .white
                p.node.colorBlendFactor = 1
                p.alpha = 1; p.life = rnd(1.6, 2.6); p.maxLife = p.life
                p.vx = rnd(-90, 90); p.vy = rnd(60, 260)
            }
        }, .wait(forDuration: 0.4)]), count: Int(seconds / 0.4) - 4), withKey: "party")
    }

    func spotNear(_ x: CGFloat, within: CGFloat) -> GroundSpot? {
        spots.filter { $0.level > 0.3 && abs($0.node.position.x - x) < within }
            .min { abs($0.node.position.x - x) < abs($1.node.position.x - x) }
    }

    private func spotBits(_ s: GroundSpot, _ count: Int, up: ClosedRange<CGFloat>) {
        let at = CGPoint(x: s.node.position.x, y: 5)
        switch s.kind {
        case .rain: bits(count, at: at, tex: Art.dot, size: CGSize(width: 3, height: 3), colors: [0xCFE6FF, 0x9CC8F5], up: up)
        case .leaves: bits(count, at: at, tex: Art.leaf, size: CGSize(width: 12, height: 9), colors: [0xE2703A, 0xD9A53C, 0xC9492F, 0xE8B84A], up: up)
        case .sakura: bits(count, at: at, tex: Art.petal, size: CGSize(width: 9, height: 7), colors: [0xFFFFFF, 0xFFD1E0, 0xFFB7CF], up: up)
        case .snow: bits(count, at: at, tex: Art.snowDot, size: CGSize(width: 4.5, height: 4.5), colors: [0xFFFFFF, 0xDDE9FA], up: up)
        case .starfall: bits(count, at: at, tex: Art.twinkle, size: CGSize(width: 8, height: 8), colors: [0xFFFFFF, 0xFFE9A8], up: up)
        case .fireflies: bits(count, at: at, tex: Art.twinkle, size: CGSize(width: 7, height: 7), colors: [0xE8FF8A, 0xBFFFD9], up: up)
        case .off: break
        }
    }

    /// A pet reached a spot: what it does there depends on what the weather left.
    func playSpot(_ a: PetActor) {
        guard let s = spotNear(a.node.position.x, within: 46) else { return }
        let st = Settings.shared, n = a.node, k = scaleOf(a) / 0.7
        let squashSpot: (Double) -> Void = { delay in
            n.run(.sequence([.wait(forDuration: delay), .run { [weak s] in s?.bounce = 1 }]))
        }
        a.dir = s.node.position.x >= n.position.x ? 1 : -1
        switch s.kind {
        case .rain:                                                      // stomp about in the puddle
            n.position.x = s.node.position.x
            face(a, 8, 1.8); hop(a, height: 14, times: 3); a.timer = 2
            for i in 0..<3 {
                n.run(.sequence([.wait(forDuration: 0.36 + Double(i) * 0.36), .run { [weak self, weak s] in
                    guard let self, let s else { return }
                    s.bounce = 1
                    self.spotBits(s, 6, up: 70...190)
                    self.make(.ring, x: s.node.position.x + rnd(-10, 10), y: 2.5)
                }]))
            }
        case .leaves, .sakura:                                           // run up and dive into the heap
            a.state = 4; a.timer = 1.9
            face(a, s.kind == .sakura ? 10 : 4, 1.8)
            hop(a, height: 24)
            n.run(.moveTo(x: s.node.position.x, duration: 0.3))
            squashSpot(0.34)
            n.run(.sequence([.wait(forDuration: 0.34), .run { [weak self, weak s] in
                guard let self, let s else { return }
                self.spotBits(s, 14, up: 150...300)
            }, .wait(forDuration: 0.9), .run { [weak self, weak a] in
                guard let self, let a else { return }
                self.wiggle(a, 0.12, times: 2)                           // shake the bits off
            }]))
        case .snow:                                                      // flop into the mound
            a.state = 4; a.timer = 2.2
            face(a, 8, 2)
            n.run(.moveTo(x: s.node.position.x, duration: 0.25))
            let d = a.dir
            n.run(.sequence([.rotate(toAngle: -1.4 * d, duration: 0.22), .wait(forDuration: 1.1),
                             .rotate(toAngle: 0, duration: 0.16), .run { [weak a] in a?.squash = 0.2 }]), withKey: "wig")
            squashSpot(0.22)
            n.run(.sequence([.wait(forDuration: 0.22), .run { [weak self, weak s] in
                guard let self, let s else { return }
                self.spotBits(s, 12, up: 60...190)
            }]))
        case .starfall:                                                  // sit by the fallen star and make a wish
            a.sit = true; a.timer = 3.4
            face(a, 10, 3)
            n.run(.sequence([.wait(forDuration: 1.4), .run { [weak self, weak s, weak a] in
                guard let self, let s, let a else { return }
                s.bounce = 0.6
                self.spotBits(s, 8, up: 50...170)
                self.emote(Art.star, x: s.node.position.x, y: a.node.position.y + 46 * k)
            }]))
        case .fireflies:                                                 // sniff the glowing mushroom
            a.timer = 2.8
            face(a, 5, 1.2); a.squash = 0.2
            n.run(.sequence([.wait(forDuration: 1.1), .run { [weak self, weak s, weak a] in
                guard let self, let s, let a else { return }
                s.bounce = 0.7
                self.spotBits(s, 6, up: 40...140)
                self.face(a, 4, 1.4)
                let q = self.emote(Art.firefly, x: s.node.position.x, y: a.node.position.y + 30 * k)
                q.node.blendMode = .add
                q.node.color = SKColor(cgColor: rgb(0xE8FF8A)) ?? .yellow
                q.node.colorBlendFactor = 1
                q.vy = 26; q.life = 1.8; q.maxLife = 1.8
            }]))
        case .off: break
        }
        st.cheer(1.5)
    }

    /// A baby reached a spot: a bounce in it, whatever it is.
    func babySpot(_ b: Baby) {
        guard let s = spotNear(b.node.position.x, within: 30) else { return }
        s.bounce = 0.7
        spotBits(s, s.kind == .starfall || s.kind == .fireflies ? 4 : 7, up: 50...150)
        if s.kind == .rain { make(.ring, x: s.node.position.x, y: 2.5) }
        b.face = s.kind == .starfall || s.kind == .sakura ? 10 : 8
        b.faceT = 1.5
        b.hops = s.kind == .starfall || s.kind == .fireflies ? 0 : 2
        if b.lift <= 0 { b.vy = 140; b.lift = 0.01 }
        b.timer = 2
        Settings.shared.cheer(1)
    }
}
