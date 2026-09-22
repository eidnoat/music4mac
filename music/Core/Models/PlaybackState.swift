import Foundation

public enum PlayMode: Int, Codable, CaseIterable {
    case sequence = 0
    case repeatOne = 1
    case repeatAll = 2
    case shuffle = 3
    
    public var title: String {
        switch self {
        case .sequence: return "Sequential"
        case .repeatOne: return "Repeat One"
        case .repeatAll: return "Repeat All"
        case .shuffle: return "Shuffle"
        }
    }
    
    public var iconName: String {
        switch self {
        case .sequence: return "repeat"
        case .repeatOne: return "repeat.1"
        case .repeatAll: return "repeat"
        case .shuffle: return "shuffle"
        }
    }
}

public enum PlaybackStatus: Equatable {
    case stopped
    case playing
    case paused
    case loading
    case error(String)
}
