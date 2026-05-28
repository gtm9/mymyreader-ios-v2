import Foundation
import AVFoundation
import Qwen3TTS
import MLX
import os

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

    init() {
        // Enforce strict memory limits to survive iOS Jetsam
        MLX.Memory.memoryLimit = 1250 * 1024 * 1024  // 1.25 GB
        MLX.Memory.cacheLimit = 16 * 1024 * 1024       // 16 MB

        if let url = Bundle.main.url(forResource: "Qwen3-TTS-12Hz-0.6B-Base-4bit", withExtension: nil) {
            Task { await loadModel(at: url) }
        } else {
            self.errorMessage = "TTS model not found in app bundle."
        }
    }

    func loadModel(at url: URL) async {
        logger.info("Starting TTS model load from \(url.lastPathComponent)")
        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            // loadAudioEncoder: false — we only need speaker embeddings, not ICL vocoder
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

    /// Generate audio for the given note text using the supplied reference voice.
    /// Returns the URL of the saved WAV file.
    func generateAudio(for noteText: String, referenceAudioURL: URL) async throws -> URL {
        logger.info("Starting audio generation for text of length \(noteText.count)")
        let totalStartTime = CFAbsoluteTimeGetCurrent()
        guard let pipeline = pipeline else {
            logger.error("Failed to generate: TTS model not loaded.")
            throw TTSError.modelNotLoaded
        }

        await MainActor.run {
            self.isGenerating = true
            self.generationProgress = 0.0
            self.errorMessage = nil
        }

        defer {
            Task { @MainActor in
                self.isGenerating = false
                self.generationProgress = 0.0
            }
        }

        // 1. Load & normalise reference audio
        let audioSamples = try loadAudioSamples(from: referenceAudioURL)

        // 2. Extract speaker embedding
        guard let embedding = pipeline.extractSpeakerEmbedding(audioSamples: audioSamples) else {
            throw TTSError.embeddingFailed
        }

        await MainActor.run { self.generationProgress = 0.1 }

        // 3. Chunk text into ≤10-word pieces to keep KV cache within 200 tokens
        let chunks = chunkText(noteText)
        let totalChunks = Double(chunks.count)

        // 4. Output file in Documents/AudioNotes/
        let outputURL = try prepareOutputURL()

        // 5. Generate each chunk sequentially and combine
        var allSamples: [Float] = []
        logger.info("Divided text into \(chunks.count) chunks. Beginning sequential generation.")
        for (index, chunk) in chunks.enumerated() {
            let chunkStartTime = CFAbsoluteTimeGetCurrent()
            logger.debug("Generating chunk \(index + 1)/\(chunks.count) (\(chunk.count) characters)")
            let chunkURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("chunk_\(index)_\(UUID().uuidString).wav")
            _ = try await pipeline.generateToFile(
                text: chunk,
                speakerEmbedding: embedding,
                outputURL: chunkURL
            )
            let chunkSamples = try loadRawSamples(from: chunkURL)
            allSamples.append(contentsOf: chunkSamples)
            try? FileManager.default.removeItem(at: chunkURL)

            let chunkDuration = CFAbsoluteTimeGetCurrent() - chunkStartTime
            logger.info("Chunk \(index + 1) generated in \(String(format: "%.2f", chunkDuration)) seconds")

            let progress = 0.1 + (Double(index + 1) / totalChunks) * 0.9
            await MainActor.run { self.generationProgress = progress }
        }

        // 6. Write combined WAV
        try writeWAV(samples: allSamples, sampleRate: 24000, to: outputURL)

        let totalDuration = CFAbsoluteTimeGetCurrent() - totalStartTime
        logger.info("Finished audio generation. Total time: \(String(format: "%.2f", totalDuration)) seconds for \(chunks.count) chunks.")

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
