import SwiftUI
import SwiftData
import PhotosUI

enum AppTab {
    case home
    case profile
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @State private var ttsManager = TTSManager()
    @State private var showingNewNote = false
    @State private var showingVoiceSetup = false
    @State private var searchText = ""
    @State private var currentTab: AppTab = .home
    @AppStorage("userName") private var userName = ""

    let bgColor = Color(red: 0.98, green: 0.95, blue: 0.93) // Pastel beige/pink

    var referenceVoiceSet: Bool {
        UserDefaults.standard.string(forKey: "referenceVoiceURL") != nil
    }

    var filteredNotes: [Note] {
        if searchText.isEmpty { return notes }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.body.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Top Bar
                    HStack {
                        Button {
                            showingVoiceSetup = true
                        } label: {
                            Image(systemName: "square.fill.on.square.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.black)
                                .rotationEffect(.degrees(45))
                        }
                        
                        Spacer()
                        
                        Button {
                            // no-op
                        } label: {
                            ZStack {
                                Circle()
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "circle.dashed")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.black)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    .zIndex(2)

                    if currentTab == .home {
                        homeContent
                    } else {
                        ProfileView(showingVoiceSetup: $showingVoiceSetup, referenceVoiceSet: referenceVoiceSet)
                    }
                }
            .background(
                bgColor
                    .ignoresSafeArea()
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            )
            .safeAreaInset(edge: .bottom) {
                // Bottom Tab Bar
                HStack {
                    // Left Pill
                    HStack(spacing: 0) {
                        Button {
                            currentTab = .home
                        } label: {
                            Image(systemName: "square.3.layers.3d")
                                .font(.system(size: 20))
                                .foregroundStyle(currentTab == .home ? .black : Color(red: 0.6, green: 0.6, blue: 0.6))
                                .padding(12)
                                .background(currentTab == .home ? Color.white : Color.clear)
                                .clipShape(Circle())
                        }
                        .accessibilityIdentifier("Home Tab")
                        
                        Button {
                            currentTab = .profile
                        } label: {
                            Image(systemName: "person")
                                .font(.system(size: 20))
                                .foregroundStyle(currentTab == .profile ? .black : Color(red: 0.6, green: 0.6, blue: 0.6))
                                .padding(12)
                                .background(currentTab == .profile ? Color.white : Color.clear)
                                .clipShape(Circle())
                        }
                        .accessibilityIdentifier("Profile Tab")
                    }
                    .padding(6)
                    .background(Color.black)
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    // Right Circle (Add button)
                    Button {
                        showingNewNote = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(Color.black)
                            .clipShape(Circle())
                    }
                    .accessibilityIdentifier("Create Note FAB")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingNewNote) {
                NewNoteView(ttsManager: ttsManager)
            }
            .sheet(isPresented: $showingVoiceSetup) {
                VoiceSetupView()
            }
        }
        .environment(ttsManager)
    }

    // MARK: - Subviews

    private var homeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Greeting
                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice notes")
                        .font(.subheadline)
                        .foregroundStyle(Color.gray)
                        .padding(.bottom, 4)
                    
                    HStack {
                        Text("Hello,")
                            .font(.system(size: 38, weight: .light))
                        Text(userName.isEmpty ? "there 👋" : "\(userName) 👋")
                            .font(.system(size: 38, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .foregroundStyle(.black)
                    
                    Text("What would you\nlike to hear today?")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.black)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 24)
                
                // Notes Grid
                if notes.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        ForEach(filteredNotes) { note in
                            NavigationLink {
                                NoteDetailView(note: note, ttsManager: ttsManager)
                            } label: {
                                NoteRowView(note: note)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteNote(note)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer().frame(height: 20)
                
                // Search Bar at bottom
                if !notes.isEmpty {
                    HStack {
                        TextField("", text: $searchText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                            .background(
                                HStack {
                                    if searchText.isEmpty {
                                        Text("Search notes..")
                                            .foregroundStyle(Color.black.opacity(0.4))
                                            .padding(.leading, 20)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(Color.black)
                                        .padding(.trailing, 20)
                                }
                            )
                    }
                    .background(Color(red: 0.94, green: 0.9, blue: 0.88)) // Match input style
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 24)
                }
                
                Spacer().frame(height: 120) // Space for bottom tab
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(Color.gray)
            Text("No Notes Yet")
                .font(.system(size: 20, weight: .bold))
            Text("Tap the + button below to create a note.")
                .font(.system(size: 14))
                .foregroundStyle(Color.gray)
            
            Button {
                showingNewNote = true
            } label: {
                Text("Create Note")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func deleteNote(_ note: Note) {
        if let audioURL = note.audioFileURL {
            try? FileManager.default.removeItem(at: audioURL)
        }
        modelContext.delete(note)
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @Binding var showingVoiceSetup: Bool
    let referenceVoiceSet: Bool
    
    @State private var showingAboutPage = false
    
    @State private var profileImageItem: PhotosPickerItem?
    @State private var profileImage: Image?
    @AppStorage("userName") private var userName = ""
    
    var body: some View {
        ScrollView {
            // Parallax Profile Image
            GeometryReader { geometry in
                let minY = geometry.frame(in: .global).minY
                let fadeOffset = max(0, -minY / 2)
                let initialHeight: CGFloat = 300
                
                if let profileImage {
                    profileImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: initialHeight + max(0, minY))
                        .clipped()
                        .opacity(max(0, 1.0 - (Double(fadeOffset) / 100.0)))
                        .offset(y: minY > 0 ? -minY : 0)
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.9, green: 0.85, blue: 0.95), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: geometry.size.width, height: initialHeight + max(0, minY))
                    .opacity(max(0, 1.0 - (Double(fadeOffset) / 100.0)))
                    .offset(y: minY > 0 ? -minY : 0)
                }
            }
            .frame(height: 300)
            
            VStack(alignment: .leading, spacing: 32) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Profile")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.black)
                            
                        TextField("Your Name", text: $userName)
                            .font(.system(size: 20, weight: .medium))
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.04), radius: 5)
                            .submitLabel(.done)
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                            
                        Text("Manage your preferences")
                            .font(.subheadline)
                            .foregroundStyle(.black.opacity(0.6))
                    }
                    Spacer()
                    
                    // Photo Picker Button
                    PhotosPicker(selection: $profileImageItem, matching: .images) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.8))
                                .frame(width: 44, height: 44)
                                .shadow(color: .black.opacity(0.1), radius: 5)
                            Image(systemName: "camera")
                                .foregroundStyle(.black)
                        }
                    }
                    .onChange(of: profileImageItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                profileImage = Image(uiImage: uiImage)
                                if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                                    let fileURL = dir.appendingPathComponent("profile.jpg")
                                    try? data.write(to: fileURL)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                // Profile options
                VStack(spacing: 16) {
                    Button {
                        showingVoiceSetup = true
                    } label: {
                        HStack {
                            Image(systemName: referenceVoiceSet ? "waveform.circle.fill" : "waveform.circle")
                                .font(.system(size: 24))
                                .foregroundStyle(referenceVoiceSet ? .black : .black.opacity(0.5))
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Reference Voice")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.black)
                                Text(referenceVoiceSet ? "Voice is set and ready" : "Not set")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.black.opacity(0.6))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Color.black.opacity(0.3))
                        }
                        .padding(24)
                        .background(Color.white.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 32))
                        .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)
                    
                    // About App
                    Button {
                        showingAboutPage = true
                    } label: {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.indigo)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("About VoiceNotes")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.black)
                                Text("Company info, Support, and Privacy")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.black.opacity(0.6))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Color.black.opacity(0.3))
                        }
                        .padding(24)
                        .background(Color.white.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 32))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("About VoiceNotes")
                    .sheet(isPresented: $showingAboutPage) {
                        AboutView()
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer().frame(height: 24)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = dir.appendingPathComponent("profile.jpg")
                if let data = try? Data(contentsOf: fileURL), let uiImage = UIImage(data: data) {
                    profileImage = Image(uiImage: uiImage)
                }
            }
        }
    }
}

// MARK: - Note Row (Square Card)

struct NoteRowView: View {
    let note: Note

    let cardColors: [Color] = [
        Color(red: 0.96, green: 0.9, blue: 0.9),  // Pink
        Color(red: 0.88, green: 0.93, blue: 0.88), // Green
        Color(red: 0.88, green: 0.9, blue: 0.95),  // Blue
        Color(red: 0.95, green: 0.93, blue: 0.88)  // Yellow
    ]
    
    var body: some View {
        let colorIndex = abs(note.id.hashValue) % cardColors.count
        let bgColor = cardColors[colorIndex]
        
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: note.audioFileName != nil ? "waveform" : "doc.text")
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(.black)
                .padding(.bottom, 16)
            
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .padding(.bottom, 6)
            
            Text(note.preview)
                .font(.system(size: 12))
                .foregroundStyle(Color.black.opacity(0.6))
                .lineLimit(2)
            
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(1, contentMode: .fill)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 8)
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    let bgColor = Color(red: 0.98, green: 0.95, blue: 0.93) // Pastel beige/pink

    var body: some View {
        ZStack(alignment: .top) {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Bar
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.black.opacity(0.8))
                    }
                    .accessibilityIdentifier("Close")
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                ScrollView {
                    VStack(spacing: 32) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.indigo)
                            .padding(.top, 20)
                            
                        VStack(spacing: 8) {
                            Text("VoiceNotes")
                                .font(.system(size: 32, weight: .bold))
                            Text("Version 1.0.0")
                                .font(.system(size: 16))
                                .foregroundStyle(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Company Information")
                                .font(.system(size: 20, weight: .semibold))
                                .padding(.bottom, 4)
                                
                            InfoRow(title: "Developer", value: "Remarga Tech Private Limited")
                            
                            Link(destination: URL(string: "https://remarga.com")!) {
                                InfoRow(title: "Website", value: "remarga.com", isLink: true)
                            }
                            
                            Link(destination: URL(string: "https://remarga.com/support")!) {
                                InfoRow(title: "Support", value: "Contact Us", isLink: true)
                            }
                            
                            Link(destination: URL(string: "https://remarga.com/privacy")!) {
                                InfoRow(title: "Privacy Policy", value: "Read Policy", isLink: true)
                            }
                        }
                        .padding(24)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .black.opacity(0.04), radius: 10, y: 5)
                        .padding(.horizontal, 24)
                        
                        Text("© 2026 Remarga Tech Private Limited. All rights reserved.")
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.top, 20)
                    }
                }
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    var isLink: Bool = false
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(.black)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isLink ? .indigo : .black.opacity(0.7))
            if isLink {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.indigo)
            }
        }
    }
}
