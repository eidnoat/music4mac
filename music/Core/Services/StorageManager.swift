import Foundation
import Combine

public final class StorageManager: ObservableObject {
    public static let shared = StorageManager()
    
    private let libraryFileName = "library_cache.json"
    private let historyFileName = "history.json"
    
    private let ioQueue = DispatchQueue(label: "com.music.storage.io", qos: .utility)
    private var pendingSaveWorkItem: DispatchWorkItem?
    
    @Published public var songs: [Song] = []
    @Published public var albums: [Album] = []
    @Published public var artists: [Artist] = []
    @Published public var history: [String] = [] // Song IDs ordered by recent play
    @Published public var dataVersion: UUID = UUID()
    
    public let baseDir: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("music", isDirectory: true)
        let oldDir = appSupport.appendingPathComponent("Sylvakru", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            if FileManager.default.fileExists(atPath: oldDir.path) {
                try? FileManager.default.moveItem(at: oldDir, to: dir)
            } else {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
        self.baseDir = dir
        loadAll()
    }
    
    public func loadAll() {
        loadLibrary()
        loadHistory()
    }
    
    // MARK: - Library
    
    private func loadLibrary() {
        let url = baseDir.appendingPathComponent(libraryFileName)
        guard let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Song].self, from: data) else {
            return
        }
        self.songs = list
        updateDerivedCollections()
    }
    
    public func updateDerivedCollections() {
        var albumDict: [String: [Song]] = [:]
        var artistDict: [String: [Song]] = [:]
        var artistAlbums: [String: Set<String>] = [:]
        
        for song in songs {
            let albumKey = "\(song.album)-\(song.artist)"
            albumDict[albumKey, default: []].append(song)
            artistDict[song.artist, default: []].append(song)
            artistAlbums[song.artist, default: []].insert(song.album)
        }
        
        self.albums = albumDict.map { (key, albumSongs) in
            let first = albumSongs[0]
            return Album(
                id: key,
                title: first.album,
                artist: first.albumArtist ?? first.artist,
                year: first.year,
                coverUrl: first.coverUrl,
                coverId: first.coverId,
                songCount: albumSongs.count,
                songs: albumSongs.sorted(by: { ($0.trackNumber ?? 0) < ($1.trackNumber ?? 0) })
            )
        }.sorted(by: { $0.title.localizedStandardCompare($1.title) == .orderedAscending })
        
        self.artists = artistDict.map { (name, artistSongs) in
            Artist(
                id: name,
                name: name,
                albumCount: artistAlbums[name]?.count ?? 0,
                songCount: artistSongs.count,
                songs: artistSongs.sorted(by: { $0.title.localizedStandardCompare($1.title) == .orderedAscending })
            )
        }.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
        
        if let currentAlbum = NavigationCoordinator.shared.selectedAlbum,
           let updated = self.albums.first(where: { $0.id == currentAlbum.id }) {
            NavigationCoordinator.shared.selectedAlbum = updated
        }
        if let currentArtist = NavigationCoordinator.shared.selectedArtist,
           let updated = self.artists.first(where: { $0.id == currentArtist.id }) {
            NavigationCoordinator.shared.selectedArtist = updated
        }
    }
    
    public func saveLibrary() {
        let songsSnapshot = self.songs
        let url = baseDir.appendingPathComponent(libraryFileName)
        
        pendingSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            if let data = try? JSONEncoder().encode(songsSnapshot) {
                try? data.write(to: url, options: .atomic)
            }
        }
        pendingSaveWorkItem = workItem
        ioQueue.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
    
    public func flushPendingSaves() {
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil
        let songsSnapshot = self.songs
        let url = baseDir.appendingPathComponent(libraryFileName)
        ioQueue.sync {
            if let data = try? JSONEncoder().encode(songsSnapshot) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
    
    public func upsertSongs(_ newSongs: [Song]) {
        assert(Thread.isMainThread, "StorageManager must be mutated on the main thread")
        var dict: [String: Song] = Dictionary(minimumCapacity: songs.count + newSongs.count)
        for song in songs {
            dict[song.id] = song
        }
        for song in newSongs {
            if let existing = dict[song.id] {
                var merged = song
                if let existingLast = existing.lastPlayed, let newLast = song.lastPlayed {
                    merged.lastPlayed = max(existingLast, newLast)
                } else {
                    merged.lastPlayed = song.lastPlayed ?? existing.lastPlayed
                }
                merged.playCount = max(existing.playCount, song.playCount)
                if merged.lyrics == nil {
                    merged.lyrics = existing.lyrics
                }
                dict[song.id] = merged
            } else {
                dict[song.id] = song
            }
        }
        self.songs = Array(dict.values).sorted(by: { $0.title.localizedStandardCompare($1.title) == .orderedAscending })
        self.dataVersion = UUID()
        updateDerivedCollections()
        saveLibrary()
    }
    
    public func removeSongs(where predicate: (Song) -> Bool) {
        assert(Thread.isMainThread, "StorageManager must be mutated on the main thread")
        songs.removeAll(where: predicate)
        self.dataVersion = UUID()
        updateDerivedCollections()
        saveLibrary()
    }
    
    // MARK: - History & Play Count
    
    private func loadHistory() {
        let url = baseDir.appendingPathComponent(historyFileName)
        if let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([String].self, from: data) {
            self.history = list
        } else {
            let sorted = songs
                .filter { $0.lastPlayed != nil }
                .sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
                .map { $0.id }
            if !sorted.isEmpty {
                self.history = sorted
            }
        }
    }
    
    public func recordPlayStart(song: Song) {
        assert(Thread.isMainThread, "StorageManager must be mutated on the main thread")
        history.removeAll(where: { $0 == song.id })
        history.insert(song.id, at: 0)
        if history.count > 500 {
            history.removeLast()
        }

        // Only bump lastPlayed for tracks that are already in the library;
        // playing an unknown track must not inject it into the user's library.
        if let idx = songs.firstIndex(where: { $0.id == song.id }) {
            songs[idx].lastPlayed = Date()
        }
        
        let historySnapshot = self.history
        let url = baseDir.appendingPathComponent(historyFileName)
        ioQueue.async {
            if let data = try? JSONEncoder().encode(historySnapshot) {
                try? data.write(to: url, options: .atomic)
            }
        }
        saveLibrary()
    }
    
    public func incrementPlayCount(songId: String) {
        assert(Thread.isMainThread, "StorageManager must be mutated on the main thread")
        if let idx = songs.firstIndex(where: { $0.id == songId }) {
            songs[idx].playCount += 1
            saveLibrary()
        }
    }
    
    public func recordPlay(song: Song) {
        recordPlayStart(song: song)
    }
}
