import AVFoundation

/// Soft synthesized ambience: rain hiss, wind, or a quiet night with crickets. Off unless the user turns it on.
final class Ambience {
    static let shared = Ambience()
    private let engine = AVAudioEngine()
    private var node: AVAudioSourceNode?
    private var mode: Int32 = 0        // 1 rain, 2 wind, 3 night; read on the audio thread
    private var target: Float = 0

    func set(_ weather: Weather, on: Bool) {
        let m: Int32
        switch weather {
        case .rain: m = 1
        case .snow, .leaves, .sakura: m = 2
        case .starfall, .fireflies: m = 3
        case .off: m = 0
        }
        guard on, m != 0 else {
            target = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                if let s = self, s.target == 0, s.engine.isRunning { s.engine.pause() }
            }
            return
        }
        mode = m
        target = 0.5
        if node == nil { build() }
        if !engine.isRunning { try? engine.start() }
    }

    private func build() {
        var sr = engine.outputNode.outputFormat(forBus: 0).sampleRate
        if sr < 8000 { sr = 44100 }
        var gain: Float = 0, lp1: Float = 0, lp2: Float = 0
        var seed: UInt32 = 12345
        var t = 0.0
        let step = 1 / sr
        let src = AVAudioSourceNode { [unowned self] _, _, frames, abl -> OSStatus in
            let bufs = UnsafeMutableAudioBufferListPointer(abl)
            let m = self.mode, tg = self.target
            for i in 0..<Int(frames) {
                seed = seed &* 1664525 &+ 1013904223
                let white = Float(Int32(bitPattern: seed)) / 2147483648
                gain += (tg - gain) * 0.00005
                t += step
                var s: Float = 0
                switch m {
                case 1:
                    lp1 += 0.25 * (white - lp1); lp2 += 0.01 * (white - lp2)
                    s = (lp1 - lp2) * 0.2
                case 2:
                    lp1 += 0.012 * (white - lp1)
                    s = lp1 * 3.0 * Float(0.55 + 0.3 * sin(t * 0.5) + 0.15 * sin(t * 0.23 + 1))
                case 3:
                    lp1 += 0.006 * (white - lp1)
                    s = lp1 * 1.5
                    let cyc = t.truncatingRemainder(dividingBy: 1.7)
                    if cyc < 0.24 {
                        let sub = cyc.truncatingRemainder(dividingBy: 0.08)
                        if sub < 0.035 { s += Float(sin(t * 2 * .pi * 4300) * 0.018 * sin(sub / 0.035 * .pi)) }
                    }
                default: break
                }
                let v = s * gain
                for b in bufs { b.mData?.assumingMemoryBound(to: Float.self)[i] = v }
            }
            return noErr
        }
        engine.attach(src)
        engine.connect(src, to: engine.mainMixerNode, format: AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2))
        engine.mainMixerNode.outputVolume = 0.6
        node = src
    }
}
