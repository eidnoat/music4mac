import Foundation

public enum SongSortOption: String, CaseIterable, Identifiable, Codable {
    case title
    case artist
    case album
    case dateAdded
    case playCount
    case duration
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .title: return "Title"
        case .artist: return "Artist"
        case .album: return "Album"
        case .dateAdded: return "Date Added"
        case .playCount: return "Plays"
        case .duration: return "Duration"
        }
    }
    
    public func comparator(ascending: Bool) -> (Song, Song) -> Bool {
        return { a, b in
            let result: ComparisonResult
            switch self {
            case .title:
                result = a.title.localizedStandardCompare(b.title)
            case .artist:
                result = a.artist.localizedStandardCompare(b.artist)
            case .album:
                result = a.album.localizedStandardCompare(b.album)
            case .dateAdded:
                result = a.dateAddedComparable.compare(b.dateAddedComparable)
            case .playCount:
                if a.playCount < b.playCount {
                    result = .orderedAscending
                } else if a.playCount > b.playCount {
                    result = .orderedDescending
                } else {
                    result = .orderedSame
                }
            case .duration:
                if a.duration < b.duration {
                    result = .orderedAscending
                } else if a.duration > b.duration {
                    result = .orderedDescending
                } else {
                    result = .orderedSame
                }
            }
            
            if result == .orderedSame {
                return a.title.localizedStandardCompare(b.title) == .orderedAscending
            }
            return ascending ? (result == .orderedAscending) : (result == .orderedDescending)
        }
    }
}

public enum AlbumSortOption: String, CaseIterable, Identifiable, Codable {
    case title
    case artist
    case year
    case songCount
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .title: return "Title"
        case .artist: return "Artist"
        case .year: return "Year"
        case .songCount: return "Tracks"
        }
    }
    
    public func comparator(ascending: Bool) -> (Album, Album) -> Bool {
        return { a, b in
            let result: ComparisonResult
            switch self {
            case .title:
                result = a.title.localizedStandardCompare(b.title)
            case .artist:
                result = a.artist.localizedStandardCompare(b.artist)
            case .year:
                let yA = a.year ?? 0
                let yB = b.year ?? 0
                if yA < yB {
                    result = .orderedAscending
                } else if yA > yB {
                    result = .orderedDescending
                } else {
                    result = .orderedSame
                }
            case .songCount:
                if a.songs.count < b.songs.count {
                    result = .orderedAscending
                } else if a.songs.count > b.songs.count {
                    result = .orderedDescending
                } else {
                    result = .orderedSame
                }
            }
            
            if result == .orderedSame {
                return a.title.localizedStandardCompare(b.title) == .orderedAscending
            }
            return ascending ? (result == .orderedAscending) : (result == .orderedDescending)
        }
    }
}
