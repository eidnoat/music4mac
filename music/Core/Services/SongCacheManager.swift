import Foundation
import Combine

public struct CachedTrackInfo: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let fileName: String
    public let fileSize: Int64
    public var lastAccessed: Date
}

public final class SongCacheManager: ObservableObject, @unchecked Sendable {
    public static let shared = SongCacheManager()
    
    private let lock = NSLock()
    private let ioQueue = DispatchQueue(label: "com.music.cache.io", qos: .utility)
    private let enabledKey = "music.cache.enabled"
    private let maxSizeKey = "music.cache.max_size_gb"
    private let indexFileName = "audio_cache_index.json"
    private let cacheFolder = "AudioCache"
    
    private let downloadCoordinator = DownloadCoordinator()
    private let downloadSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 120.0
        config.urlCache = nil // Avoid polluting global URLCache with large media/artwork downloads
        return URLSession(configuration: config)
    }()
    
    private var activeDownloadTasks: [String: Task<Void, Never>] = [:]
    private let downloadLimiter = DownloadLimiter(limit: 3)
    
    public let baseDir: URL
    public let cacheDirectory: URL
    private let indexFileUrl: URL
    
    @Published public var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
        }
    }
    
    @Published public var maxSizeGB: Int {
        didSet {
            let clamped = max(1, min(20, maxSizeGB))
            if clamped != maxSizeGB {
                maxSizeGB = clamped
            }
            UserDefaults.standard.set(maxSizeGB, forKey: maxSizeKey)
            evictOldestIfNeeded()
        }
    }
    
    @Published public var currentCacheSizeBytes: Int64 = 0
    @Published public var cachedTrackCount: Int = 0
    @Published public var cachedIds: Set<String> = []
    @Published public var downloadingIds: Set<String> = []
    @Published public var downloadProgress: [String: Double] = [:]
    
    private var cachedTracks: [String: CachedTrackInfo] = [:]
    private var downloadingSongIds: Set<String> = []
    private var cachedCoverSafeIds: Set<String> = []
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let base = appSupport.appendingPathComponent("music", isDirectory: true)
        let cache = base.appendingPathComponent("AudioCache", isDirectory: true)
        
        self.baseDir = base
        self.cacheDirectory = cache
        self.indexFileUrl = base.appendingPathComponent("audio_cache_index.json")
        
        if !FileManager.default.fileExists(atPath: cache.path) {
            try? FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        }
        
        let savedEnabled = (UserDefaults.standard.object(forKey: enabledKey) as? Bool)
            ?? (UserDefaults.standard.object(forKey: "sylvakru.cache.enabled") as? Bool)
            ?? true
        let savedSize = (UserDefaults.standard.object(forKey: maxSizeKey) as? Int)
            ?? (UserDefaults.standard.object(forKey: "sylvakru.cache.max_size_gb") as? Int)
            ?? 5
        
        self.isEnabled = savedEnabled
        self.maxSizeGB = max(1, min(20, savedSize))
        
        loadIndex()
    }
    
    // MARK: - Index Management
    
    private func loadIndex() {
        if let files = try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path) {
            var coverIds = Set<String>()
            for file in files where file.hasSuffix("_cover.jpg") {
                let safeId = String(file.dropLast("_cover.jpg".count))
                coverIds.insert(safeId)
            }
            self.cachedCoverSafeIds = coverIds
        } else {
            self.cachedCoverSafeIds = []
        }
        
        guard let data = try? Data(contentsOf: indexFileUrl),
              let list = try? JSONDecoder().decode([CachedTrackInfo].self, from: data) else {
            self.cachedTracks = [:]
            self.cachedTrackCount = 0
            self.currentCacheSizeBytes = 0
            return
        }
        
        var dict: [String: CachedTrackInfo] = [:]
        var total: Int64 = 0
        for item in list {
            let filePath = cacheDirectory.appendingPathComponent(item.fileName).path
            if FileManager.default.fileExists(atPath: filePath) {
                dict[item.id] = item
                total += item.fileSize
            }
        }
        self.cachedTracks = dict
        self.cachedTrackCount = dict.count
        self.cachedIds = Set(dict.keys)
        self.currentCacheSizeBytes = total
    }
    
    private func scheduleSaveIndex(_ list: [CachedTrackInfo]) {
        ioQueue.async { [indexFileUrl] in
            if let data = try? JSONEncoder().encode(list) {
                try? data.write(to: indexFileUrl, options: .atomic)
            }
        }
    }
    
    // MARK: - Query & Access
    
    public func isSongCached(id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard isEnabled else { return false }
        return cachedTracks[id] != nil
    }
    
    public func isDownloading(id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return downloadingSongIds.contains(id)
    }
    
    public func getCachedFileUrl(for song: Song) -> URL? {
        getCachedFileUrl(forId: song.id)
    }
    
    public func getCachedFileUrl(forId id: String) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        guard isEnabled else { return nil }
        guard let track = cachedTracks[id] else { return nil }
        let url = cacheDirectory.appendingPathComponent(track.fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }
    
    public func recordAccess(songId: String) {
        lock.lock()
        guard isEnabled, var track = cachedTracks[songId] else {
            lock.unlock()
            return
        }
        track.lastAccessed = Date()
        cachedTracks[songId] = track
        let snapshot = Array(cachedTracks.values)
        lock.unlock()
        
        scheduleSaveIndex(snapshot)
    }
    
    // MARK: - Artwork & Lyrics Cache
    
    public func safeIdentifier(for id: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/:?*\"<>|\\")
        return id.components(separatedBy: invalidChars).joined(separator: "_")
    }
    
    public func getCachedCoverUrl(forId id: String) -> URL? {
        let safeId = safeIdentifier(for: id)
        lock.lock()
        let hasCover = cachedCoverSafeIds.contains(safeId)
        lock.unlock()
        if hasCover {
            return cacheDirectory.appendingPathComponent("\(safeId)_cover.jpg")
        }
        return nil
    }
    
    public func getCachedLyrics(forId id: String) -> String? {
        let safeId = safeIdentifier(for: id)
        let lyricsUrl = cacheDirectory.appendingPathComponent("\(safeId).lrc")
        guard FileManager.default.fileExists(atPath: lyricsUrl.path),
              let content = try? String(contentsOf: lyricsUrl, encoding: .utf8) else {
            return nil
        }
        return content
    }
    
    public func saveCachedLyrics(forId id: String, lyrics: String) {
        guard !lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let safeId = safeIdentifier(for: id)
        let lyricsUrl = cacheDirectory.appendingPathComponent("\(safeId).lrc")
        ioQueue.async {
            try? lyrics.write(to: lyricsUrl, atomically: true, encoding: .utf8)
        }
    }
    
    public func saveCachedCover(forId id: String, data: Data) {
        guard !data.isEmpty else { return }
        let safeId = safeIdentifier(for: id)
        let coverUrl = cacheDirectory.appendingPathComponent("\(safeId)_cover.jpg")
        lock.lock()
        cachedCoverSafeIds.insert(safeId)
        lock.unlock()
        ioQueue.async {
            try? data.write(to: coverUrl, options: .atomic)
        }
    }
    
    public func startAutoCache(for song: Song) {
        enqueueDownload(for: song)
    }

    public func downloadSong(_ song: Song) {
        enqueueDownload(for: song)
    }

    private func enqueueDownload(for song: Song) {
        guard isEnabled else { return }
        guard let remoteId = song.remoteId, !remoteId.isEmpty else { return }
        guard !isSongCached(id: song.id) else { return }

        lock.lock()
        guard !downloadingSongIds.contains(song.id) else {
            lock.unlock()
            return
        }
        lock.unlock()

        let limiter = downloadLimiter
        let task: Task<Void, Never> = Task(priority: .utility) { [weak self] in
            // Gate concurrent downloads so batch operations don't open unbounded network streams.
            await limiter.acquire()
            guard let self else {
                await limiter.release()
                return
            }
            await self.cacheSong(song)
            await limiter.release()
        }

        lock.lock()
        activeDownloadTasks[song.id] = task
        lock.unlock()
    }
    
    public func cancelCaching(songId: String) {
        lock.lock()
        let task = activeDownloadTasks.removeValue(forKey: songId)
        downloadingSongIds.remove(songId)
        lock.unlock()
        
        task?.cancel()
        
        DispatchQueue.main.async { [weak self] in
            self?.downloadingIds.remove(songId)
            self?.downloadProgress.removeValue(forKey: songId)
        }
    }
    
    // MARK: - Cache & Download
    
    // MARK: - Synchronous Scoped Lock Helpers (Swift 6 Async Safe)
    
    private func beginCaching(song: Song) -> (canCache: Bool, streamUrl: URL?) {
        lock.lock()
        defer { lock.unlock() }
        guard isEnabled else { return (false, nil) }
        guard let remoteId = song.remoteId, !remoteId.isEmpty else { return (false, nil) }
        if cachedTracks[song.id] != nil {
            if var track = cachedTracks[song.id] {
                track.lastAccessed = Date()
                cachedTracks[song.id] = track
            }
            return (false, nil)
        }
        guard !downloadingSongIds.contains(song.id) else { return (false, nil) }
        guard let downloadUrl = NavidromeClient.shared.getDownloadUrl(songId: remoteId) ?? NavidromeClient.shared.getStreamUrl(songId: remoteId) else { return (false, nil) }
        downloadingSongIds.insert(song.id)
        return (true, downloadUrl)
    }
    
    private func endDownloading(songId: String) {
        lock.lock()
        defer { lock.unlock() }
        downloadingSongIds.remove(songId)
        activeDownloadTasks.removeValue(forKey: songId)
    }
    
    private func commitCachedTrack(song: Song, fileName: String, fileSize: Int64) -> (updatedSize: Int64, updatedCount: Int, snapshot: [CachedTrackInfo]) {
        lock.lock()
        defer { lock.unlock() }
        let info = CachedTrackInfo(
            id: song.id,
            title: song.title,
            artist: song.artist,
            fileName: fileName,
            fileSize: fileSize,
            lastAccessed: Date()
        )
        cachedTracks[song.id] = info
        let total = cachedTracks.values.reduce(Int64(0)) { $0 + $1.fileSize }
        return (total, cachedTracks.count, Array(cachedTracks.values))
    }
    
    // MARK: - Cache & Download
    
    public func cacheSong(_ song: Song) async {
        let (canCache, streamUrl) = beginCaching(song: song)
        guard canCache, let streamUrl = streamUrl else { return }
        
        let songId = song.id
        let safeId = safeIdentifier(for: songId)
        
        DispatchQueue.main.async { [weak self] in
            self?.downloadingIds.insert(songId)
            self?.downloadProgress[songId] = 0.05
        }
        
        defer {
            endDownloading(songId: songId)
            DispatchQueue.main.async { [weak self] in
                self?.downloadingIds.remove(songId)
                self?.downloadProgress.removeValue(forKey: songId)
            }
        }
        
        let expectedBytes: Int64
        if let bitrate = song.bitrate, bitrate > 0, song.duration > 0 {
            expectedBytes = Int64(Double(bitrate) * 1000.0 / 8.0 * song.duration)
        } else if song.duration > 0 {
            expectedBytes = Int64(320.0 * 1000.0 / 8.0 * song.duration)
        } else {
            expectedBytes = 10 * 1024 * 1024
        }
        
        do {
            guard !Task.isCancelled else { return }
            let (tempUrl, response) = try await downloadCoordinator.download(
                from: streamUrl,
                songId: songId,
                expectedBytes: expectedBytes,
                onProgress: { [weak self] progress in
                    DispatchQueue.main.async {
                        self?.downloadProgress[songId] = progress
                    }
                }
            )
            guard !Task.isCancelled else {
                try? FileManager.default.removeItem(at: tempUrl)
                return
            }
            
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                try? FileManager.default.removeItem(at: tempUrl)
                return
            }
            
            var ext = song.format?.lowercased() ?? "mp3"
            if ext.isEmpty { ext = "mp3" }
            let fileName = "\(safeId).\(ext)"
            let destUrl = cacheDirectory.appendingPathComponent(fileName)
            
            try? FileManager.default.removeItem(at: destUrl)
            try FileManager.default.moveItem(at: tempUrl, to: destUrl)
            
            let attrs = try? FileManager.default.attributesOfItem(atPath: destUrl.path)
            let fileSize = (attrs?[.size] as? Int64) ?? 0
            
            let (updatedSize, updatedCount, snapshot) = commitCachedTrack(
                song: song,
                fileName: fileName,
                fileSize: fileSize
            )
            
            scheduleSaveIndex(snapshot)
            
            // Immediately publish cached state to UI so the cached icon appears without waiting for cover/lyrics!
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentCacheSizeBytes = updatedSize
                self.cachedTrackCount = updatedCount
                self.cachedIds.insert(songId)
                self.downloadingIds.remove(songId)
            }
            
            evictOldestIfNeeded()
            
            // Also cache cover artwork in background
            if let coverUrl = song.coverUrl ?? NavidromeClient.shared.getCoverArtUrl(id: song.coverId ?? song.remoteId) {
                if let (coverData, _) = try? await downloadSession.data(from: coverUrl), !coverData.isEmpty {
                    let coverDest = cacheDirectory.appendingPathComponent("\(safeId)_cover.jpg")
                    try? coverData.write(to: coverDest, options: .atomic)
                    self.addCachedCoverSafeId(safeId)
                }
            }
            
            // Also cache lyrics in background
            if let embedded = song.lyrics, !embedded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let lyricsDest = cacheDirectory.appendingPathComponent("\(safeId).lrc")
                try? embedded.write(to: lyricsDest, atomically: true, encoding: .utf8)
            } else if let remoteId = song.remoteId {
                if let lrc = try? await NavidromeClient.shared.getLyrics(songId: remoteId),
                   !lrc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let lyricsDest = cacheDirectory.appendingPathComponent("\(safeId).lrc")
                    try? lrc.write(to: lyricsDest, atomically: true, encoding: .utf8)
                }
            }
        } catch {
            print("[SongCacheManager] Failed to cache song: \(song.title), error: \(error)")
        }
    }
    
    private func addCachedCoverSafeId(_ safeId: String) {
        lock.lock()
        defer { lock.unlock() }
        cachedCoverSafeIds.insert(safeId)
    }
    
    // MARK: - Eviction & Removal
    
    public func evictOldestIfNeeded() {
        lock.lock()
        let currentTotal = cachedTracks.values.reduce(Int64(0)) { $0 + $1.fileSize }
        let maxBytes = Int64(maxSizeGB) * 1024 * 1024 * 1024
        guard currentTotal > maxBytes else {
            lock.unlock()
            return
        }
        
        let sorted = cachedTracks.values.sorted(by: { $0.lastAccessed < $1.lastAccessed })
        var toRemove: [CachedTrackInfo] = []
        var runningSize = currentTotal
        for track in sorted {
            if runningSize <= maxBytes {
                break
            }
            toRemove.append(track)
            runningSize -= track.fileSize
        }
        
        let removedIds = Set(toRemove.map(\.id))
        for track in toRemove {
            let safeId = safeIdentifier(for: track.id)
            cachedCoverSafeIds.remove(safeId)
            cachedTracks.removeValue(forKey: track.id)
        }
        let updatedSize = max(0, runningSize)
        let updatedCount = cachedTracks.count
        let snapshot = Array(cachedTracks.values)
        lock.unlock()
        
        scheduleSaveIndex(snapshot)
        
        ioQueue.async { [cacheDirectory] in
            for track in toRemove {
                let safeId = track.id.components(separatedBy: CharacterSet(charactersIn: "/:?*\"<>|\\")).joined(separator: "_")
                let fileUrl = cacheDirectory.appendingPathComponent(track.fileName)
                let coverUrl = cacheDirectory.appendingPathComponent("\(safeId)_cover.jpg")
                let lyricsUrl = cacheDirectory.appendingPathComponent("\(safeId).lrc")
                try? FileManager.default.removeItem(at: fileUrl)
                try? FileManager.default.removeItem(at: coverUrl)
                try? FileManager.default.removeItem(at: lyricsUrl)
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentCacheSizeBytes = updatedSize
            self.cachedTrackCount = updatedCount
            self.cachedIds.subtract(removedIds)
        }
    }
    
    public func removeSong(id: String) {
        let safeId = safeIdentifier(for: id)
        lock.lock()
        downloadingSongIds.remove(id)
        cachedCoverSafeIds.remove(safeId)
        let track = cachedTracks.removeValue(forKey: id)
        let updatedSize = cachedTracks.values.reduce(Int64(0)) { $0 + $1.fileSize }
        let updatedCount = cachedTracks.count
        let snapshot = Array(cachedTracks.values)
        lock.unlock()
        
        if track != nil {
            scheduleSaveIndex(snapshot)
        }
        
        let coverUrl = cacheDirectory.appendingPathComponent("\(safeId)_cover.jpg")
        LocalCoverCache.shared.removeImage(for: coverUrl)
        
        ioQueue.async { [cacheDirectory] in
            if let track = track {
                let fileUrl = cacheDirectory.appendingPathComponent(track.fileName)
                try? FileManager.default.removeItem(at: fileUrl)
            }
            let lyricsUrl = cacheDirectory.appendingPathComponent("\(safeId).lrc")
            try? FileManager.default.removeItem(at: coverUrl)
            try? FileManager.default.removeItem(at: lyricsUrl)
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentCacheSizeBytes = updatedSize
            self.cachedTrackCount = updatedCount
            self.cachedIds.remove(id)
        }
    }
    
    internal func flushIOQueue() {
        ioQueue.sync {}
    }
    
    public func clearAllCache() {
        LocalCoverCache.shared.clear()
        
        lock.lock()
        let tasks = Array(activeDownloadTasks.values)
        activeDownloadTasks.removeAll()
        cachedTracks.removeAll()
        downloadingSongIds.removeAll()
        cachedCoverSafeIds.removeAll()
        lock.unlock()
        
        for task in tasks {
            task.cancel()
        }
        
        scheduleSaveIndex([])
        
        ioQueue.async { [cacheDirectory] in
            if let files = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
                for file in files {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentCacheSizeBytes = 0
            self.cachedTrackCount = 0
            self.cachedIds.removeAll()
            self.downloadingIds.removeAll()
            self.downloadProgress.removeAll()
        }
    }
    
    public func disableAndClearCache() {
        if Thread.isMainThread {
            self.isEnabled = false
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.isEnabled = false
            }
        }
        clearAllCache()
    }
    
    // MARK: - Formatting Helper
    
    public var formattedCurrentSize: String {
        let bytes = Double(currentCacheSizeBytes)
        if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024.0)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", bytes / (1024.0 * 1024.0))
        } else {
            return String(format: "%.2f GB", bytes / (1024.0 * 1024.0 * 1024.0))
        }
    }
}

// MARK: - Download Coordinator

/// Caps the number of simultaneous track downloads so batch operations
/// (e.g. "Cache Selected Tracks") do not spawn an unbounded number of network streams.
private actor DownloadLimiter {
    private let limit: Int
    private var active = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = limit
    }

    func acquire() async {
        if active < limit {
            active += 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if waiters.isEmpty {
            active -= 1
        } else {
            let next = waiters.removeFirst()
            next.resume()
        }
    }
}

private final class DownloadCoordinator: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private struct PendingTask {
        let songId: String
        let expectedBytes: Int64
        let onProgress: (Double) -> Void
        let continuation: CheckedContinuation<(URL, URLResponse), Error>
        var lastReportedTime: TimeInterval = 0
        var lastReportedProgress: Double = 0
    }
    
    private let lock = NSLock()
    private var tasks: [Int: PendingTask] = [:]
    private var session: URLSession!
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20.0
        config.timeoutIntervalForResource = 300.0
        config.urlCache = nil
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func download(
        from url: URL,
        songId: String,
        expectedBytes: Int64,
        onProgress: @escaping (Double) -> Void
    ) async throws -> (URL, URLResponse) {
        let downloadTask = session.downloadTask(with: url)
        let taskId = downloadTask.taskIdentifier
        
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                tasks[taskId] = PendingTask(
                    songId: songId,
                    expectedBytes: expectedBytes,
                    onProgress: onProgress,
                    continuation: continuation
                )
                lock.unlock()
                
                downloadTask.resume()
            }
        } onCancel: {
            downloadTask.cancel()
        }
    }
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        lock.lock()
        guard var pending = tasks[downloadTask.taskIdentifier] else {
            lock.unlock()
            return
        }
        
        let expected: Double
        if totalBytesExpectedToWrite > 0 {
            expected = Double(totalBytesExpectedToWrite)
        } else if pending.expectedBytes > 0 {
            expected = Double(pending.expectedBytes)
        } else {
            expected = 8.0 * 1024.0 * 1024.0 // 8MB default fallback
        }
        
        let rawProgress = min(max(Double(totalBytesWritten) / expected, 0.05), 0.98)
        let now = ProcessInfo.processInfo.systemUptime
        let shouldReport = (now - pending.lastReportedTime >= 0.05) || (rawProgress - pending.lastReportedProgress >= 0.02)
        if shouldReport {
            pending.lastReportedTime = now
            pending.lastReportedProgress = rawProgress
            tasks[downloadTask.taskIdentifier] = pending
            lock.unlock()
            pending.onProgress(rawProgress)
        } else {
            lock.unlock()
        }
    }
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        lock.lock()
        guard let pending = tasks.removeValue(forKey: downloadTask.taskIdentifier) else {
            lock.unlock()
            return
        }
        lock.unlock()
        
        let tempDir = FileManager.default.temporaryDirectory
        let stableUrl = tempDir.appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            try? FileManager.default.removeItem(at: stableUrl)
            try FileManager.default.moveItem(at: location, to: stableUrl)
            pending.onProgress(1.0)
            pending.continuation.resume(returning: (stableUrl, downloadTask.response ?? URLResponse()))
        } catch {
            pending.continuation.resume(throwing: error)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            lock.lock()
            let pending = tasks.removeValue(forKey: task.taskIdentifier)
            lock.unlock()
            
            pending?.continuation.resume(throwing: error)
        }
    }
}
