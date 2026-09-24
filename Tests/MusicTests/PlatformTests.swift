import XCTest
import SwiftUI
@testable import music

final class PlatformTests: XCTestCase {
    func testPlatformColorAndTheme() {
        XCTAssertNotNil(Color.appleMusicRed)
        XCTAssertNotNil(Color.platformWindowBackground)
    }
    
    func testCoverImageCacheLimits() {
        let cache = CoverImageCache.shared
        XCTAssertNotNil(cache)
        // Ensure cache operations don't crash
        cache.clear()
    }
    
    func testNowPlayingManagerSetup() {
        let nowPlaying = NowPlayingManager.shared
        XCTAssertNotNil(nowPlaying)
        nowPlaying.updateNowPlaying(song: nil, playbackRate: 0, currentTime: 0)
    }
}
