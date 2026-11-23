import AppKit
import SpriteKit

/// Everything the pets do beyond walking about: feelings, typing along with you, dancing to music, being picked up,
/// getting from place to place, riding little carts, and playing with the menu bar and the weather.
extension WeatherScene {

    // MARK: Helpers

    /// The middle of a pet's head, in the pet's own coordinates (feet at 0, facing right).
    func headOf(_ a: PetActor) -> CGPoint {
        switch a.kind {
        case "penguin": return CGPoint(x: 0, y: 46)
        case "egg": return CGPoint(x: 0, y: 38)
        case "panda": return CGPoint(x: 0, y: 57)
        default: return CGPoint(x: 20, y: 51)
        }
    }

    /// A point on the pet, in scene coordinates.
    func world(_ a: PetActor, _ local: CGPoint) -> CGPoint {
        CGPoint(x: a.node.position.x + local.x * a.node.xScale, y: a.node.position.y + local.y * a.node.yScale)
    }

    /// Something held in front of the pet: "laptop", "book", "umbrella", or "" for nothing.
    func setProp(_ a: PetActor, _ kind: String) {
        guard a.propKind != kind else { return }
        a.propKind = kind
        a.node.childNode(withName: "prop")?.removeFromParent()
        guard !kind.isEmpty else { return }
        let h = headOf(a)
        let sp: Sprite, pos: CGPoint
        switch kind {
        case "laptop": sp = Art.laptop; pos = CGPoint(x: h.x * 0.8 + 2, y: 15)
        case "book": sp = Art.book; pos = CGPoint(x: h.x * 0.8 + 2, y: 24)
        default: sp = Art.umbrella; pos = CGPoint(x: h.x + 10, y: h.y + 30)
        }
        let c = SKSpriteNode(texture: sp.tex, size: sp.size)
        c.name = "prop"; c.position = pos; c.zPosition = 3
        c.setScale(0.2); c.run(.scale(to: 1, duration: 0.18))
        a.node.addChild(c)
    }

    // MARK: Feelings

    /// A fit of giggles.
    func laugh(_ a: PetActor) {
        guard a.state == 0 || a.state == 3 else { return }
        a.state = 0; a.sit = false
        a.timer = max(a.timer, 1.7)
        face(a, 8, 1.7)
        let up = SKAction.moveBy(x: 0, y: 3.5 * scaleOf(a) / 0.7, duration: 0.07), down = up.reversed()
        a.node.run(.repeat(.sequence([up, down, .run { [weak a] in a?.squash = 0.07 }]), count: 9), withKey: "hop")
        Settings.shared.cheer(3)
        if let o = buddy(a), o.state == 0, o.faceTimer <= 0, Int.random(in: 0..<3) == 0 {     // it's catching
            o.node.run(.sequence([.wait(forDuration: 0.5), .run { [weak self, weak o] in if let o { self?.laugh(o) } }]))
        }
    }

    /// A proper cry, with tears. The other pet comes over.
    func cry(_ a: PetActor) {
        let n = a.node
        a.state = 4; a.timer = 2.8; a.sit = false
        face(a, 9, 2.8)
        wiggle(a, 0.05, times: 9)
        n.run(.repeat(.sequence([.run { [weak self, weak a] in
            guard let self, let a else { return }
            for s in [-1.0, 1.0] as [CGFloat] {
                let h = self.headOf(a), w = self.world(a, CGPoint(x: h.x + s * 15, y: h.y - 8))
                let q = self.make(.splash, x: w.x, y: w.y)
                q.node.size = CGSize(width: 3.5, height: 4.5)
                q.node.color = SKColor(cgColor: rgb(0x8FD0FF)) ?? .cyan
                q.node.colorBlendFactor = 1
                q.alpha = 1; q.life = 0.6; q.maxLife = 0.6
                q.vx = s * rnd(20, 60) * (a.flip < 0 ? -1 : 1); q.vy = rnd(50, 110)
            }
        }, .wait(forDuration: 0.3)]), count: 8))
        if let o = buddy(a), o.state == 0 {
            let k = scaleOf(a) / 0.7, x = n.position.x
            o.state = 1; o.goal = 0; o.sit = false
            o.target = x + (o.node.position.x < x ? -56 : 56) * k
            face(o, 5, 0.6)
        }
    }

    // MARK: Typing along with you

    /// While you type, the first pet opens a tiny laptop and taps along with your keys; the second reads a book.
    func typingStep(_ a: PetActor, _ typing: Bool, _ dt: CGFloat) {
        let n = a.node
        guard typing else {
            if a.propKind == "laptop" || a.propKind == "book" {      // you stopped: pack up and stretch
                setProp(a, "")
                if a.state == 0 { a.squash = -0.14; face(a, 4, 1); n.zRotation = 0 }
            }
            return
        }
        a.sit = true
        let lead = actors.first === a
        setProp(a, lead ? "laptop" : "book")
        if lead {
            if evKey {
                a.tilt = keyStreak % 2 == 0 ? 0.05 : -0.05              // paws go left, right, left
                a.squash = max(a.squash, 0.05)
                if keyStreak % 3 == 0 {                                 // a key pops up off the laptop
                    let w = world(a, CGPoint(x: headOf(a).x * 0.8 + rnd(-10, 12), y: 30))
                    let q = make(.splash, x: w.x, y: w.y)
                    q.node.size = CGSize(width: 3, height: 3)
                    q.node.color = SKColor(cgColor: rgb([0xBFE3FF, 0xFFFFFF, 0xFFD3E0, 0xFFE9A8].randomElement()!)) ?? .white
                    q.node.colorBlendFactor = 1
                    q.alpha = 0.9; q.life = 0.5; q.maxLife = 0.5
                    q.vx = rnd(-24, 24); q.vy = rnd(60, 115)
                }
                if keyStreak % 50 == 0 {                                // a little something for you now and then
                    face(a, 4, 1.4)
                    let w = world(a, CGPoint(x: headOf(a).x, y: headOf(a).y + 26))
                    emote((keyStreak / 50) % 3 == 2 ? Art.star : Art.heart, x: w.x, y: w.y).node.size = CGSize(width: 10, height: 10)
                }
                if keyStreak == 170 { face(a, 5, 0.9); say(a, "so fast!", 1.8) }
            }
        } else {
            a.pageT -= dt
            if a.pageT <= 0 {                                           // turn the page
                a.pageT = rnd(5, 9)
                a.tilt = 0.07; a.squash = max(a.squash, 0.07)
                n.childNode(withName: "prop")?.run(.sequence([.scaleX(to: 0.3, duration: 0.1), .scaleX(to: 1, duration: 0.12)]))
                if Bool.random() { face(a, 4, 1.2) }
            }
        }
        a.tilt *= max(0, 1 - 7 * dt)
        if n.action(forKey: "wig") == nil { n.zRotation += (a.tilt - n.zRotation) * min(1, 18 * dt) }
    }

    // MARK: Music

    /// While another app plays sound the pets wear headphones, nod on the beat and break into dances.
    func grooveStep(_ a: PetActor, _ dt: CGFloat, t: CGFloat, typing: Bool) {
        let st = Settings.shared, n = a.node
        let on = st.music && st.playing && !st.focusing && a.state != 2
        if on != a.grooving {
            a.grooving = on
            n.childNode(withName: "phones")?.removeFromParent()
            if on {
                let c = SKSpriteNode(texture: Art.phones.tex, size: Art.phones.size), h = headOf(a)
                c.name = "phones"; c.position = CGPoint(x: h.x, y: h.y + 6); c.zPosition = 2
                c.setScale(0.2); c.run(.scale(to: 1, duration: 0.2))
                n.addChild(c)
                if a.state == 0 { face(a, 4, 1.5); hop(a, height: 14) }
            } else {
                if a.state == 0 { n.zRotation = 0 }
                if a.state == 0, st.music, !st.playing, !typing { face(a, 7, 1.2) }     // aww, it stopped
            }
        }
        guard on else { return }
        a.noteT -= dt
        if a.noteT <= 0 {
            a.noteT = rnd(1.3, 2.6)
            let h = headOf(a), w = world(a, CGPoint(x: h.x + 22, y: h.y + 22))
            emote(Art.note, x: w.x, y: w.y)
        }
        if a.state == 0, !typing, n.action(forKey: "wig") == nil, n.action(forKey: "hop") == nil {
            n.zRotation = sin(t * 5.97) * 0.07                          // sway on the beat
        }
    }

    /// A dance move; a second pet nearby joins in with the same one.
    func dance(_ a: PetActor) {
        let move = Int.random(in: 0..<5)
        danceMove(a, move)
        if let o = buddy(a), o.state == 0, o.grooving { danceMove(o, move) }
        Settings.shared.cheer(1)
    }

    private func danceMove(_ a: PetActor, _ move: Int) {
        let n = a.node, k = scaleOf(a) / 0.7
        a.sit = false
        face(a, 4, 2.2)
        switch move {
        case 0: a.state = 3; a.timer = 2.2                              // quick feet
        case 1:                                                         // spin
            a.timer = 2
            n.run(.repeat(.sequence([.wait(forDuration: 0.26), .run { [weak a] in a?.dir *= -1 }]), count: 6))
        case 2:                                                         // side to side shuffle
            a.state = 4; a.timer = 1.7
            n.run(.sequence([.moveBy(x: 16 * k, y: 0, duration: 0.4), .moveBy(x: -32 * k, y: 0, duration: 0.8),
                             .moveBy(x: 16 * k, y: 0, duration: 0.4)]))
        case 3: hop(a, height: 20, times: 3); a.timer = 1.7             // bounce
        default: a.timer = 2; wiggle(a, 0.22, times: 5)                 // rock out
        }
    }

    // MARK: Picking a pet up

    func petAt(_ pt: CGPoint) -> PetActor? {
        guard !onBar else { return nil }
        return actors.first { a in
            let k = scaleOf(a) / 0.7, p = a.node.position
            return !a.bar && a.state != 4 && a.state != 7 && a.node.alpha > 0.9
                && abs(pt.x - p.x) < 26 * k && pt.y > p.y + 2 && pt.y < p.y + 64 * k
        }
    }

    /// A plain click picks a pet up only over bare desktop, so clicks meant for a window or the Dock are never
    /// swallowed. Hold Option to pick one up anywhere.
    func canGrab(_ pt: CGPoint) -> Bool {
        if NSEvent.modifierFlags.contains(.option) { return true }
        if spot == "dock" { return false }
        if let d = dock, d.insetBy(dx: -4, dy: -4).contains(pt) { return false }
        return !lastRects.values.contains { $0.contains(pt) }
    }

    func grab(_ a: PetActor) {
        grabbed = a
        a.state = 6; a.heldT = 0; a.shaken = 0; a.goal = 0; a.sit = false; a.perch = 0; a.inHouse = false; a.fast = false
        setProp(a, "")
        a.node.removeAllActions()
        a.node.alpha = 1
        toys.first { $0.carrier === a }?.carrier = nil
        face(a, 5, 0.7)
    }

    func release(_ a: PetActor) {
        grabbed = nil
        guard a.state == 6 else { return }
        if Settings.shared.barVisits, mouse.y > size.height - barH - 12 {      // set down on the menu bar
            a.bar = true; a.state = 0; a.timer = 1.5; a.barT = rnd(20, 45)
            a.node.zRotation = 0
            a.node.position = CGPoint(x: min(size.width - 70, max(70, mouse.x)), y: size.height - barH + 1)
            face(a, 4, 1.4); a.squash = 0.25
            return
        }
        a.state = 5
        a.v = CGVector(dx: wind.dx * 0.55, dy: max(-300, min(760, wind.dy * 0.55)))
        face(a, 5, 0.6)
    }

    /// Dangling from the pointer by the scruff, swinging as you move.
    func heldStep(_ a: PetActor, _ dt: CGFloat, speed: CGFloat) {
        let n = a.node
        if NSEvent.pressedMouseButtons & 1 == 0 { release(a); return }
        a.heldT += dt
        let swing = max(-0.75, min(0.75, -wind.dx / 1000))
        n.zRotation += (swing - n.zRotation) * min(1, 6 * dt)
        let len = 54 * scaleOf(a)
        n.position = CGPoint(x: mouse.x + sin(n.zRotation) * len, y: mouse.y - cos(n.zRotation) * len)
        if speed > 1500 { a.shaken += dt }
        a.anim += dt
        if abs(wind.dx) > 80 { a.dir = wind.dx > 0 ? 1 : -1 }
        let f = a.faceTimer > 0 ? a.faceIdx : (a.shaken > 0.5 ? 11 : (a.heldT > 2.2 ? 8 : Int(a.anim / 0.1) % 2))   // paddling legs
        n.texture = a.frames[f].tex
    }

    /// Thrown or dropped: fall, bounce off the screen edges, and land on a window, the Dock or the ground.
    func fallStep(_ a: PetActor, _ dt: CGFloat) {
        let n = a.node, sc = scaleOf(a)
        var p = n.position
        let prevY = p.y
        a.v.dy -= 1150 * dt
        p.x += a.v.dx * dt; p.y += a.v.dy * dt
        if p.x < 30 { p.x = 30; a.v.dx = abs(a.v.dx) * 0.5 } else if p.x > size.width - 30 { p.x = size.width - 30; a.v.dx = -abs(a.v.dx) * 0.5 }
        let roof = size.height - barH - 70 * sc
        if p.y > roof, a.v.dy > 0 { p.y = roof; a.v.dy = -a.v.dy * 0.3 }
        n.zRotation -= a.v.dx / 240 * dt
        n.texture = a.frames[a.faceTimer > 0 ? a.faceIdx : 5].tex
        var floor = groundY(p.x), onto = 0
        if a.v.dy < 0, Settings.shared.windowVisits {
            for s in surfaces where s.id != -2 && s.covers(p.x) && prevY >= s.y && p.y <= s.y
                && s.y > 120 && s.y < size.height - barH - 70 && s.y > floor {
                floor = s.y; onto = s.id
            }
        }
        guard a.v.dy < 0, p.y <= floor else { n.position = p; return }
        let hard = a.v.dy < -950 || a.shaken > 0.5
        p.y = floor
        n.position = p
        n.zRotation = 0
        a.perch = onto; a.v = .zero; a.state = 0; a.sit = false; a.squash = 0.34
        a.barT = rnd(15, 35)
        if onto == 0, spot == "sides", sideZones() != nil { a.side = p.x < size.width / 2 ? 0 : 1 }
        bits(6, at: CGPoint(x: p.x, y: p.y + 2), tex: Art.dot, size: CGSize(width: 4, height: 4), colors: [0xFFFFFF, 0xDDE6F5], up: 40...130)
        if hard {                                                       // seeing stars
            face(a, 11, 1.9); a.timer = 2.1
            let h = headOf(a)
            for i in 0..<3 {
                let w = world(a, CGPoint(x: h.x + CGFloat(i - 1) * 16, y: h.y + 26))
                emote(Art.star, x: w.x, y: w.y).node.size = CGSize(width: 9, height: 9)
            }
        } else {                                                        // wheee
            face(a, 8, 1.5); a.timer = 1.7
            Settings.shared.cheer(2)
        }
    }

    /// The window it was sitting on moved, closed, or got covered.
    func perchGone(_ a: PetActor) -> Bool {
        guard let s = surfaces.first(where: { $0.id == a.perch }) else { return true }
        let x = a.node.position.x
        return movedIds.contains(a.perch) || !s.ranges.contains { x >= $0.0 - 6 && x <= $0.1 + 6 }
    }

    func drop(_ a: PetActor) {
        a.perch = 0; a.state = 5; a.sit = false; a.goal = 0
        setProp(a, "")
        a.node.removeAllActions(); a.node.alpha = 1
        a.v = CGVector(dx: rnd(-30, 30), dy: 120)
        face(a, 5, 1.2)
    }

    // MARK: Getting from place to place

    /// Carry a pet to `dest` in one of six ways; `set` records where it now lives.
    /// 0 a puff of magic, 1 balloon up or umbrella down, 2 rocket, 3 a flying leap, 4 a cloud, 5 a soap bubble.
    func go(_ a: PetActor, to dest: CGPoint, style: Int, set: @escaping (PetActor) -> Void) {
        let n = a.node, from = n.position, h = headOf(a)
        a.state = 4; a.goal = 0; a.sit = false; a.fast = false; a.inHouse = false
        setProp(a, "")
        n.removeAction(forKey: "hop"); n.removeAction(forKey: "wig")
        n.zRotation = 0
        a.dir = dest.x >= from.x ? 1 : -1
        let up = dest.y > from.y + 40
        func attach(_ sp: Sprite, x: CGFloat, y: CGFloat, z: CGFloat) {
            let c = SKSpriteNode(texture: sp.tex, size: sp.size)
            c.name = "ride"; c.position = CGPoint(x: x, y: y); c.zPosition = z
            c.setScale(0.2); c.run(.scale(to: 1, duration: 0.2))
            n.addChild(c)
        }
        let sparkle: (CGPoint) -> Void = { [weak self] pt in
            self?.bits(8, at: CGPoint(x: pt.x, y: pt.y + 16), tex: Art.twinkle, size: CGSize(width: 9, height: 9),
                       colors: [0xFFFFFF, 0xFFE9A8], up: 60...200)
        }
        let land = SKAction.run { [weak self, weak a] in
            guard let self, let a else { return }
            a.node.children.filter { $0.name == "ride" }.forEach { $0.removeFromParent() }
            a.node.removeAction(forKey: "wig")
            a.node.zRotation = 0; a.node.alpha = 1; a.trail = false
            a.state = 0; a.sit = false; a.timer = 1.5; a.barT = rnd(20, 45)
            self.face(a, 4, 1.4); a.squash = 0.24
        }
        func glide(_ t: Double) -> SKAction {
            let m = SKAction.move(to: dest, duration: t)
            m.timingMode = .easeInEaseOut
            return m
        }
        let sway = SKAction.repeatForever(.sequence([.rotate(toAngle: 0.09, duration: 0.5), .rotate(toAngle: -0.09, duration: 0.5)]))
        switch style {
        case 1:
            set(a); a.timer = 4.2
            face(a, 4, 3.6)
            if up { attach(Art.balloon, x: 0, y: 86, z: -1) } else { attach(Art.umbrella, x: h.x + 10, y: h.y + 30, z: 1) }
            n.run(sway, withKey: "wig")
            n.run(.sequence([glide(3.4), land]))
        case 2:
            set(a); a.timer = 2.6
            face(a, 5, 0.6)
            attach(Art.rocket, x: -24, y: 30, z: -1)
            let blast = SKAction.move(to: dest, duration: 0.95)
            blast.timingMode = .easeIn
            n.run(.sequence([.repeat(.sequence([.rotate(toAngle: 0.06, duration: 0.07), .rotate(toAngle: -0.06, duration: 0.07)]), count: 4),
                             .rotate(toAngle: 0, duration: 0.04),
                             .run { [weak self, weak a] in if let a { self?.face(a, 8, 1.2); a.trail = true } },
                             blast, .run { sparkle(dest) }, land]))
        case 3:
            set(a); a.timer = 1.6
            a.squash = 0.3
            face(a, 4, 1.4)
            let room = size.height - max(from.y, dest.y) - 90 * scaleOf(a)
            let height = max(0, min(room, abs(dest.y - from.y) * 0.2 + 80)), dir = a.dir, dur = 0.95
            let arc = SKAction.customAction(withDuration: dur) { node, el in
                let u = el / CGFloat(dur)
                node.position = CGPoint(x: from.x + (dest.x - from.x) * u,
                                        y: from.y + (dest.y - from.y) * u + height * 4 * u * (1 - u))
                node.zRotation = -2 * .pi * u * dir
            }
            n.run(.sequence([.wait(forDuration: 0.18), arc, land]))
        case 4:
            set(a); a.timer = 3.6
            a.sit = true
            face(a, 4, 3.2)
            attach(Art.cloud, x: 0, y: 4, z: 1)
            n.run(.sequence([glide(3), .run { sparkle(dest) }, land]))
        case 5:
            set(a); a.timer = 3.8
            face(a, 5, 1)
            attach(Art.bubble, x: h.x * 0.5, y: 46, z: 2)
            n.run(sway, withKey: "wig")
            n.run(.sequence([glide(3.2), .run { [weak self] in
                self?.bits(9, at: CGPoint(x: dest.x, y: dest.y + 24), tex: Art.dot, size: CGSize(width: 4, height: 4),
                           colors: [0xDDF1FF, 0xFFFFFF], up: 40...170)
            }, land]))
        default:
            a.timer = 1.6
            face(a, 5, 0.4)
            sparkle(from)
            n.run(.sequence([.fadeOut(withDuration: 0.2), .wait(forDuration: 0.5),
                             .run { [weak a] in
                                 guard let a else { return }
                                 set(a)
                                 a.barMix = a.bar ? 1 : 0
                                 a.node.position = dest
                                 sparkle(dest)
                             },
                             .fadeIn(withDuration: 0.2), land]))
        }
    }

    /// Up to the menu bar, or back down from it.
    func travel(_ a: PetActor, toBar: Bool) {
        let z = toBar ? barZone() : petZone(a.side)
        let x = toBar ? min(z.upperBound, max(z.lowerBound, a.node.position.x + rnd(-260, 260))) : rnd(z.lowerBound, z.upperBound)
        go(a, to: CGPoint(x: x, y: toBar ? size.height - barH + 1 : groundY(x)), style: Int.random(in: 0...5)) {
            $0.bar = toBar; $0.perch = 0
        }
    }

    /// Back to its own patch of ground from the menu bar or a window.
    func goHome(_ a: PetActor) {
        guard !onBar else { return }
        let z = petZone(a.side), x = rnd(z.lowerBound, z.upperBound)
        go(a, to: CGPoint(x: x, y: groundY(x)), style: Int.random(in: 0...5)) { $0.bar = false; $0.perch = 0 }
    }

    /// Over to the other side of the Dock: fly across, or simply stroll over the top of the Dock.
    func cross(_ a: PetActor) {
        guard spot == "sides", sideZones() != nil, !a.bar, a.perch == 0 else { return }
        let other = 1 - a.side, z = petZone(other), x = rnd(z.lowerBound + 20, z.upperBound - 20)
        if Int.random(in: 0..<4) == 0 {
            a.side = other
            a.state = 1; a.goal = 0; a.sit = false; a.target = x
            face(a, 4, 1.2)
        } else {
            go(a, to: CGPoint(x: x, y: groundY(x)), style: [0, 2, 3, 3, 4, 5].randomElement()!) { $0.side = other }
        }
    }

    /// A clear stretch along the top edge of some window, for sitting on.
    private func perchSpot() -> (Int, CGPoint)? {
        var out: [(Int, CGPoint)] = []
        for s in surfaces where s.id != -2 && s.y > 150 && s.y < size.height - barH - 90 {
            for r in s.ranges where r.1 - r.0 > 180 { out.append((s.id, CGPoint(x: rnd(r.0 + 50, r.1 - 50), y: s.y - 2))) }
        }
        return out.randomElement()
    }

    /// Go and spend a while somewhere else: the menu bar, the top of a window, or the far side of the Dock.
    func roam(_ a: PetActor) -> Bool {
        let st = Settings.shared
        guard !st.busy, !st.focusing else { return false }
        var opts: [Int] = []
        if st.barVisits { opts += [0, 0] }
        let seat = st.windowVisits ? perchSpot() : nil
        if seat != nil { opts += [1, 1] }
        if spot == "sides", sideZones() != nil, actors.count == 1 { opts.append(2) }
        switch opts.randomElement() {
        case 0: travel(a, toBar: true)
        case 1:
            guard let (id, pt) = seat else { return false }
            go(a, to: pt, style: [1, 2, 3, 4, 5].randomElement()!) { $0.perch = id; $0.bar = false }
        case 2: cross(a)
        default: return false
        }
        return true
    }

    // MARK: Little carts on the menu bar

    func startRide(_ a: PetActor, zone: ClosedRange<CGFloat>) {
        let n = a.node, p = n.position
        let kind = (Settings.shared.weather == .snow ? [0, 1, 2, 3, 3] : [0, 1, 2]).randomElement()!
        let ride = SKNode()
        ride.name = "ride"; ride.zPosition = 1
        func part(_ sp: Sprite, _ x: CGFloat, _ y: CGFloat, scale: CGFloat = 1, wheel: Bool = false) {
            let c = SKSpriteNode(texture: sp.tex, size: sp.size)
            c.position = CGPoint(x: x, y: y); c.setScale(scale)
            c.zPosition = wheel ? 0.2 : 0.1
            if wheel { c.name = "wheel" }
            ride.addChild(c)
        }
        switch kind {
        case 0:
            part(Art.car([0xF4727E, 0x4FB7A8, 0xF7C948, 0x6FB7E9, 0xB58AE0].randomElement()!), 0, 15)
            part(Art.wheel, -25, 7, wheel: true); part(Art.wheel, 25, 7, wheel: true)
        case 1:
            part(Art.wagon, 0, 16)
            part(Art.wheel, -20, 6, scale: 0.85, wheel: true); part(Art.wheel, 20, 6, scale: 0.85, wheel: true)
        case 2:
            part(Art.board, 0, 4)
            part(Art.wheel, -24, 1, scale: 0.42, wheel: true); part(Art.wheel, 24, 1, scale: 0.42, wheel: true)
        default: part(Art.sled, 0, 7)
        }
        ride.setScale(0.2); ride.run(.scale(to: 1, duration: 0.2))
        n.addChild(ride)
        bits(6, at: CGPoint(x: p.x, y: p.y + 6), tex: Art.twinkle, size: CGSize(width: 7, height: 7), colors: [0xFFFFFF, 0xFFE9A8], up: 30...110)
        a.state = 7; a.goal = 0; a.sit = kind < 2; a.rideV = 0; a.timer = 40; a.pageT = 0
        a.target = p.x - zone.lowerBound > zone.upperBound - p.x ? zone.lowerBound + rnd(0, 160) : zone.upperBound - rnd(0, 160)
        n.zRotation = 0
        face(a, 4, 3)
        if Int.random(in: 0..<3) == 0 { say(a, ["beep beep!", "vroom!", "wheee!"].randomElement()!, 1.6) }
        if let o = buddy(a), o.state == 0 {                              // the other one runs after it
            o.state = 1; o.goal = 0; o.sit = false; o.fast = true
            o.target = min(zone.upperBound, max(zone.lowerBound, a.target + (a.target > p.x ? -40 : 40)))
            face(o, 5, 0.6)
        }
    }

    func rideStep(_ a: PetActor, _ dt: CGFloat) {
        let n = a.node, sc = scaleOf(a)
        var p = n.position
        let d = a.target - p.x
        a.dir = d >= 0 ? 1 : -1
        let want = min(250 * sc + 60, abs(d) * 2.2 + 14)
        a.rideV += (want - a.rideV) * min(1, 3 * dt)
        p.x += a.dir * a.rideV * dt
        p.y += (groundFor(a, p.x) - p.y) * min(1, 12 * dt)
        n.position = p
        n.zRotation = 0
        n.texture = frame(a, a.faceTimer > 0 ? a.faceIdx : 0)
        if let ride = n.childNode(withName: "ride") {
            for w in ride.children where w.name == "wheel" { w.zRotation -= a.rideV * dt / max(1.5, 7.6 * w.xScale * sc) }
        }
        a.pageT -= dt
        if a.pageT <= 0, a.rideV > 40 {                                  // a puff of dust behind
            a.pageT = 0.11
            let q = make(.heart, x: p.x - a.dir * 30 * sc, y: p.y + 5 * sc)
            q.node.texture = Art.dot.tex
            q.node.size = CGSize(width: 5, height: 5)
            q.vx = -a.dir * 26; q.vy = 9; q.life = 0.45; q.maxLife = 0.45
        }
        if abs(d) < 6 || a.timer <= 0 || !(a.bar || onBar) {             // there: hop out
            n.children.filter { $0.name == "ride" }.forEach { $0.removeFromParent() }
            bits(6, at: CGPoint(x: p.x, y: p.y + 6), tex: Art.twinkle, size: CGSize(width: 7, height: 7),
                 colors: [0xFFFFFF, 0xFFE9A8], up: 30...110)
            a.state = 0; a.sit = false; a.timer = 1.6; a.squash = 0.22
            face(a, 4, 1.4)
            Settings.shared.cheer(2)
        }
    }

    // MARK: Playing on the menu bar

    /// Up on the bar: stroll, sprint, ride a cart, go and play with one of the items up there, leapfrog, or peek over the edge.
    func barPlay(_ a: PetActor, _ r: Int, zone: ClosedRange<CGFloat>) -> Bool {
        let n = a.node, p = n.position, k = scaleOf(a) / 0.7
        let items = barItems.filter { $0.midX > zone.lowerBound && $0.midX < zone.upperBound && abs($0.midX - p.x) < 800 }
        let r = r < 10 && !items.isEmpty ? 45 : r                        // more of the time, go and play with an item
        switch r {
        case 0..<16:
            a.state = 1; a.sit = false; a.target = rnd(zone.lowerBound, zone.upperBound)
        case 16..<24:                                                    // sprint to the far end and skid to a stop
            a.state = 1; a.sit = false; a.fast = true
            a.target = p.x - zone.lowerBound > zone.upperBound - p.x ? zone.lowerBound + rnd(0, 120) : zone.upperBound - rnd(0, 120)
            face(a, 4, 2)
        case 24..<40: startRide(a, zone: zone)
        case 40..<64 where !items.isEmpty:                               // off to one of the menu bar items
            let it = items.randomElement()!
            a.item = it; a.act = Int.random(in: 0..<7)
            a.state = 1; a.goal = 11; a.sit = false; a.fast = a.act == 2
            a.target = p.x < it.midX ? it.minX - 3 : it.maxX + 3
        case 64..<70:
            guard let o = buddy(a), o.state == 0, abs(o.node.position.x - p.x) < 260 else { return false }
            let dx = o.node.position.x - p.x                             // leapfrog, kept low: there is no headroom up here
            a.state = 4; a.timer = 0.8
            a.dir = dx > 0 ? 1 : -1
            face(a, 4, 1); face(o, 5, 0.6); o.squash = 0.3
            let up = SKAction.moveBy(x: dx, y: 9 * k, duration: 0.3), down = SKAction.moveBy(x: dx, y: -9 * k, duration: 0.3)
            up.timingMode = .easeOut; down.timingMode = .easeIn
            n.run(.sequence([up, down]))
        case 70..<76:                                                    // lean over the edge for a look below
            a.state = 4; a.timer = 2
            face(a, 5, 1.8)
            n.run(.sequence([.rotate(toAngle: -0.5 * a.dir, duration: 0.25), .wait(forDuration: 1.3),
                             .rotate(toAngle: 0, duration: 0.2)]), withKey: "wig")
        default: return false
        }
        return true
    }

    /// The pet reached the menu bar item it was heading for.
    func itemAct(_ a: PetActor) {
        let it = a.item, n = a.node, p = n.position, k = scaleOf(a) / 0.7
        let toward: CGFloat = it.midX > p.x ? 1 : -1
        a.dir = toward
        let isClock = it.maxX >= (barItems.map { $0.maxX }.max() ?? 0) - 1
        switch isClock && a.act < 3 ? 9 : a.act {
        case 0:                                                          // hide behind it, pop out the other side
            a.state = 4; a.timer = 2.5
            face(a, 5, 0.4)
            let out = toward > 0 ? it.maxX + 5 : it.minX - 5
            n.run(.sequence([.group([.moveTo(x: it.midX, duration: 0.25), .fadeOut(withDuration: 0.25)]),
                             .wait(forDuration: 0.9),
                             .run { [weak a] in a?.node.position.x = out; a?.dir = -toward },
                             .fadeIn(withDuration: 0.15),
                             .run { [weak self, weak a] in if let a { a.state = 0; a.timer = 1.6; self?.laugh(a) } }]))
        case 1:                                                          // hang underneath it like a bat
            a.state = 4; a.timer = 3.6
            face(a, 8, 3.2)
            let swing = SKAction.sequence([.rotate(toAngle: .pi + 0.3, duration: 0.4), .rotate(toAngle: .pi - 0.3, duration: 0.4)])
            n.run(.sequence([.moveTo(x: it.midX, duration: 0.2), .rotate(toAngle: .pi, duration: 0.25), .repeat(swing, count: 3),
                             .rotate(toAngle: 0, duration: 0.25), .run { [weak a] in a?.squash = 0.2 }]), withKey: "wig")
        case 2:                                                          // ran straight into it
            a.state = 4; a.timer = 2.3; a.squash = 0.32
            face(a, 11, 1.9)
            n.run(.moveBy(x: -toward * 9 * k, y: 0, duration: 0.15))
            for i in 0..<3 {
                emote(Art.star, x: p.x + CGFloat(i - 1) * 9 * k, y: p.y - 6 - CGFloat(i % 2) * 5).node.size = CGSize(width: 8, height: 8)
            }
            if let o = buddy(a), o.state == 0 { laugh(o) }
        case 3:                                                          // give it a polish
            a.state = 4; a.timer = 2.2
            face(a, 4, 2.2); wiggle(a, 0.1, times: 7)
            n.run(.repeat(.sequence([.run { [weak self] in
                let sp = self?.make(.spark, x: it.midX + rnd(-it.width / 2, it.width / 2), y: p.y + rnd(6, max(8, it.height - 6)))
                sp?.vy = 10; sp?.life = 0.5; sp?.maxLife = 0.5
            }, .wait(forDuration: 0.3)]), count: 6))
        case 4:                                                          // lean on it for a nap
            a.state = 2; a.sit = true; a.timer = rnd(6, 10); a.z = 0.4
            n.zRotation = -toward * 0.16
        case 5:                                                          // bounce on it like a trampoline
            a.state = 4; a.timer = 2.6
            face(a, 4, 2.4)
            let up = SKAction.moveBy(x: 0, y: 11 * k, duration: 0.19), down = SKAction.moveBy(x: 0, y: -11 * k, duration: 0.19)
            up.timingMode = .easeOut; down.timingMode = .easeIn
            let land = SKAction.run { [weak self, weak a] in
                guard let self, let a else { return }
                a.squash = 0.3
                self.bits(3, at: CGPoint(x: it.midX, y: p.y + 4), tex: Art.twinkle, size: CGSize(width: 6, height: 6),
                          colors: [0xFFFFFF, 0xFFE9A8], up: 20...70)
            }
            n.run(.sequence([.moveTo(x: it.midX, duration: 0.2), .repeat(.sequence([up, down, land]), count: 5)]), withKey: "wig")
        case 6:                                                          // leapfrog clean over it
            a.state = 4; a.timer = 1.7
            face(a, 5, 0.5)
            let out = toward > 0 ? it.maxX + 6 : it.minX - 6
            let up = SKAction.moveBy(x: 0, y: 13 * k, duration: 0.24), down = SKAction.moveBy(x: 0, y: -13 * k, duration: 0.24)
            up.timingMode = .easeOut; down.timingMode = .easeIn
            n.run(.sequence([.group([.moveTo(x: out, duration: 0.48), .sequence([up, down])]),
                             .run { [weak self, weak a] in if let a { a.squash = 0.28; self?.face(a, 4, 1.2) } }]), withKey: "wig")
        default:                                                         // check the clock
            let h = Calendar.current.component(.hour, from: Date())
            let line = h < 5 ? "so late… sleep soon?" : h < 9 ? "good morning!" : h < 12 ? "morning's flying by" :
                       h < 14 ? "lunch time?" : h < 18 ? "afternoon already" : h < 22 ? "nice evening" : "getting late"
            face(a, 5, 1.2); a.timer = 2.8
            say(a, line, 2.4)
        }
    }

    /// For recording and checking: make the pets do one named thing in the demo window.
    func demoAct(_ name: String) {
        let st = Settings.shared
        for a in actors {
            let zone = zoneFor(a)
            switch name {
            case "laugh": laugh(a)
            case "cry": cry(a)
            case "love": face(a, 10, 6); a.timer = 6
            case "dizzy": face(a, 11, 6); a.timer = 6
            case "music": st.playing = true
            case "type": st.busy = true; fakeKeys = true
            case "bar": travel(a, toBar: true)
            case "ride":                                                 // one drives, the other runs after it
                a.bar = true; a.barMix = 1
                a.node.position = CGPoint(x: size.width - 300 - CGFloat(a.slot) * 70, y: size.height - barH + 1)
                if a.slot == 0 { startRide(a, zone: barZone()) }
            case "item":                                                 // each goes to an item of its own
                a.bar = true; a.barMix = 1
                a.node.position = CGPoint(x: size.width - 320 - CGFloat(a.slot) * 90, y: size.height - barH + 1)
                a.item = barItems[a.slot == 0 ? 4 : 1]; a.act = a.slot == 0 ? 5 : 6; a.state = 1; a.goal = 11; a.target = a.item.minX - 3
            case "perch": _ = roam(a)
            case "rocket", "leap", "cloud", "bubble", "umbrella":
                let style = ["rocket": 2, "leap": 3, "cloud": 4, "bubble": 5, "umbrella": 1][name]!
                if name == "umbrella" { a.node.position.y = 420 }
                let x = rnd(zone.lowerBound, zone.upperBound)
                go(a, to: CGPoint(x: name == "umbrella" ? x : a.node.position.x + 120, y: name == "umbrella" ? groundY(x) : size.height - barH + 1),
                   style: style) { $0.bar = name != "umbrella" }
            case "fall": a.node.position.y = 500; a.state = 5; a.v = CGVector(dx: 60, dy: 0)
            case "butterfly": startCritter(zone: zone, ground: groundFor(a, a.node.position.x))
            case "weather": weatherPlay(a)
            default: if let n = Int(name) { a.timer = 2.4; soloExtra(a, n, zone: zone) }
            }
        }
    }

    // MARK: A butterfly to chase

    func startCritter(zone: ClosedRange<CGFloat>, ground: CGFloat) {
        guard critter == nil else { return }
        let c = SKSpriteNode(texture: Art.butterfly.tex, size: Art.butterfly.size)
        critterDir = Bool.random() ? 1 : -1
        critterY = ground + 44
        c.position = CGPoint(x: critterDir > 0 ? zone.lowerBound - 30 : zone.upperBound + 30, y: critterY)
        c.zPosition = 24
        c.userData = NSMutableDictionary(dictionary: ["end": Double(critterDir > 0 ? zone.upperBound + 40 : zone.lowerBound - 40)])
        c.run(.repeatForever(.sequence([.scaleX(to: 0.25, duration: 0.09), .scaleX(to: 1, duration: 0.09)])))
        addChild(c)
        critter = c
        for a in actors where a.state == 0 && !a.bar && a.perch == 0 && zone.contains(a.node.position.x) {
            a.state = 1; a.goal = 10; a.sit = false
            face(a, 5, 0.5)
        }
    }

    func updateCritter(_ dt: CGFloat, t: CGFloat) {
        guard let c = critter else { return }
        c.position.x += critterDir * 58 * dt
        c.position.y = critterY + sin(t * 3.1) * 16 + sin(t * 7.3) * 4
        let end = CGFloat(c.userData?["end"] as? Double ?? 0)
        if (critterDir > 0 && c.position.x > end) || (critterDir < 0 && c.position.x < end) {
            c.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
            critter = nil
        }
    }

    // MARK: More things to do alone

    func soloExtra(_ a: PetActor, _ pick: Int, zone: ClosedRange<CGFloat>) {
        let n = a.node, p = n.position, k = scaleOf(a) / 0.7, h = headOf(a)
        switch pick {
        case 12:                                                         // a big yawn
            face(a, 3, 1.7); a.squash = -0.17
            let w = world(a, CGPoint(x: h.x + 16, y: h.y + 14))
            make(.zzz, x: w.x, y: w.y)
        case 13: laugh(a)
        case 14:                                                         // blow a bubble and watch it go
            face(a, 5, 2)
            let w = world(a, CGPoint(x: h.x + 26, y: h.y - 8))
            let b = emote(Art.bubble, x: w.x, y: w.y)
            b.node.size = CGSize(width: 16, height: 16)
            b.node.setScale(0.25); b.node.run(.scale(to: 1.2, duration: 1.1))
            b.vx = a.dir * 12; b.vy = 20; b.life = 2.4; b.maxLife = 2.4
        case 15:                                                         // a butterfly drifts through
            let w = Settings.shared.weather
            if w != .rain, w != .snow, !a.bar, a.perch == 0 { startCritter(zone: zone, ground: groundFor(a, p.x)) } else { hop(a); face(a, 4, 0.9) }
        case 16:                                                         // a few squats, then phew
            a.state = 4; a.timer = 3
            face(a, 3, 2.4)
            n.run(.sequence([.repeat(.sequence([.run { [weak a] in a?.squash = 0.24 }, .wait(forDuration: 0.3),
                                                .run { [weak a] in a?.squash = -0.1 }, .wait(forDuration: 0.3)]), count: 4),
                             .run { [weak self, weak a] in
                                 guard let self, let a else { return }
                                 self.face(a, 4, 1)
                                 self.say(a, "phew!", 1.4)
                             }]))
        case 17:                                                         // spin until dizzy
            a.state = 4; a.timer = 2.8
            n.run(.sequence([.repeat(.sequence([.wait(forDuration: 0.1), .run { [weak a] in a?.dir *= -1 }]), count: 10),
                             .run { [weak self, weak a] in
                                 guard let self, let a else { return }
                                 self.face(a, 11, 1.6); self.wiggle(a, 0.12, times: 4)
                             }]))
        case 18:                                                         // a magic trick
            a.timer = 2.6; a.squash = 0.2
            face(a, 3, 0.5)
            n.run(.sequence([.wait(forDuration: 0.5), .run { [weak self, weak a] in
                guard let self, let a else { return }
                let w = self.world(a, CGPoint(x: h.x + 24, y: h.y + 6))
                self.bits(7, at: w, tex: Art.twinkle, size: CGSize(width: 8, height: 8), colors: [0xFFFFFF, 0xFFE9A8, 0xFFD1F0], up: 60...190)
                self.emote([Art.star, Art.heart, Art.note, Art.cup].randomElement()!, x: w.x, y: w.y + 8)
                self.face(a, 4, 1.6)
                self.say(a, "ta-da!", 1.5)
            }]))
        case 19:                                                         // creep up on the other one
            guard let o = buddy(a), o.state == 0 || o.state == 2, !a.bar else { laugh(a); return }
            let ox = o.node.position.x
            a.state = 1; a.goal = 12; a.sit = false
            a.target = ox + (p.x < ox ? -48 : 48) * k
        case 20:                                                         // makes eyes at you
            if abs(mouse.x - p.x) < 520 { a.dir = mouse.x > p.x ? 1 : -1 }
            face(a, 10, 2.2)
            for i in 0..<2 { emote(Art.heart, x: p.x + rnd(-12, 12), y: p.y + (56 + CGFloat(i) * 10) * k) }
        default: weatherPlay(a)
        }
    }

    /// Something to do with whatever is falling right now.
    func weatherPlay(_ a: PetActor) {
        let n = a.node, p = n.position, k = scaleOf(a) / 0.7, h = headOf(a)
        let after: (Double, @escaping (PetActor) -> Void) -> Void = { delay, body in
            n.run(.sequence([.wait(forDuration: delay), .run { [weak a] in if let a { body(a) } }]))
        }
        switch Settings.shared.weather {
        case .snow:
            if Bool.random(), !a.bar {                                   // a snow angel
                a.state = 4; a.timer = 2.7
                face(a, 4, 2.5)
                let d = a.dir
                n.run(.sequence([.rotate(toAngle: -1.45 * d, duration: 0.2),
                                 .repeat(.sequence([.rotate(toAngle: -1.3 * d, duration: 0.16), .rotate(toAngle: -1.6 * d, duration: 0.16)]), count: 5),
                                 .rotate(toAngle: 0, duration: 0.15), .run { [weak a] in a?.squash = 0.2 }]), withKey: "wig")
                bits(10, at: CGPoint(x: p.x, y: p.y + 4), tex: Art.snowDot, size: CGSize(width: 4, height: 4), colors: [0xFFFFFF], up: 50...150)
            } else {                                                     // catch a flake on the nose
                face(a, 4, 1.2); hop(a, height: 30)
                emote(Art.flakes[0], x: p.x + a.dir * 14 * k, y: p.y + 70 * k).node.size = CGSize(width: 11, height: 11)
            }
        case .rain:
            if Bool.random() {                                           // out comes the umbrella
                setProp(a, "umbrella")
                a.timer = 5.5
                face(a, 4, 2)
                after(5.5) { [weak self] a in if a.propKind == "umbrella" { self?.setProp(a, "") } }
            } else {                                                     // puddle stomping
                face(a, 8, 1.6); hop(a, height: 14, times: 3)
                for i in 0..<3 {
                    after(0.3 + Double(i) * 0.36) { [weak self] a in
                        self?.bits(5, at: CGPoint(x: a.node.position.x, y: a.node.position.y + 2), tex: Art.dot,
                                   size: CGSize(width: 3, height: 3), colors: [0xCFE6FF, 0x9CC8F5], up: 60...170)
                    }
                }
            }
        case .leaves:                                                    // throw an armful in the air
            face(a, 8, 1.5); a.squash = 0.2
            bits(9, at: CGPoint(x: p.x + a.dir * 8 * k, y: p.y + 18 * k), tex: Art.leaves[0], size: CGSize(width: 12, height: 12),
                 colors: [0xE2703A, 0xD9A53C, 0xC9492F, 0xE8B84A], up: 150...300)
        case .sakura:                                                    // a petal lands on its nose
            let w = world(a, CGPoint(x: h.x, y: h.y + 40))
            let q = emote(Art.petal, x: w.x, y: w.y)
            q.vx = 0; q.vy = -34 * k; q.life = 1; q.maxLife = 1.6
            face(a, 5, 0.9)
            after(0.9) { [weak self] a in self?.face(a, 10, 1.6) }
        case .starfall:                                                  // make a wish
            a.sit = true; a.timer = 3.2
            face(a, 3, 2)
            after(1.9) { [weak self] a in
                guard let self else { return }
                let w = self.world(a, CGPoint(x: h.x, y: h.y + 30))
                self.bits(7, at: w, tex: Art.twinkle, size: CGSize(width: 8, height: 8), colors: [0xFFFFFF, 0xFFE9A8], up: 50...170)
                self.face(a, 4, 1.2)
            }
        case .fireflies:                                                 // one lands on its nose
            let w = world(a, CGPoint(x: h.x + 16, y: h.y + 2))
            let q = emote(Art.firefly, x: w.x, y: w.y)
            q.node.blendMode = .add
            q.node.color = SKColor(cgColor: rgb(0xE8FF8A)) ?? .yellow
            q.node.colorBlendFactor = 1
            q.vx = a.dir * 4; q.vy = 5; q.life = 2.2; q.maxLife = 2.2
            face(a, 5, 1.2)
            after(1.2) { [weak self] a in self?.face(a, 10, 1.2) }
        case .off:
            wiggle(a, 0.12, times: 2); face(a, 4, 0.9)
        }
    }
}
