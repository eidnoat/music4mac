import SwiftUI

public struct iOSNowPlayingView: View {
    @ObservedObject var player = AudioPlayerEngine.shared
    @ObservedObject var queue = PlayQueueManager.shared
    @ObservedObject var progress = AudioProgressTracker.shared
    
    @Environment(\.dismiss) private var dismiss
    @State private var showLyrics: Bool = false
    @State private var showQueue: Bool = false
    @State private var isScrubbing: Bool = false
    @State private var scrubTime: TimeInterval = 0
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background subtle blur/tint
                Color.platformWindowBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Bar: Drag indicator & dismiss chevron
                    headerBar
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    
                    Spacer(minLength: 8)
                    
                    // Main Artwork or Lyrics
                    if showLyrics {
                        LyricsView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.opacity)
                    } else {
                        artworkView(maxSize: min(geometry.size.width - 56, geometry.size.height * 0.45))
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                    
                    Spacer(minLength: 12)
                    
                    // Metadata & Favorite
                    metadataView
                        .padding(.horizontal, 28)
                    
                    // Scrubber Bar
                    scrubberView
                        .padding(.horizontal, 28)
                        .padding(.top, 12)
                    
                    // Primary Controls (Shuffle, Prev, Play/Pause, Next, Repeat)
                    controlsView
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    
                    // Volume Slider
                    volumeView
                        .padding(.horizontal, 28)
                        .padding(.top, 16)
                    
                    // Bottom Accessories (Lyrics toggle, Queue toggle)
                    bottomAccessories
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showQueue) {
            iOSQueueSheet()
        }
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("NOW PLAYING")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.secondary)
                if let song = player.currentSong {
                    Text(song.album)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Button {
                showQueue.toggle()
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(showQueue ? .appleMusicRed : .secondary)
                    .frame(width: 44, height: 44)
            }
        }
    }
    
    // MARK: - Artwork
    private func artworkView(maxSize: CGFloat) -> some View {
        let size = max(180, maxSize)
        return CoverImageView(url: player.currentSong?.effectiveCoverUrl) {
            ZStack {
                Color.secondary.opacity(0.12)
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.35))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
    }
    
    // MARK: - Metadata
    private var metadataView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentSong?.title ?? "Not Playing")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(player.currentSong?.artist ?? "Select a track to start")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Scrubber
    private var scrubberView: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubTime : progress.currentTime },
                    set: { scrubTime = $0 }
                ),
                in: 0...max(progress.duration, 1),
                onEditingChanged: { editing in
                    isScrubbing = editing
                    if !editing {
                        player.seek(to: scrubTime)
                    } else {
                        scrubTime = progress.currentTime
                    }
                }
            )
            .tint(.primary)
            
            HStack {
                Text(formatTime(isScrubbing ? scrubTime : progress.currentTime))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                let remaining = max(0, progress.duration - (isScrubbing ? scrubTime : progress.currentTime))
                Text("-\(formatTime(remaining))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Controls
    private var controlsView: some View {
        HStack(spacing: 0) {
            // Shuffle
            Button {
                queue.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 18))
                    .foregroundColor(queue.isShuffleEnabled ? .appleMusicRed : .secondary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            
            // Previous
            Button {
                player.skipToPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            
            // Play / Pause
            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.status == .playing ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            
            // Next
            Button {
                player.skipToNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            
            // Repeat
            Button {
                queue.cycleRepeatMode()
            } label: {
                Image(systemName: queue.repeatMode == .repeatOne ? "repeat.1" : "repeat")
                    .font(.system(size: 18))
                    .foregroundColor(queue.repeatMode != .off ? .appleMusicRed : .secondary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Volume
    private var volumeView: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Slider(
                value: Binding(
                    get: { player.volume },
                    set: { player.volume = $0 }
                ),
                in: 0...1
            )
            .tint(.secondary)
            
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Bottom Accessories
    private var bottomAccessories: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showLyrics.toggle()
                }
            } label: {
                Image(systemName: "quote.bubble")
                    .font(.system(size: 20))
                    .foregroundColor(showLyrics ? .appleMusicRed : .secondary)
                    .padding(8)
                    .background(showLyrics ? Color.appleMusicRed.opacity(0.15) : Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button {
                showQueue.toggle()
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20))
                    .foregroundColor(showQueue ? .appleMusicRed : .secondary)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        guard !seconds.isNaN && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Queue Sheet
public struct iOSQueueSheet: View {
    @ObservedObject var queue = PlayQueueManager.shared
    @ObservedObject var player = AudioPlayerEngine.shared
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                if queue.queue.isEmpty {
                    Text("Queue is empty")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(Array(queue.queue.enumerated()), id: \.element.id) { index, song in
                        let isCurrent = index == queue.currentIndex
                        HStack(spacing: 12) {
                            if isCurrent {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.appleMusicRed)
                                    .font(.system(size: 13))
                            } else {
                                Text("\(index + 1)")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, alignment: .trailing)
                            }
                            
                            TrackCoverView(song: song, size: 38, cornerRadius: 6)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(song.title)
                                    .font(.system(size: 14, weight: isCurrent ? .semibold : .regular))
                                    .foregroundColor(isCurrent ? .appleMusicRed : .primary)
                                    .lineLimit(1)
                                Text(song.artist)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            queue.playQueueItem(at: index)
                        }
                    }
                }
            }
            .navigationTitle("Playing Next")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
