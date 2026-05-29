import SwiftUI
import SwiftData

struct NoteDetailView: View {
    @Bindable var note: Note
    let ttsManager: TTSManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var audioPlayer = AudioPlayer()
    @State private var showingVoiceSetup = false
    @State private var showError = false
    @State private var errorText = ""
    @State private var isEdited = false
    @FocusState private var bodyFocused: Bool
    
    let bgColor = Color(red: 0.98, green: 0.95, blue: 0.93) // Pastel beige/pink

    var referenceVoiceURL: URL? {
        guard let name = UserDefaults.standard.string(forKey: "referenceVoiceURL") else { return nil }
        let fileName = (name as NSString).lastPathComponent
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }

    private var isCurrentlyGenerating: Bool {
        ttsManager.activeNoteID == note.id
    }

    private var isQueued: Bool {
        ttsManager.pendingNotes.contains(note.id)
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
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        bodyFocused = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .fontWeight(.semibold)
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
            if isCurrentlyGenerating {
                VStack(spacing: 8) {
                    ProgressView(value: ttsManager.generationProgress)
                        .progressViewStyle(.linear)
                        .tint(.indigo)
                    HStack {
                        Text("Generating audio… \(Int(ttsManager.generationProgress * 100))%")
                        Spacer()
                        if let start = ttsManager.generationStartTime {
                            TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                                Text(String(format: "%.1fs", CFAbsoluteTimeGetCurrent() - start))
                                    .monospacedDigit()
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .background(.ultraThinMaterial)
            } else if isQueued {
                VStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.indigo)
                    Text("Queued...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .background(.ultraThinMaterial)
            } else if let genTime = note.lastGenerationTime {
                Text(String(format: "Generated in %.2fs", genTime))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            // Player controls and Regenerate row
            HStack(spacing: 12) {
                if let audioURL = note.audioFileURL, FileManager.default.fileExists(atPath: audioURL.path) {
                    Button {
                        if audioPlayer.isPlaying {
                            audioPlayer.pause()
                        } else {
                            audioPlayer.play(url: audioURL)
                        }
                    } label: {
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 44)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 5)
                    }
                }
                
                // Voice status
                Button {
                    showingVoiceSetup = true
                } label: {
                    Label(
                        referenceVoiceURL != nil ? "Voice Set" : "Set Voice",
                        systemImage: referenceVoiceURL != nil ? "waveform.circle.fill" : "waveform.circle"
                    )
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .foregroundStyle(referenceVoiceURL != nil ? .indigo : .secondary)
                    .shadow(color: .black.opacity(0.05), radius: 3)
                }
                .buttonStyle(.plain)
                
                Spacer()

                // Generate button (Compact)
                Button {
                    if !isCurrentlyGenerating && !isQueued {
                        generateAudio()
                    }
                } label: {
                    Image(systemName: (isCurrentlyGenerating || isQueued) ? "clock.fill" : "arrow.triangle.2.circlepath")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background((isCurrentlyGenerating || isQueued) ? Color.gray : Color.black)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 5)
                }
                .disabled(isCurrentlyGenerating || isQueued)
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color(red: 0.94, green: 0.9, blue: 0.88))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 15, y: -5)
        .onDisappear {
            audioPlayer.stop()
        }
    }

    // MARK: - Actions

    private func generateAudio() {
        guard let refURL = referenceVoiceURL else {
            showingVoiceSetup = true
            return
        }
        guard !note.body.isEmpty else { return }

        Task {
            do {
                let startTime = CFAbsoluteTimeGetCurrent()
                let outputURL = try await ttsManager.generateAudio(
                    for: note.body,
                    referenceAudioURL: refURL,
                    noteID: note.id
                )
                // Store just the filename (relative path)
                let fileName = outputURL.lastPathComponent
                note.audioFileName = fileName

                // Load duration
                let asset = try AVAudioFile(forReading: outputURL)
                note.audioDuration = Double(asset.length) / asset.fileFormat.sampleRate

                note.lastGenerationTime = CFAbsoluteTimeGetCurrent() - startTime
                note.updatedAt = Date()
                
                audioPlayer.play(url: outputURL)
            } catch {
                errorText = error.localizedDescription
                showError = true
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// Global hack to re-enable swipe-to-go-back when navigation bar is hidden
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
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
