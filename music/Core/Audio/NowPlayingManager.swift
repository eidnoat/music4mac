import Foundation
import MediaPlayer

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

public final class NowPlayingManager: @unchecked Sendable {
    public static let shared = NowPlayingManager()
    
    private let lock = NSLock()
    private var currentSongId: String?
    private var currentArtwork: MPMediaItemArtwork?
    private var artworkTask: Task<Void, Never>?
    
    private init() {
        setupRemoteCommands()
    }
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in
            DispatchQueue.main.async {
                AudioPlayerEngine.shared.play()
            }
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            DispatchQueue.main.async {
                AudioPlayerEngine.shared.pause()
            }
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            DispatchQueue.main.async {
                AudioPlayerEngine.shared.togglePlayPause()
            }
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { _ in
            DispatchQueue.main.async {
                AudioPlayerEngine.shared.skipToNext()
            }
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { _ in
            DispatchQueue.main.async {
                AudioPlayerEngine.shared.skipToPrevious()
            }
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let targetPos = posEvent.positionTime
            DispatchQueue.main.async {
                AudioPlayerEngine.shared.seek(to: targetPos)
            }
            return .success
        }
        
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.beginReceivingRemoteControlEvents()
        }
        #endif
    }
    
    public func updateNowPlaying(
        song: Song?,
        playbackRate: Float,
        currentTime: TimeInterval,
        artworkImage: PlatformImage? = nil
    ) {
        let infoCenter = MPNowPlayingInfoCenter.default()
        guard let song = song else {
            lock.lock()
            currentSongId = nil
            currentArtwork = nil
            artworkTask?.cancel()
            artworkTask = nil
            lock.unlock()
            
            #if os(iOS)
            infoCenter.playbackState = .stopped
            #endif
            infoCenter.nowPlayingInfo = nil
            return
        }
        
        lock.lock()
        if currentSongId != song.id {
            currentSongId = song.id
            currentArtwork = nil
            artworkTask?.cancel()
            artworkTask = nil
        }
        
        if let image = artworkImage, image.size.width > 0, image.size.height > 0 {
            currentArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        } else if currentArtwork == nil, let coverUrl = song.effectiveCoverUrl {
            if let cached = CoverImageCache.shared.cachedImage(for: coverUrl),
               cached.size.width > 0, cached.size.height > 0 {
                currentArtwork = MPMediaItemArtwork(boundsSize: cached.size) { _ in cached }
            } else {
                let targetSongId = song.id
                artworkTask = Task { [weak self] in
                    guard let image = await CoverImageCache.shared.loadImage(for: coverUrl) else { return }
                    guard !Task.isCancelled else { return }
                    guard image.size.width > 0, image.size.height > 0 else { return }
                    self?.setLoadedArtwork(image, for: targetSongId)
                }
            }
        }
        let artworkToSet = currentArtwork
        lock.unlock()
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyPlaybackDuration: song.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: playbackRate
        ]
        
        if let artwork = artworkToSet {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        #if os(iOS)
        infoCenter.playbackState = (playbackRate > 0) ? .playing : .paused
        #endif
        infoCenter.nowPlayingInfo = nowPlayingInfo
    }
    
    private func setLoadedArtwork(_ image: PlatformImage, for songId: String) {
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        
        lock.lock()
        guard currentSongId == songId else {
            lock.unlock()
            return
        }
        currentArtwork = artwork
        lock.unlock()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            guard self.currentSongId == songId else {
                self.lock.unlock()
                return
            }
            self.lock.unlock()
            
            let infoCenter = MPNowPlayingInfoCenter.default()
            var currentInfo = infoCenter.nowPlayingInfo ?? [:]
            currentInfo[MPMediaItemPropertyArtwork] = artwork
            infoCenter.nowPlayingInfo = currentInfo
        }
    }
}
