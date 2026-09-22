import XCTest
@testable import music

final class LyricsServiceTests: XCTestCase {
    func testStandardLrcParsing() {
        let lrc = """
        [00:01.00]Hello world
        [00:05.50]Second line of song
        """
        
        let parsed = LyricsService.shared.parse(lrcContent: lrc, songDuration: 10.0)
        XCTAssertEqual(parsed.lines.count, 2)
        XCTAssertEqual(parsed.lines[0].text, "Hello world")
        XCTAssertEqual(parsed.lines[0].start, 1.0)
        XCTAssertEqual(parsed.lines[1].text, "Second line of song")
        XCTAssertEqual(parsed.lines[1].start, 5.5)
        XCTAssertFalse(parsed.isKaraoke)
    }
    
    func testKaraokeTokenParsing() {
        let lrc = """
        [00:02.00]Hello [00:02.50]beautiful [00:03.00]world
        """
        
        let parsed = LyricsService.shared.parse(lrcContent: lrc, songDuration: 5.0)
        XCTAssertTrue(parsed.isKaraoke)
        XCTAssertEqual(parsed.lines.count, 1)
        XCTAssertEqual(parsed.lines[0].tokens.count, 3)
        XCTAssertEqual(parsed.lines[0].tokens[0].text, "Hello ")
        XCTAssertEqual(parsed.lines[0].tokens[0].start, 2.0)
        XCTAssertEqual(parsed.lines[0].tokens[0].end, 2.5)
    }
    
    func testTranslationLineDetection() {
        let lrc = """
        [00:01.00]Bonjour le monde
        [00:01.00]Hello, world
        """
        
        let parsed = LyricsService.shared.parse(lrcContent: lrc, songDuration: 5.0)
        XCTAssertEqual(parsed.lines.count, 1)
        XCTAssertEqual(parsed.lines[0].text, "Bonjour le monde")
        XCTAssertEqual(parsed.lines[0].translates.count, 1)
        XCTAssertEqual(parsed.lines[0].translates[0], "Hello, world")
    }
    
    func testActiveIndexMatching() {
        let lrc = """
        [00:02.00]Line 1
        [00:05.00]Line 2
        [00:08.00]Line 3
        """
        let parsed = LyricsService.shared.parse(lrcContent: lrc)
        
        XCTAssertEqual(LyricsService.shared.activeLineIndex(in: parsed.lines, position: 1.0), -1)
        XCTAssertEqual(LyricsService.shared.activeLineIndex(in: parsed.lines, position: 3.0), 0)
        XCTAssertEqual(LyricsService.shared.activeLineIndex(in: parsed.lines, position: 6.0), 1)
        XCTAssertEqual(LyricsService.shared.activeLineIndex(in: parsed.lines, position: 9.0), 2)
    }
    
    func testMultiTimestampLineParsing() {
        let lrc = """
        [00:02.00][00:10.00]Repeated Chorus Line
        """
        let parsed = LyricsService.shared.parse(lrcContent: lrc)
        XCTAssertEqual(parsed.lines.count, 2)
        XCTAssertEqual(parsed.lines[0].start, 2.0)
        XCTAssertEqual(parsed.lines[0].text, "Repeated Chorus Line")
        XCTAssertEqual(parsed.lines[1].start, 10.0)
        XCTAssertEqual(parsed.lines[1].text, "Repeated Chorus Line")
    }
    
    func testOffsetParsing() {
        let lrc = """
        [offset:500]
        [00:02.00]Line with offset
        """
        let parsed = LyricsService.shared.parse(lrcContent: lrc)
        XCTAssertEqual(parsed.offset, 0.5)
        XCTAssertEqual(parsed.lines.count, 1)
        XCTAssertEqual(parsed.lines[0].start, 1.5) // 2.0 - 0.5 = 1.5
    }
    
    func testSingleDigitMinuteParsing() {
        let lrc = """
        [1:05.20]Single digit minute
        """
        let parsed = LyricsService.shared.parse(lrcContent: lrc)
        XCTAssertEqual(parsed.lines.count, 1)
        XCTAssertEqual(parsed.lines[0].start, 65.2)
        XCTAssertEqual(parsed.lines[0].text, "Single digit minute")
    }
    
    func testOutOfOrderLrcLinesSorting() {
        let lrc = """
        [00:10.00]Third line
        [00:02.00]First line
        [00:06.00]Second line
        """
        let parsed = LyricsService.shared.parse(lrcContent: lrc)
        XCTAssertEqual(parsed.lines.count, 3)
        XCTAssertEqual(parsed.lines[0].text, "First line")
        XCTAssertEqual(parsed.lines[0].start, 2.0)
        XCTAssertEqual(parsed.lines[1].text, "Second line")
        XCTAssertEqual(parsed.lines[1].start, 6.0)
        XCTAssertEqual(parsed.lines[2].text, "Third line")
        XCTAssertEqual(parsed.lines[2].start, 10.0)
    }
}
