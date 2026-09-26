import Foundation
import Combine

public final class PlayQueueManager: ObservableObject {
    public static let shared = PlayQueueManager()
    
    @Published public var queue: [Song] = []
    @Published public var currentIndex: Int = -1
    @Published public var playMode: PlayMode = .sequence {
        didSet {
            handlePlayModeChange()
        }
    }
    
    public var isReorganizingQueue = false
    private var originalQueue: [Song] = []
    private let modeStorageKey = "music.playback.mode"
    
    public var currentSong: Song? {
        guard currentIndex >= 0 && currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }
    
    private init() {
        let rawMode = UserDefaults.standard.object(forKey: modeStorageKey) != nil
            ? UserDefaults.standard.integer(forKey: modeStorageKey)
            : UserDefaults.standard.integer(forKey: "sylvakru.playback.mode")
        self.playMode = PlayMode(rawValue: rawMode) ?? .sequence
    }
    
    public func setQueue(_ songs: [Song], startAt index: Int = 0) {
        self.originalQueue = songs
        if playMode == .shuffle {
            var shuffled = songs
            if index >= 0 && index < songs.count {
                let startSong = songs[index]
                shuffled.remove(at: index)
                shuffled.shuffle()
                shuffled.insert(startSong, at: 0)
                self.queue = shuffled
                self.currentIndex = 0
            } else {
                shuffled.shuffle()
                self.queue = shuffled
                self.currentIndex = 0
            }
        } else {
            self.queue = songs
            self.currentIndex = max(0, min(index, songs.count - 1))
        }
    }
    
    public func insertNext(_ song: Song) {
        if let existingIdx = queue.firstIndex(where: { $0.id == song.id }) {
            if existingIdx == currentIndex { return }
            queue.remove(at: existingIdx)
            if existingIdx < currentIndex {
                queue.insert(song, at: currentIndex)
                currentIndex -= 1
            } else {
                queue.insert(song, at: currentIndex + 1)
            }
        } else {
            if queue.isEmpty {
                queue.append(song)
                currentIndex = 0
            } else {
                queue.insert(song, at: currentIndex + 1)
            }
        }
    }
    
    public func append(_ song: Song) {
        if let existingIdx = queue.firstIndex(where: { $0.id == song.id }) {
            if existingIdx == currentIndex { return }
            queue.remove(at: existingIdx)
            if existingIdx < currentIndex {
                currentIndex -= 1
            }
            queue.append(song)
        } else {
            queue.append(song)
            if queue.count == 1 {
                currentIndex = 0
            }
        }
    }
    
    public func remove(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        queue.remove(at: index)
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex {
            if currentIndex >= queue.count {
                currentIndex = queue.count - 1
            }
        }
    }
    
    public func remove(atOffsets offsets: IndexSet) {
        let currentId = currentSong?.id
        var newQueue = queue
        for index in offsets.sorted(by: >) {
            guard index >= 0 && index < newQueue.count else { continue }
            newQueue.remove(at: index)
        }
        self.queue = newQueue
        if let currentId = currentId, let newIdx = newQueue.firstIndex(where: { $0.id == currentId }) {
            self.currentIndex = newIdx
        } else if newQueue.isEmpty {
            self.currentIndex = -1
        } else if currentIndex >= newQueue.count {
            self.currentIndex = newQueue.count - 1
        }
    }
    
    public func move(from source: IndexSet, to destination: Int) {
        let currentSongId = currentSong?.id
        queue.move(fromOffsets: source, toOffset: destination)
        if let currentSongId = currentSongId,
           let newIndex = queue.firstIndex(where: { $0.id == currentSongId }) {
            currentIndex = newIndex
        }
    }
    
    public func nextSong() -> Song? {
        guard !queue.isEmpty else { return nil }
        
        switch playMode {
        case .repeatOne:
            return currentSong
        case .repeatAll:
            currentIndex = (currentIndex + 1) % queue.count
            return currentSong
        case .sequence:
            if currentIndex + 1 < queue.count {
                currentIndex += 1
                return currentSong
            }
            return nil
        case .shuffle:
            if currentIndex + 1 < queue.count {
                currentIndex += 1
                return currentSong
            } else {
                // Reshuffle when reaching end
                var shuffled = queue
                shuffled.shuffle()
                queue = shuffled
                currentIndex = 0
                return currentSong
            }
        }
    }
    
    public func previousSong() -> Song? {
        guard !queue.isEmpty else { return nil }
        
        switch playMode {
        case .repeatOne:
            return currentSong
        case .repeatAll, .shuffle:
            currentIndex = (currentIndex - 1 + queue.count) % queue.count
            return currentSong
        case .sequence:
            if currentIndex - 1 >= 0 {
                currentIndex -= 1
                return currentSong
            }
            return nil
        }
    }
    
    public func togglePlayMode() {
        let all = PlayMode.allCases
        let nextRaw = (playMode.rawValue + 1) % all.count
        self.playMode = PlayMode(rawValue: nextRaw) ?? .sequence
    }
    
    public var isShuffleEnabled: Bool {
        get { playMode == .shuffle }
        set { playMode = newValue ? .shuffle : .sequence }
    }
    
    public func toggleShuffle() {
        playMode = (playMode == .shuffle) ? .sequence : .shuffle
    }
    
    public func cycleRepeatMode() {
        switch playMode {
        case .sequence:
            playMode = .repeatAll
        case .repeatAll:
            playMode = .repeatOne
        case .repeatOne, .shuffle:
            playMode = .sequence
        }
    }
    
    public func playQueueItem(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        self.currentIndex = index
    }
    
    private func handlePlayModeChange() {
        UserDefaults.standard.set(playMode.rawValue, forKey: modeStorageKey)
        guard let current = currentSong else { return }

        isReorganizingQueue = true
        defer { isReorganizingQueue = false }

        if playMode == .shuffle {
            // Snapshot the current logical order so it can be restored exactly on exit,
            // instead of trusting an `originalQueue` that may have gone stale after appends.
            originalQueue = queue
            var newQueue = queue
            if let idx = newQueue.firstIndex(where: { $0.id == current.id }) {
                newQueue.remove(at: idx)
            }
            newQueue.shuffle()
            newQueue.insert(current, at: 0)
            self.queue = newQueue
            self.currentIndex = 0
        } else {
            // Restore the pre-shuffle order with a graceful fallback instead of silently no-oping.
            let restored = originalQueue.isEmpty ? queue : originalQueue
            if let idx = restored.firstIndex(where: { $0.id == current.id }) {
                self.queue = restored
                self.currentIndex = idx
            } else if !queue.isEmpty {
                self.queue = restored
                self.queue.insert(current, at: 0)
                self.currentIndex = 0
            }
        }
    }
}
