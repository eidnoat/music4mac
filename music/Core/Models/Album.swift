import Foundation

public struct Album: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public var year: Int?
    public var coverUrl: URL?
    public var coverId: String?
    public var songCount: Int
    public var songs: [Song] = []
    
    public var effectiveCoverUrl: URL? {
        if let first = songs.first, let cached = SongCacheManager.shared.getCachedCoverUrl(forId: first.id) {
            return cached
        }
        return coverUrl
    }
    
    public init(
        id: String,
        title: String,
        artist: String,
        year: Int? = nil,
        coverUrl: URL? = nil,
        coverId: String? = nil,
        songCount: Int = 0,
        songs: [Song] = []
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.year = year
        self.coverUrl = coverUrl
        self.coverId = coverId
        self.songCount = songCount
        self.songs = songs
    }
}

public struct Artist: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public var albumCount: Int = 0
    public var songCount: Int = 0
    public var coverUrl: URL?
    public var songs: [Song] = []
    
    public init(
        id: String,
        name: String,
        albumCount: Int = 0,
        songCount: Int = 0,
        coverUrl: URL? = nil,
        songs: [Song] = []
    ) {
        self.id = id
        self.name = name
        self.albumCount = albumCount
        self.songCount = songCount
        self.coverUrl = coverUrl
        self.songs = songs
    }
}
