import XCTest
@testable import music

final class PlayQueueLogicTests: XCTestCase {
    func testQueueNextPreviousNavigation() {
        let queueManager = PlayQueueManager.shared
        let song1 = Song(id: "1", title: "Song 1", artist: "Artist 1", album: "Album 1")
        let song2 = Song(id: "2", title: "Song 2", artist: "Artist 2", album: "Album 2")
        let song3 = Song(id: "3", title: "Song 3", artist: "Artist 3", album: "Album 3")
        
        queueManager.playMode = .sequence
        queueManager.setQueue([song1, song2, song3], startAt: 0)
        
        XCTAssertEqual(queueManager.currentSong?.id, "1")
        
        let next1 = queueManager.nextSong()
        XCTAssertEqual(next1?.id, "2")
        
        let next2 = queueManager.nextSong()
        XCTAssertEqual(next2?.id, "3")
        
        let next3 = queueManager.nextSong() // End of sequence
        XCTAssertNil(next3)
        
        let prev = queueManager.previousSong()
        XCTAssertEqual(prev?.id, "2")
    }
    
    func testQueueInsertNext() {
        let queueManager = PlayQueueManager.shared
        let song1 = Song(id: "1", title: "Song 1", artist: "Artist 1", album: "Album 1")
        let song2 = Song(id: "2", title: "Song 2", artist: "Artist 2", album: "Album 2")
        let song3 = Song(id: "3", title: "Song 3", artist: "Artist 3", album: "Album 3")
        
        queueManager.setQueue([song1, song2], startAt: 0)
        queueManager.insertNext(song3)
        
        XCTAssertEqual(queueManager.queue.count, 3)
        XCTAssertEqual(queueManager.queue[1].id, "3")
    }
}
