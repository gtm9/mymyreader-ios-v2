import SwiftUI
import SwiftData

struct NoteDetailView: View {
    @Bindable var note: Note
    let ttsManager: TTSManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var audioPlayer = AudioPlayer()
    @State private var isGenerating = false
    @State private var generationProgress: Double = 0
    @State private var showingVoiceSetup = false
    @State private var showError = false
    @State private var errorText = ""
    @State private var isEdited = false
    @FocusState private var bodyFocused: Bool
    
    let bgColor = Color(red: 0.98, green: 0.95, blue: 0.93) // Pastel beige/pink

    var referenceVoiceURL: URL? {
        guard let path = UserDefaults.standard.string(forKey: "referenceVoiceURL") else { return nil }
        return URL(fileURLWithPath: path)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Top Bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                    
                    Spacer()
                    
                    if isEdited {
                        Button {
                            // Dismiss keyboard to save
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            isEdited = false
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.black)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 16)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Title
                        TextField("Title", text: $note.title, axis: .vertical)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 4)
                            .onChange(of: note.title) { _, _ in 
                                note.updatedAt = Date()
                                isEdited = true
                            }
    
                        // Date chip
                        Text(note.updatedAt.formatted(date: .long, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(Color.black.opacity(0.5))
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
    
                        // Body
                        TextEditor(text: $note.body)
                            .font(.system(size: 20, weight: .regular))
                            .lineSpacing(6)
                            .foregroundStyle(.black.opacity(0.8))
                            .padding(.horizontal, 20)
                            .frame(minHeight: 300)
                            .scrollContentBackground(.hidden)
                            .focused($bodyFocused)
                            .onChange(of: note.body) { _, _ in 
                                note.updatedAt = Date()
                                isEdited = true
                            }
                    }
                    .padding(.bottom, bodyFocused ? 20 : 180) // Space for bottom player bar only when visible
                }
            }

            // Bottom audio bar
            if !bodyFocused {
                audioBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingVoiceSetup) { VoiceSetupView() }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText)
        }
    }

    // MARK: - Audio bar

    private var audioBar: some View {
        VStack(spacing: 0) {
            // Generation progress
            if isGenerating {
                VStack(spacing: 8) {
                    ProgressView(value: generationProgress)
                        .progressViewStyle(.linear)
                        .tint(.indigo)
                    Text("Generating audio… \(Int(generationProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .background(.ultraThinMaterial)
            }

            // Player controls
            if let audioURL = note.audioFileURL, FileManager.default.fileExists(atPath: audioURL.path) {
                playerControls(audioURL: audioURL)
            }

            // Generate / Voice setup button row
            HStack(spacing: 12) {
                // Voice status
                Button {
                    showingVoiceSetup = true
                } label: {
                    Label(
                        referenceVoiceURL != nil ? "Change Voice" : "Set Voice",
                        systemImage: referenceVoiceURL != nil ? "waveform.circle.fill" : "waveform.circle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(referenceVoiceURL != nil ? .indigo : .secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                // Generate button
                Button {
                    generateAudio()
                } label: {
                    if isGenerating {
                        ProgressView().tint(.white)
                    } else {
                        Label(
                            note.audioFileName != nil ? "Regenerate" : "Generate Audio",
                            systemImage: "waveform.and.mic"
                        )
                        .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isGenerating || note.body.isEmpty ? Color.secondary : Color.indigo)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .disabled(isGenerating || note.body.isEmpty || !ttsManager.isModelLoaded)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
    }

    private func playerControls(audioURL: URL) -> some View {
        VStack(spacing: 10) {
            // Progress bar
            Slider(
                value: Binding(
                    get: { audioPlayer.currentTime },
                    set: { audioPlayer.seek(to: $0) }
                ),
                in: 0...(audioPlayer.duration > 0 ? audioPlayer.duration : 1)
            )
            .tint(.indigo)
            .padding(.horizontal, 20)

            HStack {
                Text(formatTime(audioPlayer.currentTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()

                // Play / Pause
                Button {
                    if audioPlayer.isPlaying {
                        audioPlayer.pause()
                    } else {
                        audioPlayer.play(url: audioURL)
                    }
                } label: {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.indigo)
                        .symbolRenderingMode(.hierarchical)
                }

                Spacer()
                Text(formatTime(audioPlayer.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    private func generateAudio() {
        guard let refURL = referenceVoiceURL else {
            showingVoiceSetup = true
            return
        }
        guard !note.body.isEmpty else { return }

        isGenerating = true
        generationProgress = 0

        Task {
            do {
                let outputURL = try await ttsManager.generateAudio(
                    for: note.body,
                    referenceAudioURL: refURL
                )
                // Store just the filename (relative path)
                let fileName = outputURL.lastPathComponent
                note.audioFileName = fileName

                // Load duration
                let asset = try AVAudioFile(forReading: outputURL)
                note.audioDuration = Double(asset.length) / asset.fileFormat.sampleRate

                note.updatedAt = Date()
            } catch {
                errorText = error.localizedDescription
                showError = true
            }
            isGenerating = false
            generationProgress = 0
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// Global hack to re-enable swipe-to-go-back when navigation bar is hidden
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}

// AVAudioFile import needed
import AVFoundation
