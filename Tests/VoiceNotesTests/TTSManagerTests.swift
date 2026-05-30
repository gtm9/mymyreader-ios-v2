import XCTest
@testable import VoiceNotes

final class TTSManagerTests: XCTestCase {
    
    func testInitialization() {
        let manager = TTSManager()
        XCTAssertFalse(manager.isGenerating)
        XCTAssertTrue(manager.pendingNotes.isEmpty)
        XCTAssertNil(manager.activeNoteID)
    }
}
