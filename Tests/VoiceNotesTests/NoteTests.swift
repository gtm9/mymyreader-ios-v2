import XCTest
@testable import VoiceNotes

final class NoteTests: XCTestCase {
    
    func testNoteInitialization() {
        let note = Note(title: "Hello World", body: "Hello World")
        
        XCTAssertEqual(note.body, "Hello World")
        XCTAssertEqual(note.title, "Hello World")
        XCTAssertEqual(note.preview, "Hello World")
        XCTAssertNil(note.audioFileName)
        XCTAssertNil(note.audioFileURL)
        XCTAssertNotNil(note.createdAt)
    }
    
    func testNotePreviewGenerationWithShortText() {
        let note = Note(body: "Short text.")
        XCTAssertEqual(note.preview, "Short text.")
    }
    
    func testNotePreviewGenerationWithLongText() {
        let longText = String(repeating: "A", count: 150)
        let note = Note(body: longText)
        let expectedPreview = String(repeating: "A", count: 100) + "…"
        XCTAssertEqual(note.preview, expectedPreview)
    }
    
    func testNoteEmptyText() {
        let note = Note(body: "")
        XCTAssertEqual(note.title, "")
        XCTAssertEqual(note.preview, "No additional text")
    }
}
