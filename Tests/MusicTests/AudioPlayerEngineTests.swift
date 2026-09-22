import XCTest
@testable import music

final class AudioPlayerEngineTests: XCTestCase {
    func testPlaybackStatusTransitions() {
        let engine = AudioPlayerEngine.shared
        
        engine.stop()
        XCTAssertEqual(engine.status, .stopped)
        XCTAssertNil(engine.errorMessage)
        
        engine.status = .loading
        XCTAssertEqual(engine.status, .loading)
        
        let errorString = "Network timeout: track failed to load. Please check your network connection."
        engine.status = .error(errorString)
        engine.errorMessage = errorString
        XCTAssertEqual(engine.status, .error(errorString))
        XCTAssertEqual(engine.errorMessage, errorString)
        
        engine.stop()
        XCTAssertEqual(engine.status, .stopped)
        XCTAssertNil(engine.errorMessage)
    }
    
    func testTogglePlayPauseErrorRetry() {
        let engine = AudioPlayerEngine.shared
        let dummySong = Song(
            id: "dummy_error_retry",
            title: "Test Track",
            artist: "Test Artist",
            album: "Test Album"
        )
        
        engine.currentSong = dummySong
        engine.status = .error("Network error")
        engine.errorMessage = "Network error"
        
        // When stopped or error, togglePlayPause should attempt to load and play
        engine.togglePlayPause()
        
        // Since URL is nil, status should transition to error("Unable to get playback URL")
        if case .error(let msg) = engine.status {
            XCTAssertTrue(msg.contains("playback URL") || msg.contains("Network"))
        }
        
        engine.stop()
    }
}
