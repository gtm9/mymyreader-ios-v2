import SwiftUI
import SwiftData

struct NewNoteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let ttsManager: TTSManager

    @State private var title = ""
    @State private var noteBody = ""
    @FocusState private var focusedField: Field?

    enum Field { case title, body }
    
    let bgColor = Color(red: 0.98, green: 0.95, blue: 0.93) // Pastel beige/pink

    var body: some View {
        ZStack(alignment: .top) {
            bgColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Top Bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundStyle(.black)
                    }
                    
                    Spacer()
                    
                    if !title.isEmpty || !noteBody.isEmpty {
                        Button {
                            saveNote()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.black)
                        }
                        .accessibilityIdentifier("Save Note")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)

                // Title field
                TextField("Note title...", text: $title)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .body }

                // Body field
                TextEditor(text: $noteBody)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.black.opacity(0.8))
                    .padding(.horizontal, 20)
                    .focused($focusedField, equals: .body)
                    .scrollContentBackground(.hidden)
            }
        }
        .onAppear { focusedField = .title }
    }

    private func saveNote() {
        // Dismiss keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        let note = Note(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: noteBody.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(note)
        dismiss()
    }
}
