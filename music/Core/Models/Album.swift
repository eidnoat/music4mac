import Foundation

public struct Album: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public var year: Int?
    public var coverUrl: URL?
    public var coverId: String?
    public var songCount: Int
    /// Referenced by id rather than holding full `[Song]` copies, so the derived
    /// collections stay lightweight (no N× duplication of song structs in memory).
    public var songIds: [String] = []

    public var effectiveCoverUrl: URL? {
        if let firstId = songIds.first, let cached = SongCacheManager.shared.getCachedCoverUrl(forId: firstId) {
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
        songIds: [String] = []
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.year = year
        self.coverUrl = coverUrl
        self.coverId = coverId
        self.songCount = songCount
        self.songIds = songIds
    }
}

public struct Artist: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public var albumCount: Int = 0
    public var songCount: Int = 0
    public var coverUrl: URL?
    /// Referenced by id rather than holding full `[Song]` copies (see `Album.songIds`).
    public var songIds: [String] = []

    public init(
        id: String,
        name: String,
        albumCount: Int = 0,
        songCount: Int = 0,
        coverUrl: URL? = nil,
        songIds: [String] = []
    ) {
        self.id = id
        self.name = name
        self.albumCount = albumCount
        self.songCount = songCount
        self.coverUrl = coverUrl
        self.songIds = songIds
    }
}
