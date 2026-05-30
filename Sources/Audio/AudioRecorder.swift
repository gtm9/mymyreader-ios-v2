import Foundation
import AVFoundation

@Observable
class AudioRecorder: NSObject {
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?

    var recordedAudioURL: URL?
    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var errorMessage: String?

    private let maxDuration: TimeInterval = 15.0

    func requestPermissionAndRecord() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.startRecording()
                } else {
                    self?.errorMessage = "Microphone permission is required to record a reference voice."
                }
            }
        }
    }

    func startRecording() {
        stopRecording()
        recordedAudioURL = nil
        recordingDuration = 0

        do {
            let session = AVAudioSession.sharedInstance()
            // Use .default mode to enable Apple's AGC and noise suppression
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = docs.appendingPathComponent("reference_voice_\(UUID().uuidString).m4a")

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record(forDuration: maxDuration)

            isRecording = true
            startTimer()
        } catch {
            errorMessage = "Recording failed: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        if let url = audioRecorder?.url, FileManager.default.fileExists(atPath: url.path) {
            recordedAudioURL = url
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingDuration += 0.1
            if self.recordingDuration >= self.maxDuration {
                self.stopRecording()
            }
        }
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.timer?.invalidate()
            self.timer = nil
            if flag {
                self.recordedAudioURL = recorder.url
            }
        }
    }
}
