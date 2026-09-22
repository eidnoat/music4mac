import Foundation
import AVFoundation
import AppKit
import Combine

public final class AudioPlayerEngine: ObservableObject {
    public static let shared = AudioPlayerEngine()
    
    private let player = AVPlayer()
    private var timeObserverToken: Any?
    private var cancellables = Set<AnyCancellable>()
    
    @Published public var currentSong: Song?
    @Published public var status: PlaybackStatus = .stopped
    @Published public var volume: Float = 0.8 {
        didSet {
            player.volume = volume
            UserDefaults.standard.set(volume, forKey: "music.player.volume")
        }
    }
    
    @Published public var parsedLyrics: ParsedLyrics = ParsedLyrics()
    public var activeLyricIndex: Int = -1
    public var lyricsOffset: TimeInterval = 0 // In seconds
    
    public let progress = AudioProgressTracker.shared
    public var currentTime: TimeInterval {
        get { progress.currentTime }
        set { progress.currentTime = newValue }
    }
    public var duration: TimeInterval {
        get { progress.duration }
        set { progress.duration = newValue }
    }
    
    private let playQueue = PlayQueueManager.shared
    private var scrobbledCurrentSong = false
    private var isSeeking = false
    private var autoCacheTask: Task<Void, Never>?
    private var itemStatusObservation: NSKeyValueObservation?
    private var loadingTimeoutTask: Task<Void, Never>?
    private let playbackLoadingTimeout: TimeInterval = 12.0
    @Published public var errorMessage: String? = nil
    
    private init() {
        let savedVol = UserDefaults.standard.object(forKey: "music.player.volume") != nil
            ? UserDefaults.standard.float(forKey: "music.player.volume")
            : UserDefaults.standard.float(forKey: "sylvakru.player.volume")
        self.volume = savedVol > 0 ? savedVol : 0.8
        self.player.volume = self.volume
        
        setupTimeObserver()
        
        // Listen to queue song changes
        playQueue.$currentIndex
            .receive(on: RunLoop.main)
            .sink { [weak self] newIdx in
                guard let self = self else { return }
                guard !self.playQueue.isReorganizingQueue else { return }
                guard newIdx >= 0 && newIdx < self.playQueue.queue.count else { return }
                let song = self.playQueue.queue[newIdx]
                if song.id != self.currentSong?.id {
                    self.loadAndPlay(song: song)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Playback Control
    
    public func playSong(_ song: Song, in queue: [Song]? = nil) {
        if let queue = queue {
            if let idx = queue.firstIndex(where: { $0.id == song.id }) {
                playQueue.setQueue(queue, startAt: idx)
            } else {
                playQueue.setQueue([song] + queue, startAt: 0)
            }
        } else {
            playQueue.append(song)
        }
        loadAndPlay(song: song)
    }
    
    public func loadAndPlay(song: Song) {
        cancelLoadingTimeout()
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        autoCacheTask?.cancel()
        autoCacheTask = nil
        self.errorMessage = nil
        
        self.isSeeking = false
        self.currentSong = song
        self.currentTime = 0
        self.duration = song.duration
        self.status = .loading
        self.scrobbledCurrentSong = false
        self.activeLyricIndex = -1
        
        StorageManager.shared.recordPlayStart(song: song)
        loadLyrics(for: song)
        
        var playUrl: URL?
        var isLocalOrCached = false
        
        if let cachedUrl = SongCacheManager.shared.getCachedFileUrl(for: song) {
            playUrl = cachedUrl
            isLocalOrCached = true
            SongCacheManager.shared.recordAccess(songId: song.id)
            BookmarkManager.shared.stopAccessingTrack()
            if song.source == .navidrome, let remoteId = song.remoteId {
                Task { await NavidromeClient.shared.scrobble(songId: remoteId, submission: false) }
            }
        } else if song.source == .local, let localPath = song.localPath {
            playUrl = URL(fileURLWithPath: localPath)
            isLocalOrCached = true
            _ = BookmarkManager.shared.startAccessingTrack(url: playUrl!)
        } else {
            BookmarkManager.shared.stopAccessingTrack()
            if song.source == .navidrome, let remoteId = song.remoteId {
                playUrl = NavidromeClient.shared.getStreamUrl(songId: remoteId)
                Task { await NavidromeClient.shared.scrobble(songId: remoteId, submission: false) }
                
                // Auto-cache played song in background if enabled
                if SongCacheManager.shared.isEnabled {
                    autoCacheTask = Task(priority: .utility) {
                        await SongCacheManager.shared.cacheSong(song)
                    }
                }
            }
        }
        
        guard let url = playUrl else {
            let msg = "Unable to get playback URL"
            self.status = .error(msg)
            self.errorMessage = msg
            return
        }
        
        // Detach old item observers
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemPlaybackStalled, object: nil)
        
        let playerItem = AVPlayerItem(url: url)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidStall),
            name: .AVPlayerItemPlaybackStalled,
            object: playerItem
        )
        
        // Reuse persistent AVPlayer and replace item: frees previous decoded audio buffers
        self.player.replaceCurrentItem(with: playerItem)
        self.player.volume = volume
        
        if isLocalOrCached {
            self.player.play()
            self.status = .playing
            NowPlayingManager.shared.updateNowPlaying(
                song: song,
                playbackRate: 1.0,
                currentTime: 0
            )
        } else {
            self.status = .loading
            
            itemStatusObservation = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
                DispatchQueue.main.async {
                    guard let self = self, self.currentSong?.id == song.id else { return }
                    switch item.status {
                    case .readyToPlay:
                        self.cancelLoadingTimeout()
                        if self.status == .loading {
                            self.player.play()
                            self.status = .playing
                            NowPlayingManager.shared.updateNowPlaying(
                                song: song,
                                playbackRate: 1.0,
                                currentTime: 0
                            )
                        }
                    case .failed:
                        self.cancelLoadingTimeout()
                        let err = item.error?.localizedDescription ?? "Failed to load audio stream"
                        self.handleLoadingFailure(message: err, song: song)
                    case .unknown:
                        break
                    @unknown default:
                        break
                    }
                }
            }
            
            loadingTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(12 * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self = self, self.currentSong?.id == song.id, self.status == .loading else { return }
                    self.handleLoadingTimeout(song: song)
                }
            }
        }
    }
    
    private func cancelLoadingTimeout() {
        loadingTimeoutTask?.cancel()
        loadingTimeoutTask = nil
    }
    
    private func handleLoadingTimeout(song: Song) {
        cancelLoadingTimeout()
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        
        player.pause()
        player.replaceCurrentItem(with: nil)
        
        autoCacheTask?.cancel()
        autoCacheTask = nil
        SongCacheManager.shared.cancelCaching(songId: song.id)
        
        let msg = "Network timeout: track failed to load. Please check your network connection."
        self.status = .error(msg)
        self.errorMessage = msg
    }
    
    private func handleLoadingFailure(message: String, song: Song) {
        cancelLoadingTimeout()
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        
        player.pause()
        player.replaceCurrentItem(with: nil)
        
        autoCacheTask?.cancel()
        autoCacheTask = nil
        SongCacheManager.shared.cancelCaching(songId: song.id)
        
        let msg = "Network error: \(message)"
        self.status = .error(msg)
        self.errorMessage = msg
    }
    
    public func play() {
        if player.currentItem == nil {
            if let first = playQueue.currentSong {
                loadAndPlay(song: first)
            }
            return
        }
        player.play()
        self.status = .playing
        NowPlayingManager.shared.updateNowPlaying(
            song: currentSong,
            playbackRate: 1.0,
            currentTime: currentTime
        )
    }
    
    public func pause() {
        player.pause()
        self.status = .paused
        NowPlayingManager.shared.updateNowPlaying(
            song: currentSong,
            playbackRate: 0.0,
            currentTime: currentTime
        )
    }
    
    public func togglePlayPause() {
        switch status {
        case .playing:
            pause()
        case .loading:
            stop()
        case .paused:
            play()
        case .stopped, .error:
            if let song = currentSong ?? playQueue.currentSong {
                loadAndPlay(song: song)
            }
        }
    }
    
    public func skipToNext() {
        if let next = playQueue.nextSong() {
            loadAndPlay(song: next)
        } else {
            stop()
        }
    }
    
    public func skipToPrevious() {
        if currentTime > 3.0 {
            seek(to: 0)
        } else if let prev = playQueue.previousSong() {
            loadAndPlay(song: prev)
        }
    }
    
    public func seek(to seconds: TimeInterval) {
        guard player.currentItem != nil else { return }
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return }
        let targetSeconds = min(seconds, duration > 0 ? duration : seconds)
        let cmTime = CMTime(seconds: targetSeconds, preferredTimescale: 1000)
        let wasPlaying = (self.status == .playing)
        
        self.isSeeking = true
        self.currentTime = targetSeconds
        self.updateLyricsActiveIndex()
        
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.currentTime = targetSeconds
                self.updateLyricsActiveIndex()
                self.isSeeking = false
                if wasPlaying {
                    self.player.play()
                    self.status = .playing
                }
                NowPlayingManager.shared.updateNowPlaying(
                    song: self.currentSong,
                    playbackRate: wasPlaying ? 1.0 : 0.0,
                    currentTime: targetSeconds
                )
            }
        }
    }
    
    // MARK: - Lyrics
    
    private func loadLyrics(for song: Song) {
        self.parsedLyrics = ParsedLyrics()
        self.activeLyricIndex = -1
        self.lyricsOffset = 0
        
        if let embedded = song.lyrics, !embedded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let parsed = LyricsService.shared.parse(lrcContent: embedded, songDuration: song.duration)
            self.parsedLyrics = parsed
            self.lyricsOffset = parsed.offset
            self.updateLyricsActiveIndex()
            return
        }
        
        if let cached = SongCacheManager.shared.getCachedLyrics(forId: song.id),
           !cached.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let parsed = LyricsService.shared.parse(lrcContent: cached, songDuration: song.duration)
            self.parsedLyrics = parsed
            self.lyricsOffset = parsed.offset
            self.updateLyricsActiveIndex()
            return
        }
        
        if song.source == .navidrome, let remoteId = song.remoteId {
            Task {
                if let lrc = try? await NavidromeClient.shared.getLyrics(songId: remoteId) {
                    SongCacheManager.shared.saveCachedLyrics(forId: song.id, lyrics: lrc)
                    await MainActor.run {
                        if self.currentSong?.id == song.id {
                            let parsed = LyricsService.shared.parse(lrcContent: lrc, songDuration: song.duration)
                            self.parsedLyrics = parsed
                            self.lyricsOffset = parsed.offset
                            self.updateLyricsActiveIndex()
                        }
                    }
                } else {
                    await MainActor.run {
                        if self.currentSong?.id == song.id {
                            self.parsedLyrics = ParsedLyrics(isKaraoke: false, lines: [LyricLine(start: 0, text: "No lyrics available")])
                        }
                    }
                }
            }
        } else {
            self.parsedLyrics = ParsedLyrics(isKaraoke: false, lines: [LyricLine(start: 0, text: "No lyrics available")])
        }
    }
    
    private func updateLyricsActiveIndex() {
        let active = LyricsService.shared.activeLineIndex(
            in: parsedLyrics.lines,
            position: currentTime,
            offset: lyricsOffset
        )
        if active != self.activeLyricIndex {
            self.activeLyricIndex = active
        }
    }
    
    // MARK: - Time Observer & End of Track
    
    private func setupTimeObserver() {
        // 250ms interval (4 Hz) provides smooth UI progress updates while saving ~80% CPU overhead
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            guard self.status == .playing || self.status == .paused else { return }
            guard !self.isSeeking else { return }
            let seconds = CMTimeGetSeconds(time)
            if !seconds.isNaN && seconds >= 0 {
                self.currentTime = seconds
            }
            
            if let itemDuration = self.player.currentItem?.duration {
                let durSeconds = CMTimeGetSeconds(itemDuration)
                if !durSeconds.isNaN && durSeconds > 0 && abs(self.duration - durSeconds) > 0.5 {
                    self.duration = durSeconds
                }
            }
            
            // Scrobble & play count trigger (> 50% duration or > 4 minutes)
            if !self.scrobbledCurrentSong && self.duration > 0 {
                if seconds > (self.duration / 2.0) || seconds > 240 {
                    self.scrobbledCurrentSong = true
                    if let song = self.currentSong {
                        StorageManager.shared.incrementPlayCount(songId: song.id)
                        if song.source == .navidrome, let remoteId = song.remoteId {
                            Task { await NavidromeClient.shared.scrobble(songId: remoteId, submission: true) }
                        }
                    }
                }
            }
        }
    }
    
    @objc private func playerItemDidReachEnd() {
        if !self.scrobbledCurrentSong {
            self.scrobbledCurrentSong = true
            if let song = self.currentSong {
                StorageManager.shared.incrementPlayCount(songId: song.id)
                if song.source == .navidrome, let remoteId = song.remoteId {
                    Task { await NavidromeClient.shared.scrobble(songId: remoteId, submission: true) }
                }
            }
        }
        
        if playQueue.playMode == .repeatOne {
            seek(to: 0)
            play()
        } else {
            skipToNext()
        }
    }
    
    @objc private func playerItemDidStall() {
        if status == .playing {
            player.play()
        }
    }
    
    public func stop() {
        cancelLoadingTimeout()
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        autoCacheTask?.cancel()
        autoCacheTask = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemPlaybackStalled, object: nil)
        player.pause()
        player.replaceCurrentItem(with: nil) // Explicitly flush and release CoreMedia audio buffers
        BookmarkManager.shared.stopAccessingTrack()
        self.status = .stopped
        self.currentTime = 0
        self.duration = 0
        self.errorMessage = nil
        NowPlayingManager.shared.updateNowPlaying(song: nil, playbackRate: 0, currentTime: 0)
    }
    
    private func teardownPlayer() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        stop()
    }
    
    deinit {
        teardownPlayer()
    }
}
