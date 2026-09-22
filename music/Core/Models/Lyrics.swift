import Foundation

public struct LyricToken: Identifiable, Equatable, Codable {
    public var id: UUID = UUID()
    public let start: TimeInterval   // Seconds
    public var end: TimeInterval?   // Seconds
    public let text: String
    
    public init(start: TimeInterval, text: String, end: TimeInterval? = nil) {
        self.start = start
        self.text = text
        self.end = end
    }
    
    enum CodingKeys: String, CodingKey {
        case start, end, text
    }
}

public struct LyricLine: Identifiable, Equatable, Codable {
    public var id: UUID = UUID()
    public let start: TimeInterval
    public var end: TimeInterval?
    public let text: String
    public var tokens: [LyricToken]
    public var translates: [String]
    
    public init(start: TimeInterval, end: TimeInterval? = nil, text: String, tokens: [LyricToken] = [], translates: [String] = []) {
        self.start = start
        self.end = end
        self.text = text
        self.tokens = tokens
        self.translates = translates
    }
    
    enum CodingKeys: String, CodingKey {
        case start, end, text, tokens, translates
    }
}

public struct ParsedLyrics: Equatable {
    public var isKaraoke: Bool = false
    public var offset: TimeInterval = 0  // In seconds (from LRC [offset: +/- ms])
    public var lines: [LyricLine] = []
    
    public init(isKaraoke: Bool = false, offset: TimeInterval = 0, lines: [LyricLine] = []) {
        self.isKaraoke = isKaraoke
        self.offset = offset
        self.lines = lines
    }
}
