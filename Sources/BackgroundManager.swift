import AVFoundation

class BackgroundManager {
    static let shared = BackgroundManager()
    private var audioPlayer: AVAudioPlayer?

    func start() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let sampleRate = 8000
            let numSamples = sampleRate
            var data = Data()
            let dataSize = numSamples * 2
            let fileSize = 36 + dataSize
            
            data.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
            data.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
            data.append(contentsOf: [0x57, 0x41, 0x56, 0x45])
            data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
            data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate * 2).littleEndian) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })
            data.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
            data.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
            data.append(Data(repeating: 0, count: dataSize))
            
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.play()
        } catch {
            print("Audio error: \(error)")
        }
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}
