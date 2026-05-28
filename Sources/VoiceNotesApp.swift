import SwiftUI
import SwiftData

@main
struct VoiceNotesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: Note.self)
                .preferredColorScheme(.light)
        }
    }
}
