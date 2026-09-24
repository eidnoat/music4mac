import Foundation

public enum SongSource: String, Codable, Sendable {
    case local
    case navidrome
}

public struct Song: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public var title: String
    public var artist: String
    public var album: String
    public var albumArtist: String?
    public var genre: String?
    public var year: Int?
    public var trackNumber: Int?
    public var discNumber: Int?
    public var duration: TimeInterval
    public var bitrate: Int?
    public var sampleRate: Int?
    public var format: String?
    
    public var source: SongSource
    public var remoteId: String?
    public var coverUrl: URL?
    public var coverId: String?
    
    public var playCount: Int = 0
    public var lastPlayed: Date?
    public var lyrics: String?
    public var dateAdded: Date?
    
    public var dateAddedComparable: Date {
        dateAdded ?? .distantPast
    }
    
    public var lastPlayedComparable: Date {
        lastPlayed ?? .distantPast
    }
    
    public var effectiveCoverUrl: URL? {
        if let cached = SongCacheManager.shared.getCachedCoverUrl(forId: id) {
            return cached
        }
        if let coverUrl = coverUrl {
            return coverUrl
        }
        if let coverId = coverId ?? remoteId {
            return NavidromeClient.shared.getCoverArtUrl(id: coverId)
        }
        return nil
    }
    
    public init(
        id: String,
        title: String,
        artist: String,
        album: String,
        albumArtist: String? = nil,
        genre: String? = nil,
        year: Int? = nil,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        duration: TimeInterval = 0,
        bitrate: Int? = nil,
        sampleRate: Int? = nil,
        format: String? = nil,
        source: SongSource = .navidrome,
        remoteId: String? = nil,
        coverUrl: URL? = nil,
        coverId: String? = nil,
        playCount: Int = 0,
        lastPlayed: Date? = nil,
        lyrics: String? = nil,
        dateAdded: Date? = nil
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown Title" : title
        self.artist = artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown Artist" : artist
        self.album = album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown Album" : album
        self.albumArtist = albumArtist
        self.genre = genre
        self.year = year
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.duration = duration
        self.bitrate = bitrate
        self.sampleRate = sampleRate
        self.format = format
        self.source = source
        self.remoteId = remoteId
        self.coverUrl = coverUrl
        self.coverId = coverId
        self.playCount = playCount
        self.lastPlayed = lastPlayed
        self.lyrics = lyrics
        self.dateAdded = dateAdded
    }
    
    public var formattedDuration: String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    public var yearSortValue: Int {
        year ?? 0
    }
}
