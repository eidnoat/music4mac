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
    
    func testRemoveSongsUpdatesDerivedCollections() {
        let storage = StorageManager.shared
        let originalSongs = storage.songs
        
        let song1 = Song(id: "remove_1", title: "Song 1", artist: "Artist 1", album: "Album 1", localPath: "/tmp/music/1.mp3")
        let song2 = Song(id: "remove_2", title: "Song 2", artist: "Artist 2", album: "Album 2", localPath: "/other/music/2.mp3")
        
        storage.songs = [song1, song2]
        storage.updateDerivedCollections()
        XCTAssertEqual(storage.songs.count, 2)
        XCTAssertEqual(storage.albums.count, 2)
        XCTAssertEqual(storage.artists.count, 2)
        
        storage.removeSongs { $0.localPath?.hasPrefix("/tmp/music") == true }
        
        XCTAssertEqual(storage.songs.count, 1)
        XCTAssertEqual(storage.songs.first?.id, "remove_2")
        XCTAssertEqual(storage.albums.count, 1)
        XCTAssertEqual(storage.albums.first?.title, "Album 2")
        XCTAssertEqual(storage.artists.count, 1)
        XCTAssertEqual(storage.artists.first?.name, "Artist 2")
        
        // Restore
        storage.songs = originalSongs
        storage.updateDerivedCollections()
    }
    
    func testLastPlayedComparableSorting() {
        let now = Date()
        let song1 = Song(id: "s1", title: "S1", artist: "A", album: "Alb", lastPlayed: now.addingTimeInterval(-100))
        let song2 = Song(id: "s2", title: "S2", artist: "A", album: "Alb", lastPlayed: now)
        let song3 = Song(id: "s3", title: "S3", artist: "A", album: "Alb", lastPlayed: nil)
        
        let songs = [song1, song2, song3]
        let sortedDesc = songs.sorted(by: { $0.lastPlayedComparable > $1.lastPlayedComparable })
        
        XCTAssertEqual(sortedDesc[0].id, "s2")
        XCTAssertEqual(sortedDesc[1].id, "s1")
        XCTAssertEqual(sortedDesc[2].id, "s3")
    }
}
