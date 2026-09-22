import XCTest
@testable import music

final class StorageManagerTests: XCTestCase {
    func testUpdateDerivedCollections() {
        let storage = StorageManager.shared
        let originalSongs = storage.songs
        
        let testSong1 = Song(
            id: "test_1",
            title: "Track A",
            artist: "Artist Alpha",
            album: "Album One",
            trackNumber: 1
        )
        let testSong2 = Song(
            id: "test_2",
            title: "Track B",
            artist: "Artist Alpha",
            album: "Album One",
            trackNumber: 2
        )
        let testSong3 = Song(
            id: "test_3",
            title: "Track C",
            artist: "Artist Beta",
            album: "Album Two",
            trackNumber: 1
        )
        
        storage.songs = [testSong1, testSong2, testSong3]
        storage.updateDerivedCollections()
        
        XCTAssertEqual(storage.albums.count, 2)
        XCTAssertEqual(storage.artists.count, 2)
        
        let albumOne = storage.albums.first(where: { $0.title == "Album One" })
        XCTAssertNotNil(albumOne)
        XCTAssertEqual(albumOne?.songCount, 2)
        XCTAssertEqual(albumOne?.songs.first?.title, "Track A")
        
        let artistAlpha = storage.artists.first(where: { $0.name == "Artist Alpha" })
        XCTAssertNotNil(artistAlpha)
        XCTAssertEqual(artistAlpha?.songCount, 2)
        XCTAssertEqual(artistAlpha?.albumCount, 1)
        
        // Restore
        storage.songs = originalSongs
        storage.updateDerivedCollections()
    }
    
    func testHistoryDeduplicationAndCapacity() {
        let storage = StorageManager.shared
        let originalHistory = storage.history
        
        let songA = Song(id: "hist_a", title: "A", artist: "Artist", album: "Album")
        let songB = Song(id: "hist_b", title: "B", artist: "Artist", album: "Album")
        
        storage.recordPlayStart(song: songA)
        storage.recordPlayStart(song: songB)
        storage.recordPlayStart(song: songA) // Duplicate should move to top
        
        XCTAssertEqual(storage.history.first, "hist_a")
        XCTAssertEqual(storage.history.filter { $0 == "hist_a" }.count, 1)
        
        // Restore
        storage.history = originalHistory
    }
}
