import XCTest
@testable import music

final class SongCacheManagerTests: XCTestCase {
    func testMaxSizeClamping() {
        let manager = SongCacheManager.shared
        let original = manager.maxSizeGB
        
        manager.maxSizeGB = 0
        XCTAssertEqual(manager.maxSizeGB, 1)
        
        manager.maxSizeGB = 25
        XCTAssertEqual(manager.maxSizeGB, 20)
        
        manager.maxSizeGB = 10
        XCTAssertEqual(manager.maxSizeGB, 10)
        
        // Restore
        manager.maxSizeGB = original
    }
    
    func testEnableDisableState() {
        let manager = SongCacheManager.shared
        let original = manager.isEnabled
        
        manager.isEnabled = false
        XCTAssertFalse(manager.isEnabled)
        XCTAssertFalse(manager.isSongCached(id: "any_song"))
        
        manager.isEnabled = true
        XCTAssertTrue(manager.isEnabled)
        
        // Restore
        manager.isEnabled = original
    }
    
    func testFormattedCurrentSize() {
        let manager = SongCacheManager.shared
        let formatted = manager.formattedCurrentSize
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("KB") || formatted.contains("MB") || formatted.contains("GB"))
    }
    
    func testCacheDirectoryExists() {
        let manager = SongCacheManager.shared
        XCTAssertTrue(FileManager.default.fileExists(atPath: manager.cacheDirectory.path))
    }
    
    func testDownloadingIdsSetManagement() {
        let manager = SongCacheManager.shared
        XCTAssertFalse(manager.isDownloading(id: "test_non_existent"))
        XCTAssertFalse(manager.downloadingIds.contains("test_non_existent"))
    }
    
    func testCachedIdsLookup() {
        let manager = SongCacheManager.shared
        let isCached = manager.isSongCached(id: "dummy_id")
        XCTAssertEqual(isCached, manager.cachedIds.contains("dummy_id"))
    }
    
    func testConcurrentQuerySafety() {
        let manager = SongCacheManager.shared
        DispatchQueue.concurrentPerform(iterations: 100) { i in
            _ = manager.isSongCached(id: "query_\(i)")
            _ = manager.isDownloading(id: "query_\(i)")
            _ = manager.formattedCurrentSize
        }
    }
    
    func testLyricsAndCoverCaching() {
        let manager = SongCacheManager.shared
        let testSongId = "test_song_cache_metadata"
        let testLyrics = "[00:01.00]Hello world\n[00:05.00]Second line"
        let dummyCoverData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]) // JPEG header bytes
        
        manager.saveCachedLyrics(forId: testSongId, lyrics: testLyrics)
        manager.saveCachedCover(forId: testSongId, data: dummyCoverData)
        manager.flushIOQueue()
        
        let loadedLyrics = manager.getCachedLyrics(forId: testSongId)
        XCTAssertEqual(loadedLyrics, testLyrics)
        
        let coverUrl = manager.getCachedCoverUrl(forId: testSongId)
        XCTAssertNotNil(coverUrl)
        if let coverUrl = coverUrl {
            XCTAssertTrue(FileManager.default.fileExists(atPath: coverUrl.path))
        }
        
        let song = Song(
            id: testSongId,
            title: "Test",
            artist: "Artist",
            album: "Album",
            coverUrl: URL(string: "https://remote.com/cover.jpg")
        )
        XCTAssertEqual(song.effectiveCoverUrl, coverUrl)
        
        // Clean up
        manager.removeSong(id: testSongId)
        manager.flushIOQueue()
        
        XCTAssertNil(manager.getCachedLyrics(forId: testSongId))
        XCTAssertNil(manager.getCachedCoverUrl(forId: testSongId))
    }
    
    func testCancelCachingStopsDownloading() {
        let manager = SongCacheManager.shared
        let testId = "cancel_test_id"
        
        manager.cancelCaching(songId: testId)
        XCTAssertFalse(manager.isDownloading(id: testId))
        XCTAssertFalse(manager.downloadingIds.contains(testId))
    }
    
    func testStartAutoCacheGuardsAndTriggers() {
        let manager = SongCacheManager.shared
        
        // 1. Local songs should not be cached via startAutoCache
        let localSong = Song(
            id: "local_track_1",
            title: "Local Track",
            artist: "Local Artist",
            album: "Local Album",
            source: .local,
            localPath: "/path/to/local.mp3"
        )
        manager.startAutoCache(for: localSong)
        XCTAssertFalse(manager.isDownloading(id: localSong.id))
        
        // 2. Disabled cache manager should not trigger auto-cache
        let originalEnabled = manager.isEnabled
        manager.isEnabled = false
        let remoteSong = Song(
            id: "remote_track_disabled",
            title: "Remote Track",
            artist: "Remote Artist",
            album: "Remote Album",
            source: .navidrome,
            remoteId: "remote_track_disabled"
        )
        manager.startAutoCache(for: remoteSong)
        XCTAssertFalse(manager.isDownloading(id: remoteSong.id))
        
        // Restore
        manager.isEnabled = originalEnabled
    }
}
