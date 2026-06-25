import AVFoundation
import Foundation

final class SoundEffectPlayer: NSObject {
    static let shared = SoundEffectPlayer()

    enum Effect {
        case laneShift
        case dodge
        case spark
        case crash
    }

    private var cachedData: [Effect: Data] = [:]
    private var activePlayers: [AVAudioPlayer] = []

    private override init() {
        super.init()
        configureSession()
    }

    func play(_ effect: Effect) {
        let data = cachedData[effect] ?? makeSoundData(for: effect)
        cachedData[effect] = data

        do {
            let player = try AVAudioPlayer(data: data)
            player.volume = 0.45
            player.delegate = self
            activePlayers.append(player)
            player.prepareToPlay()
            player.play()
        } catch {
            activePlayers.removeAll()
        }
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
        }
    }

    private func makeSoundData(for effect: Effect) -> Data {
        let sampleRate = 44_100
        let duration: Double
        let frequencies: [Double]

        switch effect {
        case .laneShift:
            duration = 0.08
            frequencies = [540]
        case .dodge:
            duration = 0.12
            frequencies = [720, 920]
        case .spark:
            duration = 0.16
            frequencies = [880, 1175]
        case .crash:
            duration = 0.24
            frequencies = [190, 110]
        }

        let frameCount = Int(Double(sampleRate) * duration)
        var pcm = Data(capacity: frameCount * 2)

        for frame in 0..<frameCount {
            let time = Double(frame) / Double(sampleRate)
            let envelope = exp(-5.2 * time / duration)
            let sampleValue = frequencies.enumerated().reduce(0.0) { partial, item in
                let phaseOffset = Double(item.offset) * 0.35
                return partial + sin((2.0 * .pi * item.element * time) + phaseOffset)
            } / Double(frequencies.count)

            let shaped: Double
            if effect == .crash {
                shaped = (sampleValue * 0.6 + Double.random(in: -0.35...0.35)) * envelope
            } else {
                shaped = sampleValue * envelope
            }

            let intSample = Int16(max(-1.0, min(1.0, shaped)) * Double(Int16.max))
            var littleEndian = intSample.littleEndian
            withUnsafeBytes(of: &littleEndian) { bytes in
                pcm.append(contentsOf: bytes)
            }
        }

        return wavData(from: pcm, sampleRate: sampleRate)
    }

    private func wavData(from pcm: Data, sampleRate: Int) -> Data {
        var data = Data()
        let fileSize = 36 + pcm.count
        let byteRate = sampleRate * 2
        let blockAlign: UInt16 = 2
        let bitsPerSample: UInt16 = 16

        data.append("RIFF".data(using: .ascii)!)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian, Array.init))
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian, Array.init))
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian, Array.init))
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian, Array.init))
        data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian, Array.init))
        data.append(contentsOf: withUnsafeBytes(of: UInt32(byteRate).littleEndian, Array.init))
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian, Array.init))
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian, Array.init))
        data.append("data".data(using: .ascii)!)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(pcm.count).littleEndian, Array.init))
        data.append(pcm)

        return data
    }
}

extension SoundEffectPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        activePlayers.removeAll { $0 === player }
    }
}
