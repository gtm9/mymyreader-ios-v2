import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    /// Relative filename in the app's Documents/AudioNotes/ directory
    var audioFileName: String?
    var audioDuration: Double?
    var lastGenerationTime: Double?

    init(title: String = "", body: String = "") {
        self.id = UUID()
        self.title = title
        self.body = body
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var audioFileURL: URL? {
        guard let fileName = audioFileName else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("AudioNotes").appendingPathComponent(fileName)
    }

    var preview: String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxLen = 100
        if trimmed.count > maxLen {
            return String(trimmed.prefix(maxLen)) + "…"
        }
        return trimmed.isEmpty ? "No additional text" : trimmed
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(updatedAt) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(updatedAt) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: updatedAt)
    }
}
