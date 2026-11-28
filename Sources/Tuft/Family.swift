import AppKit
import SpriteKit

/// A baby pet: a small copy of one parent, or a mix of the two. It toddles after its parents, naps when they do,
/// chases the ball and whatever toy you are holding, and likes being petted.
final class Baby {
    let node: SKSpriteNode, shadow: SKSpriteNode
    let frames: [Sprite]
    var state = 0          // 0 awake, 1 toddling, 2 asleep, 3 busy tumbling
    var goal = 0           // 0 nowhere special, 1 a parent, 2 the ball, 3 a sibling, 4 the toy in your hand
    var timer: CGFloat = 1, target: CGFloat = 0, dir: CGFloat = 1, flip: CGFloat = 1, anim: CGFloat = 0
    var squash: CGFloat = 0, face = 0, faceT: CGFloat = 0, hover: CGFloat = 0, cooldown: CGFloat = 0, z: CGFloat = 1
    var lift: CGFloat = 0, vy: CGFloat = 0, hops = 0, grow: CGFloat = 1
    var side = 1, sit = false, fast = false
    var vx: CGFloat = 0    // sideways speed while it is in the air after you let go
    init(node: SKSpriteNode, shadow: SKSpriteNode, frames: [Sprite]) { self.node = node; self.shadow = shadow; self.frames = frames }
}

extension WeatherScene {

    // MARK: Games for two

    /// Moves a node from one point to another along an arc. `wobble` adds a ripple; `nose` keeps a paper plane pointing along its path.
    func toss(from: CGPoint, to: CGPoint, height: CGFloat, _ dur: Double, wobble: CGFloat = 0, nose: Bool = false) -> SKAction {
        .customAction(withDuration: dur) { node, e in
            let u = min(1, e / CGFloat(dur))
            let p = CGPoint(x: from.x + (to.x - from.x) * u,
                            y: from.y + (to.y - from.y) * u + sin(u * .pi) * height + sin(u * 3 * .pi) * wobble)
            if nose {
                let dx = p.x - node.position.x, dy = p.y - node.position.y
                if abs(dx) > 0.05 {
                    node.xScale = dx < 0 ? -abs(node.xScale) : abs(node.xScale)
                    node.zRotation = atan2(dy, abs(dx)) * (dx < 0 ? -1 : 1)
                }
            }
            node.position = p
        }
    }

    /// The two pets play a game together: 0 catch, 1 paper planes, 2 build something, 3 bubbles, 4 a high five.
    func duet(_ a: PetActor, _ b: PetActor, _ pick: Int, zone: ClosedRange<CGFloat>) {
        let st = Settings.shared, k = scaleOf(a) / 0.7
        var pick = pick
        if pick == 2, built != nil { pick = 4 }                          // one thing built at a time
        let bx = b.node.position.x, ax0 = a.node.position.x, gy = b.node.position.y
        let s: CGFloat = ax0 < bx ? -1 : 1                               // which side of b the first pet is on
        let want: CGFloat = [112, 130, 100, 100, 50][min(4, pick)] * k
        var ax = min(zone.upperBound, max(zone.lowerBound, bx + s * want))
        if abs(ax - bx) < 46 * k { ax = ax0 }
        if abs(ax - bx) < want * 0.6 { pick = 4 }                        // no room here: a high five needs none
        a.dir = -s; b.dir = s
        func busy(_ t: CGFloat) { for p in [a, b] { p.state = 4; p.timer = t; p.goal = 0; p.sit = false } }
        let step = SKAction.moveTo(x: ax, duration: 0.45)
        step.timingMode = .easeOut
        a.node.run(step)
        let ha = CGPoint(x: ax - s * 20 * k, y: gy + 34 * k), hb = CGPoint(x: bx + s * 20 * k, y: gy + 34 * k)
        let mid = CGPoint(x: (ax + bx) / 2, y: gy)
        func prop(_ sp: Sprite, _ w: CGFloat) -> SKSpriteNode {
            let n = SKSpriteNode(texture: sp.tex, size: CGSize(width: w, height: w * sp.size.height / sp.size.width))
            n.zPosition = 23.6; n.alpha = 0; n.position = ha
            addChild(n)
            return n
        }
        st.cheer(4)

        switch pick {
        case 0:                                                          // catch: the ball goes back and forth
            busy(6.4)
            let ball = prop(Art.ball, 15 * k)
            ball.run(.repeatForever(.rotate(byAngle: 6, duration: 0.6)))
            var seq: [SKAction] = [.wait(forDuration: 0.5), .fadeIn(withDuration: 0.1)]
            for i in 0..<6 {
                let fromA = i % 2 == 0
                let thrower = fromA ? a : b, catcher = fromA ? b : a
                seq.append(.run { [weak self] in thrower.squash = -0.14; self?.face(thrower, 4, 0.8) })
                seq.append(toss(from: fromA ? ha : hb, to: fromA ? hb : ha, height: rnd(34, 64) * k, 0.62))
                seq.append(.run { [weak self] in catcher.squash = 0.16; self?.face(catcher, i == 5 ? 8 : 4, 0.9) })
                seq.append(.wait(forDuration: 0.18))
            }
            seq.append(.run { [weak self] in
                guard let self else { return }
                self.hop(a, height: 16); self.hop(b, height: 16)
                self.emote(Art.heart, x: mid.x, y: gy + 58 * k)
            })
            seq.append(.group([.fadeOut(withDuration: 0.2), .scale(to: 0.3, duration: 0.2)]))
            seq.append(.removeFromParent())
            ball.run(.sequence(seq))
        case 1:                                                          // paper planes
            busy(6.8)
            let plane = prop(Art.plane, 24 * k)
            var seq: [SKAction] = [.wait(forDuration: 0.5), .fadeIn(withDuration: 0.1)]
            for i in 0..<3 {
                let fromA = i % 2 == 0
                let thrower = fromA ? a : b, catcher = fromA ? b : a
                seq.append(.run { [weak self] in thrower.squash = -0.16; self?.face(thrower, 4, 1) })
                seq.append(toss(from: fromA ? ha : hb, to: fromA ? hb : ha, height: 48 * k, 1.25, wobble: 9 * k, nose: true))
                seq.append(.run { [weak self] in self?.hop(catcher, height: 16); self?.face(catcher, 4, 1) })
                seq.append(.wait(forDuration: 0.35))
            }
            let away = CGPoint(x: ha.x - s * 300 * k, y: gy + 230 * k)   // the last throw sails off
            seq.append(.run { [weak self] in self?.face(a, 5, 1.2); self?.face(b, 5, 1.2) })
            seq.append(.group([toss(from: hb, to: away, height: 30 * k, 1.1, nose: true),
                               .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 0.5)])]))
            seq.append(.run { [weak self] in self?.laugh(b) })
            seq.append(.removeFromParent())
            plane.run(.sequence(seq))
        case 2 where st.weather == .rain:                                // share an umbrella
            busy(5.4)
            a.node.removeAllActions()
            a.node.run(.moveTo(x: bx + s * 40 * k, duration: 0.5))
            setProp(a, "umbrella")
            face(a, 3, 5); face(b, 3, 5)
            for i in 0..<3 {
                a.node.run(.sequence([.wait(forDuration: 1 + Double(i) * 1.2), .run { [weak self] in
                    self?.emote(Art.heart, x: bx + s * 20 * k, y: gy + (62 + CGFloat(i) * 6) * k)
                }]))
            }
            a.node.run(.sequence([.wait(forDuration: 5.2), .run { [weak self] in
                if a.propKind == "umbrella" { self?.setProp(a, "") }
            }]))
        case 2:                                                          // build a snowman, a leaf heap or a sandcastle
            busy(6)
            let sp: Sprite, w: CGFloat, tex: Sprite, colors: [UInt32], word: String
            switch st.weather {
            case .snow: sp = Art.snowman; w = 34 * k; tex = Art.snowDot; colors = [0xFFFFFF, 0xDDE9FA]; word = "our snowman!"
            case .leaves: sp = Art.pile; w = 62 * k; tex = Art.leaf; colors = [0xE2703A, 0xD9A53C, 0xC9492F]; word = "leaf mountain!"
            default: sp = Art.castle; w = 54 * k; tex = Art.dot; colors = [0xF2D79C, 0xD9B56E]; word = "our castle!"
            }
            let n = SKSpriteNode(texture: sp.tex, size: CGSize(width: w, height: w * sp.size.height / sp.size.width))
            n.anchorPoint = CGPoint(x: 0.5, y: 0)
            n.position = CGPoint(x: mid.x, y: gy + 1)
            n.zPosition = 21.6
            n.setScale(0.02)
            addChild(n)
            built = n
            var seq: [SKAction] = [.wait(forDuration: 0.6)]
            for i in 1...3 {
                let grow = SKAction.scale(to: CGFloat(i) / 3, duration: 0.35)
                grow.timingMode = .easeOut
                seq.append(.run { [weak self] in
                    guard let self else { return }
                    let patter = i % 2 == 1 ? a : b
                    self.wiggle(patter, 0.1, times: 2); patter.squash = 0.18
                    self.face(a, 3, 0.8); self.face(b, 3, 0.8)
                    self.bits(7, at: CGPoint(x: mid.x, y: gy + 6), tex: tex, size: CGSize(width: 5, height: 5), colors: colors, up: 60...160)
                })
                seq.append(grow)
                seq.append(.wait(forDuration: 0.8))
            }
            seq.append(.run { [weak self] in
                guard let self else { return }
                self.bits(8, at: CGPoint(x: mid.x, y: gy + n.size.height), tex: Art.twinkle, size: CGSize(width: 8, height: 8),
                          colors: [0xFFFFFF, 0xFFE9A8], up: 40...150)
                self.face(a, 4, 1.6); self.face(b, 4, 1.6)
                self.hop(a, height: 18, times: 2); self.hop(b, height: 18, times: 2)
                self.say(a, word, 1.8)
                Settings.shared.cheer(4)
            })
            seq.append(.wait(forDuration: 24))                           // it stays a while, then sinks away
            seq.append(.group([.scaleY(to: 0.05, duration: 0.5), .fadeOut(withDuration: 0.5)]))
            seq.append(.run { [weak self, weak n] in if self?.built === n { self?.built = nil } })
            seq.append(.removeFromParent())
            n.run(.sequence(seq))
        case 3:                                                          // one blows bubbles, the other pops them
            busy(5.8)
            for i in 0..<4 {
                a.node.run(.sequence([.wait(forDuration: 0.6 + Double(i) * 1.15), .run { [weak self] in
                    guard let self else { return }
                    self.face(a, 5, 0.8); a.squash = -0.1
                    let bub = prop(Art.bubble, 15 * k)
                    bub.setScale(0.3)
                    let end = CGPoint(x: hb.x, y: hb.y + rnd(8, 26) * k)
                    bub.run(.sequence([.group([.fadeIn(withDuration: 0.1), .scale(to: 1, duration: 0.4),
                                               self.toss(from: ha, to: end, height: 22 * k, 0.9, wobble: 5 * k)]),
                                       .run { [weak self] in
                                           guard let self else { return }
                                           self.bits(5, at: end, tex: Art.twinkle, size: CGSize(width: 6, height: 6),
                                                     colors: [0xFFFFFF, 0xBFE3FF], up: 30...110)
                                           self.face(b, i == 3 ? 8 : 4, 0.8)
                                       }, .removeFromParent()]))
                    b.node.run(.sequence([.wait(forDuration: 0.6), .run { [weak self] in self?.hop(b, height: 20) }]))
                }]))
            }
        default:                                                         // run up and high five
            busy(2.4)
            face(a, 4, 2); face(b, 4, 2)
            a.node.run(.sequence([.wait(forDuration: 0.45), .run { [weak self] in
                guard let self else { return }
                self.hop(a, height: 26); self.hop(b, height: 26)
            }, .wait(forDuration: 0.24), .run { [weak self] in
                guard let self else { return }
                let top = CGPoint(x: mid.x, y: gy + 62 * k)
                self.bits(7, at: top, tex: Art.star, size: CGSize(width: 7, height: 7), colors: [0xFFD65A, 0xFFFFFF], up: 40...160)
                self.emote(Art.star, x: top.x, y: top.y)
            }]))
        }
    }

    // MARK: Babies

    var babyScale: CGFloat { petScale * 0.62 }

    private func babyKeyNow() -> String {
        let want = (onBar || actors.isEmpty) ? [] : Settings.shared.babies
        return want.isEmpty ? "" : want.joined(separator: ",") + "|" + spot
    }

    /// Keeps the babies on screen in step with the saved list: none on the menu bar, and none without a parent.
    func syncBabies() {
        let key = babyKeyNow()
        guard key != babyKey else { return }
        babyKey = key
        babies.forEach { $0.node.removeFromParent(); $0.shadow.removeFromParent() }; grabbedBaby = nil
        babies = []
        guard !key.isEmpty else { return }
        let side = actors.first?.side ?? 1, z = petZone(side)
        for (i, e) in Settings.shared.babies.enumerated() {
            addBaby(e, x: z.lowerBound + (z.upperBound - z.lowerBound) * (0.3 + 0.2 * CGFloat(i)), side: side)
        }
    }

    /// `entry` is "kind|scarf colour", where kind may be a mix such as "fox+cat".
    @discardableResult
    func addBaby(_ entry: String, x: CGFloat, side: Int) -> Baby {
        let parts = entry.split(separator: "|").map(String.init)
        let frames = Art.pet(parts.first ?? "fox", hat: 0, scarf: parts.count > 1 ? Int(parts[1]) ?? 0 : 0)
        let n = SKSpriteNode(texture: frames[0].tex, size: frames[0].size)
        n.anchorPoint = CGPoint(x: 0.5, y: 0)
        n.zPosition = 23.4 + CGFloat(babies.count) * 0.04      // in front of the toys, the heaps and the parents
        n.position = CGPoint(x: x, y: groundY(x))
        addChild(n)
        let halo = SKSpriteNode(texture: Art.glow.tex, size: CGSize(width: 104, height: 92))   // a soft light behind it
        halo.position = CGPoint(x: 4, y: 34); halo.zPosition = -0.02; halo.alpha = 0.42
        n.addChild(halo)
        let sh = SKSpriteNode(texture: Art.shadow.tex, size: Art.shadow.size)
        sh.zPosition = 21
        addChild(sh)
        let b = Baby(node: n, shadow: sh, frames: frames)
        b.side = side; b.timer = rnd(0.5, 2); b.dir = Bool.random() ? 1 : -1
        babies.append(b)
        return b
    }

    func clearBabies() {
        Settings.shared.babies = []
        syncBabies()
    }

    /// You set one pet down beside the other. They cuddle; and if babies are on, there is room for one more and the
    /// last one was a while ago, a baby arrives.
    func meet(_ a: PetActor) {
        let st = Settings.shared
        guard st.babiesOn, !onBar, !a.bar, a.perch == 0, let b = actors.first(where: { $0 !== a }), !b.bar, b.perch == 0,
              b.state == 0 || b.state == 2 || b.state == 3 else { return }
        let k = scaleOf(a) / 0.7, ax = a.node.position.x, bx = b.node.position.x, gy = a.node.position.y
        guard abs(ax - bx) < 84 * k, abs(gy - b.node.position.y) < 24 else { return }
        a.dir = bx >= ax ? 1 : -1; b.dir = -a.dir
        let mid = (ax + bx) / 2
        for p in [a, b] {
            p.state = 4; p.timer = 3.6; p.sit = false; p.goal = 0
            face(p, 10, 3.2)
            p.node.run(.sequence([.rotate(toAngle: -0.14 * p.dir, duration: 0.25), .wait(forDuration: 1.2),
                                  .rotate(toAngle: 0, duration: 0.2)]), withKey: "wig")
        }
        for i in 0..<4 {
            a.node.run(.sequence([.wait(forDuration: 0.2 + Double(i) * 0.3), .run { [weak self] in
                self?.emote(Art.heart, x: mid + rnd(-10, 10), y: gy + (52 + CGFloat(i) * 7) * k)
            }]))
        }
        st.cheer(5)
        guard st.babies.count < Settings.babyCap, birthT <= 0 else { return }       // a cuddle and nothing more
        birthT = 45
        // Usually one, sometimes twins, now and then triplets, and never past the cap.
        let litter = min(Settings.babyCap - st.babies.count, [1, 1, 1, 2, 2, 3].randomElement()!)
        let entries: [String] = (0..<litter).map { _ in
            let kind: String
            if a.kind != b.kind, Draw.mixable.contains(a.kind), Draw.mixable.contains(b.kind), Int.random(in: 0..<10) < 7 {
                kind = Bool.random() ? "\(a.kind)+\(b.kind)" : "\(b.kind)+\(a.kind)"
            } else {
                kind = Bool.random() ? a.kind : b.kind
            }
            return "\(kind)|\([0xF4727E, 0x4FB7A8, 0xF7C948, 0xFFA8BE, 0x6FB7E9, 0xB58AE0].randomElement()!)"
        }
        a.node.run(.sequence([.wait(forDuration: 1.8), .run { [weak self] in
            guard let self, !self.onBar else { return }
            for (i, entry) in entries.enumerated() where st.babies.count < Settings.babyCap {
                st.babies.append(entry)
                self.babyKey = self.babyKeyNow()
                let baby = self.addBaby(entry, x: mid + (CGFloat(i) - CGFloat(entries.count - 1) / 2) * 20 * k, side: a.side)
                baby.grow = 0.05; baby.face = 4; baby.faceT = 2.5; baby.hops = 2; baby.vy = 150 + CGFloat(i) * 25; baby.timer = 2.5
            }
            self.bits(10, at: CGPoint(x: mid, y: gy + 14), tex: Art.twinkle, size: CGSize(width: 8, height: 8),
                      colors: [0xFFFFFF, 0xFFE9A8, 0xFFD1F0], up: 60...200)
            self.emote(Art.star, x: mid, y: gy + 44 * k)
            self.face(a, 4, 1.8); self.face(b, 4, 1.8)
            self.hop(a, height: 14); self.hop(b, height: 14)
            if entries.count > 1 { self.say(a, entries.count == 2 ? "twins!" : "triplets!", 1.8) }
            st.cheer(8)
        }]))
    }

    // MARK: Picking a baby up

    func babyAt(_ pt: CGPoint) -> Baby? {
        let k = babyScale / 0.434
        return babies.last { b in
            let p = b.node.position
            return abs(pt.x - p.x) < 15 * k && pt.y > p.y && pt.y < p.y + 36 * k
        }
    }

    func grabBaby(_ b: Baby) {
        grabbedBaby = b
        b.node.removeAllActions()
        b.state = 0; b.goal = 0; b.sit = false; b.fast = false; b.hops = 0; b.lift = 0; b.vy = 0
        b.face = 5; b.faceT = 0.7
    }

    /// Let go: it keeps the pointer's speed, falls, and lands with a giggle.
    func dropBaby(_ b: Baby) {
        guard grabbedBaby === b else { return }
        grabbedBaby = nil
        let n = b.node, x = n.position.x
        n.zRotation = 0
        b.lift = max(0.01, n.position.y - groundY(x))
        b.vy = max(-300, min(600, wind.dy * 0.5)); b.vx = wind.dx * 0.45
        b.state = 0; b.timer = 1.6; b.face = 8; b.faceT = 1.6
        if spot == "sides", sideZones() != nil { b.side = x < size.width / 2 ? 0 : 1 }
        Settings.shared.cheer(2)
    }

    private func jump(_ b: Baby, _ v: CGFloat = 150) { if b.lift <= 0 { b.vy = v; b.lift = 0.01 } }

    func updateBabies(_ dt: CGFloat, t: CGFloat) {
        birthT = max(0, birthT - dt)
        guard !babies.isEmpty else { return }
        let st = Settings.shared, sc = babyScale, k = sc / 0.434
        let resting = evAway || st.focusing
        let ballToy = toys.first { $0.kind == 0 }
        for b in babies {
            let n = b.node
            var x = n.position.x
            let gy0 = groundY(x)
            if grabbedBaby === b {                                       // dangling from the pointer
                if NSEvent.pressedMouseButtons & 1 == 0 { dropBaby(b) } else {
                    b.anim += dt
                    let swing = max(-0.6, min(0.6, -wind.dx / 1000))
                    n.zRotation += (swing - n.zRotation) * min(1, 6 * dt)
                    let len = 48 * sc
                    n.position = CGPoint(x: mouse.x + sin(n.zRotation) * len, y: mouse.y - cos(n.zRotation) * len)
                    if abs(wind.dx) > 80 { b.dir = wind.dx > 0 ? 1 : -1 }
                    n.texture = b.faceT > 0 ? b.frames[5].tex : b.frames[Int(b.anim / 0.1) % 2].tex       // paddling legs
                    b.faceT -= dt
                    n.xScale = sc * b.dir; n.yScale = sc
                    b.shadow.alpha = 0
                    continue
                }
            }
            let zone = petZone(b.side)
            func clamp(_ v: CGFloat) -> CGFloat { min(zone.upperBound, max(zone.lowerBound, v)) }
            b.timer -= dt; b.faceT -= dt; b.cooldown -= dt
            b.squash += (0 - b.squash) * min(1, 7 * dt)
            b.grow += (1 - b.grow) * min(1, 6 * dt)
            b.flip += (b.dir - b.flip) * min(1, 16 * dt)
            if b.lift > 0 || b.vy > 0 {                                  // little hops, and falling after being let go
                b.vy -= 900 * dt
                x = min(size.width - 20, max(20, x + b.vx * dt))
                b.lift = b.lift + b.vy * dt + (gy0 - groundY(x))        // the ground may change under it (the Dock's edge)
                if b.lift <= 0 {
                    b.lift = 0; b.vy = 0; b.vx = 0; b.squash = 0.2
                    if b.hops > 0 { b.hops -= 1; b.vy = 150; b.lift = 0.01 }
                }
            }
            let gy = groundY(x)

            // You: petting, a click nearby, coming back, a toy in your hand.
            let near = abs(mouse.x - x) < 16 * k && mouse.y > gy - 2 && mouse.y < gy + 36 * k
            b.hover = near ? b.hover + dt : 0
            if b.hover > 0.3, b.cooldown <= 0 {
                b.cooldown = 2
                b.face = 10; b.faceT = 1.6
                jump(b, 120)
                emote(Art.heart, x: x, y: gy + 36 * k).node.size = CGSize(width: 10, height: 10)
                st.cheer(4)
                if b.state == 2, !resting { b.state = 0; b.timer = 2; b.sit = false }
            }
            if b.state != 2 {
                if evClick, hypot(mouse.x - x, mouse.y - gy) < 180 {
                    b.face = 5; b.faceT = 0.6; jump(b, 110)
                    b.dir = mouse.x > x ? 1 : -1
                }
                if evCheer { b.face = 4; b.faceT = 1.5; b.hops = 1; jump(b) }
            }
            if evBack, !st.focusing { b.state = 0; b.sit = false; b.timer = 2; b.face = 4; b.faceT = 1.6; b.hops = 2; jump(b) }
            else if resting, b.state == 0 { b.state = 2; b.timer = 9999; b.sit = true }
            else if !resting, b.state == 2, b.timer > 5000 { b.state = 0; b.timer = rnd(0.5, 2); b.sit = false }
            if let h = held, b.state == 0 || (b.state == 1 && b.goal != 4), abs(h.node.position.x - x) < 280 {
                b.state = 1; b.goal = 4; b.sit = false; b.fast = true
            }

            switch b.state {
            case 1:
                if b.goal == 4 {
                    if let h = held { b.target = clamp(h.node.position.x) } else { b.goal = 0; b.target = x }
                }
                if b.goal == 2, let ball = ballToy { b.target = clamp(ball.node.position.x) }
                b.anim += dt
                if abs(b.target - x) > 1 { b.dir = b.target > x ? 1 : -1 }
                x += b.dir * (b.fast ? 64 : 30) * k * dt
                guard abs(b.target - x) < 5 else { break }
                let goal = b.goal
                b.state = 0; b.goal = 0; b.fast = false; b.timer = rnd(1.2, 3)
                switch goal {
                case 1:                                                  // caught up with a parent
                    b.face = 4; b.faceT = 1.2; jump(b, 110)
                    if Int.random(in: 0..<3) == 0 { emote(Art.heart, x: x, y: gy + 34 * k).node.size = CGSize(width: 9, height: 9) }
                case 2:                                                  // give the ball a nudge
                    if let ball = ballToy, ball.carrier == nil, held !== ball, abs(ball.node.position.x - x) < 16 * k {
                        ball.v = CGVector(dx: b.dir * rnd(60, 110), dy: rnd(90, 140))
                        b.face = 4; b.faceT = 1; b.squash = 0.15
                    }
                case 3:                                                  // a nuzzle for a brother or sister
                    b.face = 10; b.faceT = 1.2
                    emote(Art.heart, x: x, y: gy + 34 * k).node.size = CGSize(width: 9, height: 9)
                case 5: babySpot(b)
                case 4:                                                  // jump for the toy
                    b.face = 4; b.faceT = 0.6; jump(b, 170); b.timer = 0.5
                default: break
                }
            case 2:
                b.z -= dt
                if b.z <= 0 { b.z = 1.7; make(.zzz, x: x + b.dir * 8 * k, y: gy + 24 * k).node.size = CGSize(width: 7, height: 7) }
                if b.timer <= 0 { b.state = 0; b.sit = false; b.timer = 1.5; b.squash = -0.15 }
            case 3:
                if b.timer <= 0 { b.state = 0; b.timer = rnd(1, 2.5); n.zRotation = 0 }
            default:
                guard b.timer <= 0, b.lift <= 0 else { break }
                if x < zone.lowerBound - 4 || x > zone.upperBound + 4 {   // home moved: scurry back
                    b.state = 1; b.goal = 0; b.fast = true; b.sit = false
                    b.target = clamp(x) + (x < zone.lowerBound ? 30 : -30)
                    break
                }
                let parents = actors.filter { !$0.bar && $0.perch == 0 && $0.state != 5 && $0.state != 6 && zone.contains($0.node.position.x) }
                let r = Int.random(in: 0..<100)
                if st.busy { b.sit = true; b.timer = rnd(3, 6); break }  // you're typing: sit quietly
                if parents.contains(where: { $0.state == 2 }), r < 60 {  // nap when a parent naps
                    b.state = 2; b.sit = true; b.timer = rnd(6, 12); break
                }
                // Stop beside the toys and heaps, never on top of them, so a baby is not lost among them.
                func clearOf(_ v: CGFloat) -> CGFloat {
                    var v = v
                    let things = [pile, hole, house, bowl].compactMap { $0 } + toys.map { $0.node }
                    for o in things where abs(o.position.x - v) < 24 * k { v = o.position.x + (v >= o.position.x ? 28 : -28) * k }
                    return clamp(v)
                }
                func wander() { b.state = 1; b.goal = 0; b.sit = false; b.target = clearOf(rnd(zone.lowerBound, zone.upperBound)) }
                switch r {
                case 0..<34:
                    if let par = parents.randomElement() {
                        b.state = 1; b.goal = 1; b.sit = false
                        b.target = clearOf(par.node.position.x + (Bool.random() ? -1 : 1) * rnd(22, 42) * k)
                    } else { wander() }
                case 34..<40: wander()
                case 40..<48:                                            // off to a puddle, a heap, a mound...
                    if let s = spots.filter({ $0.kind == st.weather && $0.level > 0.4 && zone.contains($0.node.position.x) }).randomElement() {
                        b.state = 1; b.goal = 5; b.sit = false; b.target = s.node.position.x
                    } else { wander() }
                case 48..<58:
                    b.hops = Int.random(in: 0...2); jump(b); b.face = 4; b.faceT = 1.2; b.timer = 1.8
                case 58..<66:                                            // a tumble
                    if b.dir > 0 ? zone.upperBound - x < 40 * k : x - zone.lowerBound < 40 * k { b.dir = -b.dir }
                    b.state = 3; b.timer = 0.7; b.sit = false; b.face = 4; b.faceT = 1.2
                    n.run(.group([.rotate(byAngle: -2 * .pi * b.dir, duration: 0.5), .moveBy(x: 26 * k * b.dir, y: 0, duration: 0.5)]))
                case 66..<74:
                    b.state = 2; b.sit = true; b.timer = rnd(6, 12)
                case 74..<84:
                    if let ball = ballToy, ball.carrier == nil, zone.contains(ball.node.position.x) {
                        b.state = 1; b.goal = 2; b.sit = false; b.target = ball.node.position.x
                    } else { wander() }
                case 84..<92:
                    if let o = babies.filter({ $0 !== b && $0.state != 1 }).randomElement() {
                        b.state = 1; b.goal = 3; b.sit = false
                        b.target = clamp(o.node.position.x + (x < o.node.position.x ? -16 : 16) * k)
                    } else { wander() }
                default:                                                 // sit down and sing
                    b.sit.toggle(); b.timer = rnd(2, 4); b.squash = 0.12
                    emote(Art.note, x: x + b.dir * 8 * k, y: gy + 30 * k).node.size = CGSize(width: 8, height: 9)
                }
            }

            var f = b.faceT > 0 ? b.face : 0
            if b.sit { f = f == 0 ? 6 : (f == 4 ? 12 : f) }
            n.texture = b.state == 1 ? b.frames[Int(b.anim / 0.14) % 2].tex : (b.state == 2 ? b.frames[2].tex : b.frames[min(f, b.frames.count - 1)].tex)
            if b.state == 1 { n.zRotation = sin(b.anim * 11) * 0.07 } else if b.state != 3 { n.zRotation = 0 }
            let bob: CGFloat = st.music && st.playing && b.state == 0 ? abs(sin(t * 5.97)) * 0.07 : 0
            let breath = sin(t * 2.6 + CGFloat(b.side)) * 0.025
            let fl = abs(b.flip) < 0.14 ? (b.flip < 0 ? -0.14 : 0.14) : b.flip
            let g = sc * b.grow
            n.position = CGPoint(x: x, y: groundY(x) + b.lift)
            n.yScale = g * (1 + breath - b.squash - bob)
            n.xScale = g * fl * (1 + b.squash * 0.6 + bob * 0.5)
            b.shadow.position = CGPoint(x: x, y: groundY(x) + 3.5 * sc)
            b.shadow.setScale(g * max(0.5, 1 - b.lift / 80))
            b.shadow.alpha = max(0, 1 - b.lift / 100)
        }
    }
}
