import Foundation
import AVFoundation

@Observable
class AudioPlayer: NSObject {
    private var player: AVAudioPlayer?
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    private var displayTimer: Timer?

    func play(url: URL) {
        stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.play()
            duration = player?.duration ?? 0
            isPlaying = true
            startDisplayTimer()
        } catch {
            print("AudioPlayer error: \(error)")
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        displayTimer?.invalidate()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        displayTimer?.invalidate()
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    private func startDisplayTimer() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.currentTime = player.currentTime
        }
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = 0
            self.displayTimer?.invalidate()
        }
    }
}
