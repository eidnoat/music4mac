import Foundation
import MediaPlayer

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

public final class NowPlayingManager: @unchecked Sendable {
    public static let shared = NowPlayingManager()
    
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
    }
    
    public func updateNowPlaying(
        song: Song?,
        playbackRate: Float,
        currentTime: TimeInterval,
        artworkImage: PlatformImage? = nil
    ) {
        let infoCenter = MPNowPlayingInfoCenter.default()
        guard let song = song else {
            infoCenter.nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyPlaybackDuration: song.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: playbackRate
        ]
        
        if let image = artworkImage {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        infoCenter.nowPlayingInfo = nowPlayingInfo
    }
}
