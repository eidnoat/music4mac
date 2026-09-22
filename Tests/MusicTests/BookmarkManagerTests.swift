import XCTest
@testable import music

final class BookmarkManagerTests: XCTestCase {
    func testBookmarkManagerConcurrentAccess() {
        let manager = BookmarkManager.shared
        
        DispatchQueue.concurrentPerform(iterations: 100) { i in
            let dummyUrl = URL(fileURLWithPath: "/tmp/music_test_dir_\(i % 10)")
            _ = manager.startAccessing(url: dummyUrl)
            manager.stopAccessing(url: dummyUrl)
        }
    }
    
    func testTrackAccessCycle() {
        let manager = BookmarkManager.shared
        let track1 = URL(fileURLWithPath: "/tmp/music_test_track1.mp3")
        let track2 = URL(fileURLWithPath: "/tmp/music_test_track2.mp3")
        
        _ = manager.startAccessingTrack(url: track1)
        _ = manager.startAccessingTrack(url: track2)
        manager.stopAccessingTrack()
    }
}
