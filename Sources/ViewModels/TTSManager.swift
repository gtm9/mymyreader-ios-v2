import Foundation
import AVFoundation
import Qwen3TTS
import MLX
import os
#if os(iOS)
import UIKit
#endif

private let logger = Logger(subsystem: "com.example.VoiceNotes", category: "TTSManager")

/// Manages TTS generation for note playback.
/// Applies all memory optimizations from VoiceCloner_Learnings.md:
///  - No double eval() before weight loading
///  - maxTokens capped at 200 per chunk
///  - MLX cache limit of 16 MB
@Observable
class TTSManager {
    private var pipeline: Qwen3TTSPipeline?
    var isModelLoaded = false
    var isGenerating = false
    var generationProgress: Double = 0.0
    var errorMessage: String?
    
    var activeNoteID: UUID?
    var generationStartTime: CFAbsoluteTime?
    
    var pendingNotes: Set<UUID> = []
    private var latestTask: Task<URL, Error>?
    
    // Caching
    private var cachedReferenceURL: URL?
    private var promptCache: TTSPromptCache?
    
    // Streaming Player
    let streamPlayer = AudioStreamPlayer()

    private var lifecycleObserver: Any?

    init() {
        // Bypass MLX Metal initialization on CI runners and during tests
        let isTesting = ProcessInfo.processInfo.arguments.contains("-UITest") || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if isTesting {
            self.errorMessage = "Mocked TTS for UI Tests"
            return
        }

        // Enforce strict memory limits to survive iOS Jetsam
        MLX.Memory.memoryLimit = 1250 * 1024 * 1024  // 1.25 GB
        MLX.Memory.cacheLimit = 16 * 1024 * 1024       // 16 MB

        if let url = Bundle.main.url(forResource: "Qwen3-TTS-12Hz-0.6B-Base-4bit", withExtension: nil) {
            Task { await loadModel(at: url) }
        } else {
            self.errorMessage = "TTS model not found in app bundle."
        }
        
        #if os(iOS)
        lifecycleObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleBackgroundTransition()
        }
        #endif
    }
    
    deinit {
        if let observer = lifecycleObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func handleBackgroundTransition() {
        logger.info("App entering background. Cancelling active TTS tasks to prevent Metal crash.")
        self.latestTask?.cancel()
        self.pendingNotes.removeAll()
        self.activeNoteID = nil
        self.isGenerating = false
        self.generationProgress = 0.0
    }

    func loadModel(at url: URL) async {
        logger.info("Starting TTS model load from \(url.lastPathComponent)")
        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            let config = Qwen3TTSPipelineConfiguration(loadAudioEncoder: false)
            let newPipeline = try Qwen3TTSPipeline(modelPath: url, configuration: config)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("Successfully loaded TTS model in \(String(format: "%.2f", duration)) seconds")
            await MainActor.run {
                self.pipeline = newPipeline
                self.isModelLoaded = true
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load TTS model: \(error.localizedDescription)"
                self.isModelLoaded = false
            }
        }
    }
    
    /// Precomputes and caches the voice embedding if the reference audio changed.
    private func updatePromptCacheIfNeeded(referenceAudioURL: URL) throws {
        guard let pipeline = pipeline else { throw TTSError.modelNotLoaded }
        
        if cachedReferenceURL != referenceAudioURL || promptCache == nil {
            logger.info("Building new Prompt Cache for voice cloning...")
            let audioSamples = try loadAudioSamples(from: referenceAudioURL)
            guard let cache = pipeline.buildPromptCache(from: audioSamples) else {
                throw TTSError.embeddingFailed
            }
            self.promptCache = cache
            self.cachedReferenceURL = referenceAudioURL
        }
    }

    /// Generate audio for the given note text using the supplied reference voice.
    /// Streams directly to AudioStreamPlayer and saves to a WAV file when complete.
    func generateAudio(for noteText: String, referenceAudioURL: URL, noteID: UUID) async throws -> URL {
        await MainActor.run {
            self.pendingNotes.insert(noteID)
        }
        
        let previousTask = self.latestTask
        let newTask = Task {
            // Wait for previous generation to finish before starting this one
            _ = try? await previousTask?.value
            return try await self.generateAudioInternal(for: noteText, referenceAudioURL: referenceAudioURL, noteID: noteID)
        }
        
        self.latestTask = newTask
        
        do {
            return try await newTask.value
        } catch {
            await MainActor.run {
                self.pendingNotes.remove(noteID)
            }
            throw error
        }
    }
    
    private func generateAudioInternal(for noteText: String, referenceAudioURL: URL, noteID: UUID) async throws -> URL {
        await MainActor.run {
            self.pendingNotes.remove(noteID)
        }
        
        try Task.checkCancellation()

        logger.info("Starting audio generation for text of length \(noteText.count)")
        let totalStartTime = CFAbsoluteTimeGetCurrent()
        guard let pipeline = pipeline else {
            logger.error("Failed to generate: TTS model not loaded.")
            throw TTSError.modelNotLoaded
        }

        await MainActor.run {
            self.activeNoteID = noteID
            self.generationStartTime = totalStartTime
            self.isGenerating = true
            self.generationProgress = 0.0
            self.errorMessage = nil
            self.streamPlayer.isFinished = false
        }

        defer {
            Task { @MainActor in
                if self.activeNoteID == noteID {
                    self.activeNoteID = nil
                    self.generationStartTime = nil
                    self.isGenerating = false
                    self.generationProgress = 0.0
                }
            }
        }

        // 1. Build or retrieve KV Prompt Cache
        try updatePromptCacheIfNeeded(referenceAudioURL: referenceAudioURL)
        guard let cache = promptCache else { throw TTSError.embeddingFailed }
        await MainActor.run { self.generationProgress = 0.1 }

        // 2. Output file
        let outputURL = try prepareOutputURL()
        
        // 3. (Streaming removed per user request)
        // 4. Generate stream with crossfading enabled
        logger.info("Beginning streaming generation...")
        
        let temp = UserDefaults.standard.object(forKey: "voiceTemperature") as? Float ?? 0.85
        let chunkSz = UserDefaults.standard.object(forKey: "voiceChunkSize") as? Int ?? 12
        
        var allSamples: [Float] = []
        let audioStream = pipeline.generateStream(
            text: noteText,
            speakerEmbedding: cache.speakerEmbedding,
            temperature: temp,
            chunkSize: chunkSz
        )
        
        for try await chunk in audioStream {
            try Task.checkCancellation()
            allSamples.append(contentsOf: chunk.samples)
            
            // Progress estimation based on chunk count (approximate tokens)
            let approxTotalTokens = Float(TextChunker.estimateTokens(for: noteText))
            let generatedTokens = Float(chunk.tokenRange.upperBound)
            let progress = min(0.95, 0.1 + Double(generatedTokens / approxTotalTokens) * 0.85)
            await MainActor.run { self.generationProgress = progress }
        }
        
        await MainActor.run { self.generationProgress = 1.0 }

        // 5. Write combined WAV
        try writeWAV(samples: allSamples, sampleRate: 24000, to: outputURL)

        let totalDuration = CFAbsoluteTimeGetCurrent() - totalStartTime
        logger.info("Finished audio streaming. Total time: \(String(format: "%.2f", totalDuration)) seconds.")

        return outputURL
    }

    // MARK: - Private helpers

    private func chunkText(_ text: String) -> [String] {
        // Split on sentence boundaries first, then cap at 10 words
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var chunks: [String] = []
        for sentence in sentences {
            let words = sentence.split(separator: " ").map(String.init)
            var i = 0
            while i < words.count {
                let slice = words[i..<min(i + 10, words.count)].joined(separator: " ")
                chunks.append(slice)
                i += 10
            }
        }
        return chunks.isEmpty ? [text] : chunks
    }

    private func prepareOutputURL() throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioDir = docs.appendingPathComponent("AudioNotes")
        try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
        return audioDir.appendingPathComponent("\(UUID().uuidString).wav")
    }

    private func loadAudioSamples(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24000, channels: 1, interleaved: false)!
        guard let converter = AVAudioConverter(from: file.processingFormat, to: format) else {
            throw TTSError.audioConversionFailed
        }
        let frameCount = AVAudioFrameCount(file.length)
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount),
              let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(Double(frameCount) * 24000.0 / file.processingFormat.sampleRate)) else {
            throw TTSError.audioConversionFailed
        }
        try file.read(into: inputBuffer)
        var didProvide = false
        var convError: NSError?
        converter.convert(to: outputBuffer, error: &convError) { _, status in
            if didProvide { status.pointee = .noDataNow; return nil }
            didProvide = true; status.pointee = .haveData; return inputBuffer
        }
        if let e = convError { throw e }
        guard let floatData = outputBuffer.floatChannelData else { throw TTSError.audioConversionFailed }
        var samples = Array(UnsafeBufferPointer(start: floatData[0], count: Int(outputBuffer.frameLength)))
        // Peak normalise — AGC mode ensures input is already boosted, this is a safety net
        if let maxVal = samples.max(by: { abs($0) < abs($1) }), abs(maxVal) > 0, abs(maxVal) < 1.0 {
            let scale = 1.0 / abs(maxVal)
            samples = samples.map { $0 * scale }
        }
        return samples
    }

    private func loadRawSamples(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24000, channels: 1, interleaved: false)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)),
              let floatData = buffer.floatChannelData else { return [] }
        try file.read(into: buffer)
        return Array(UnsafeBufferPointer(start: floatData[0], count: Int(buffer.frameLength)))
    }

    private func writeWAV(samples: [Float], sampleRate: Int, to url: URL) throws {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(sampleRate), channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { ptr in
            buffer.floatChannelData![0].update(from: ptr.baseAddress!, count: samples.count)
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
}

enum TTSError: LocalizedError {
    case modelNotLoaded
    case embeddingFailed
    case audioConversionFailed

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "TTS model is not loaded yet."
        case .embeddingFailed: return "Could not extract speaker embedding. Ensure your reference audio contains clear speech."
        case .audioConversionFailed: return "Audio conversion failed."
        }
    }
}
