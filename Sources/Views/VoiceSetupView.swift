import SwiftUI
import UniformTypeIdentifiers

struct VoiceSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = AudioRecorder()
    @State private var showFilePicker = false
    @State private var savedVoiceName: String? = nil

    var currentVoicePath: String? { UserDefaults.standard.string(forKey: "referenceVoiceURL") }
    
    let bgColor = Color(red: 0.98, green: 0.95, blue: 0.93) // Pastel beige/pink

    var body: some View {
        ZStack(alignment: .top) {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Top Bar
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.black.opacity(0.8))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 12) {
                            Text("Reference Voice")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(.black)
                            
                            Text("Record or upload 5–15 seconds of clear speech to clone your voice.")
                                .font(.system(size: 16))
                                .foregroundStyle(.black.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .padding(.top, 16)

                        // Current voice status
                        if let name = savedVoiceName ?? (currentVoicePath.map { URL(fileURLWithPath: $0).lastPathComponent }) {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color(red: 0.2, green: 0.6, blue: 0.4))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Active Voice")
                                        .font(.caption)
                                        .foregroundStyle(.black.opacity(0.6))
                                    Text(name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.black)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: .black.opacity(0.04), radius: 10, y: 5)
                            .padding(.horizontal, 24)
                        }

                        // Options
                        VStack(spacing: 16) {
                            // Record Button
                            Button {
                                if recorder.isRecording {
                                    recorder.stopRecording()
                                    if let url = recorder.recordedAudioURL {
                                        saveVoice(url: url)
                                    }
                                } else {
                                    recorder.requestPermissionAndRecord()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(recorder.isRecording ? .red : .black)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(recorder.isRecording ? "Stop Recording" : "Record a Voice Sample")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(.black)
                                        
                                        if recorder.isRecording {
                                            Text(String(format: "%.0f / 15 sec", recorder.recordingDuration))
                                                .font(.caption.monospacedDigit())
                                                .foregroundStyle(.red)
                                        } else {
                                            Text("Speak clearly for 15 seconds")
                                                .font(.caption)
                                                .foregroundStyle(.black.opacity(0.6))
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.black.opacity(0.1))
                                }
                                .padding(20)
                                .background(Color(red: 0.88, green: 0.9, blue: 0.95)) // Pastel blue
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                            }
                            .buttonStyle(.plain)

                            if let error = recorder.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            // Upload section
                            Button {
                                showFilePicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(.black)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Upload Audio File")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(.black)
                                        Text("WAV, M4A, MP3, FLAC")
                                            .font(.caption)
                                            .foregroundStyle(.black.opacity(0.6))
                                    }
                                    Spacer()
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.black.opacity(0.1))
                                }
                                .padding(20)
                                .background(Color(red: 0.88, green: 0.93, blue: 0.88)) // Pastel green
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)

                        Spacer(minLength: 40)
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        let docsURL = copyAudioToDocs(url: url)
                        saveVoice(url: docsURL ?? url)
                    }
                case .failure(let error):
                    print("File picker error: \(error)")
                }
            }
        }
    }

    private func saveVoice(url: URL) {
        UserDefaults.standard.set(url.path, forKey: "referenceVoiceURL")
        savedVoiceName = url.lastPathComponent
    }

    private func copyAudioToDocs(url: URL) -> URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent("ref_\(url.lastPathComponent)")
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        try? FileManager.default.copyItem(at: url, to: dest)
        return dest
    }
}
