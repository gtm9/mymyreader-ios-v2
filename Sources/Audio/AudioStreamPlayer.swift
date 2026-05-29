import Foundation
import AVFoundation

@Observable
class AudioStreamPlayer: NSObject {
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let format: AVAudioFormat
    
    var isPlaying = false
    var isFinished = false

    override init() {
        self.format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24000, channels: 1, interleaved: false)!
        super.init()
    }
    
    func prepare() throws {
        stop()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        
        let newEngine = AVAudioEngine()
        let newNode = AVAudioPlayerNode()
        
        newEngine.attach(newNode)
        newEngine.connect(newNode, to: newEngine.mainMixerNode, format: format)
        try newEngine.start()
        newNode.play()
        
        self.engine = newEngine
        self.playerNode = newNode
        self.isPlaying = true
        self.isFinished = false
    }
    
    func scheduleBuffer(samples: [Float], isFinal: Bool) {
        guard let node = playerNode, isPlaying, !samples.isEmpty else {
            if isFinal { self.isFinished = true }
            return
        }
        
        let frameCount = AVAudioFrameCount(samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        
        samples.withUnsafeBufferPointer { ptr in
            buffer.floatChannelData![0].update(from: ptr.baseAddress!, count: samples.count)
        }
        
        if isFinal {
            node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: {
                DispatchQueue.main.async {
                    self.isFinished = true
                    self.stop()
                }
            })
        } else {
            node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        }
    }
    
    func stop() {
        playerNode?.stop()
        engine?.stop()
        engine = nil
        playerNode = nil
        isPlaying = false
    }
}
