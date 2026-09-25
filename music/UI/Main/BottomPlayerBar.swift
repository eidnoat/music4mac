#if os(macOS)
import SwiftUI
import AVFoundation

public struct BottomPlayerBar: View {
    @ObservedObject var player = AudioPlayerEngine.shared
    @ObservedObject var queue = PlayQueueManager.shared
    
    @Binding var showLyrics: Bool
    @Binding var showQueue: Bool
    
    public init(
        showLyrics: Binding<Bool>,
        showQueue: Binding<Bool>
    ) {
        self._showLyrics = showLyrics
        self._showQueue = showQueue
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            // Track Info
            trackInfoSection
                .frame(minWidth: 220, alignment: .leading)
            
            Spacer()
            
            // Central Playback Controls & Progress Bar
            VStack(spacing: 6) {
                playbackButtons
                BottomProgressBarSection(player: player)
            }
            .frame(maxWidth: 550)
            
            Spacer()
            
            // Right Side: Volume & View Toggles
            HStack(spacing: 14) {
                volumeControl
                viewToggles
            }
            .frame(minWidth: 220, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
        .tint(Color.appleMusicRed)
        .accentColor(Color.appleMusicRed)
    }
    
    // MARK: - Track Info
    private var trackInfoSection: some View {
        HStack(spacing: 12) {
            TrackCoverView(song: player.currentSong, size: 46, cornerRadius: 6)
                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
            
            if let song = player.currentSong {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(song.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        if case .error = player.status {
                            Image(systemName: "wifi.exclamationmark")
                                .foregroundColor(.orange)
                                .font(.system(size: 11))
                        }
                    }
                    
                    if case .error(let msg) = player.status {
                        Text(msg)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                            .help(msg)
                    } else {
                        Text(song.artist)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Not Playing")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Select a track to start listening")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
        }
    }
    
    // MARK: - Playback Buttons
    private var playbackButtons: some View {
        HStack(spacing: 20) {
            Button {
                queue.togglePlayMode()
            } label: {
                Image(systemName: queue.playMode.iconName)
                    .font(.system(size: 13))
                    .foregroundColor(queue.playMode == .sequence ? .secondary : .appleMusicRed)
            }
            .buttonStyle(.plain)
            .help(queue.playMode.title)
            
            Button {
                player.skipToPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            
            Button {
                player.togglePlayPause()
            } label: {
                if player.status == .loading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 32, height: 32)
                } else if case .error = player.status {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                } else {
                    Image(systemName: player.status == .playing ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                }
            }
            .buttonStyle(.plain)
            .help(player.status == .loading ? "Loading track..." : (player.errorMessage ?? (player.status == .playing ? "Pause" : "Play")))
            
            Button {
                player.skipToNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Volume Control
    private var volumeControl: some View {
        HStack(spacing: 6) {
            Button {
                if player.volume > 0 {
                    player.volume = 0
                } else {
                    player.volume = 0.8
                }
            } label: {
                Image(systemName: player.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            Slider(value: $player.volume, in: 0...1)
                .tint(.appleMusicRed)
                .controlSize(.mini)
                .frame(width: 80)
        }
    }
    
    // MARK: - View Toggles
    private var viewToggles: some View {
        HStack(spacing: 12) {
            Button {
                showLyrics.toggle()
                if showLyrics {
                    showQueue = false
                }
            } label: {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 14))
                    .foregroundColor(showLyrics ? .appleMusicRed : .secondary)
            }
            .buttonStyle(.plain)
            .help("Lyrics")
            
            Button {
                showQueue.toggle()
                if showQueue {
                    showLyrics = false
                }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 14))
                    .foregroundColor(showQueue ? .appleMusicRed : .secondary)
            }
            .buttonStyle(.plain)
            .help("Queue")
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let min = total / 60
        let sec = total % 60
        return String(format: "%02d:%02d", min, sec)
    }
}

private struct BottomProgressBarSection: View {
    @ObservedObject var progress = AudioProgressTracker.shared
    let player: AudioPlayerEngine
    
    @State private var isDraggingSlider = false
    @State private var dragPosition: TimeInterval = 0
    
    var body: some View {
        HStack(spacing: 8) {
            Text(formatTime(isDraggingSlider ? dragPosition : progress.currentTime))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 38, alignment: .trailing)
            
            PlaybackProgressBar(
                currentTime: progress.currentTime,
                duration: progress.duration,
                isDragging: $isDraggingSlider,
                dragPosition: $dragPosition,
                onSeek: { target in
                    player.seek(to: target)
                }
            )
            
            Text(formatTime(progress.duration))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 38, alignment: .leading)
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let min = total / 60
        let sec = total % 60
        return String(format: "%02d:%02d", min, sec)
    }
}

public struct PlaybackProgressBar: View {
    let currentTime: TimeInterval
    let duration: TimeInterval
    @Binding var isDragging: Bool
    @Binding var dragPosition: TimeInterval
    let onSeek: (TimeInterval) -> Void
    
    @State private var isHovering = false
    
    public var body: some View {
        GeometryReader { geo in
            let total = max(duration, 1)
            let activeTime = isDragging ? dragPosition : currentTime
            let progress = min(max(activeTime / total, 0), 1)
            let width = geo.size.width
            
            ZStack(alignment: .leading) {
                // Background Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.18))
                    .frame(height: isHovering || isDragging ? 5 : 3.5)
                
                // Played Progress Bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.appleMusicRed)
                    .frame(width: max(width * CGFloat(progress), 0), height: isHovering || isDragging ? 5 : 3.5)
                
                // Scrub Knob
                if isHovering || isDragging {
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                        .frame(width: 11, height: 11)
                        .offset(x: min(max(width * CGFloat(progress) - 5.5, 0), max(width - 11, 0)))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let pct = min(max(value.location.x / max(width, 1), 0), 1)
                        dragPosition = pct * total
                    }
                    .onEnded { value in
                        let pct = min(max(value.location.x / max(width, 1), 0), 1)
                        let target = pct * total
                        isDragging = false
                        dragPosition = target
                        onSeek(target)
                    }
            )
        }
        .frame(height: 16)
        .animation(.none, value: currentTime)
    }
}
#endif
