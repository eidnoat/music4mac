#if os(iOS)
import SwiftUI

public struct iOSNowPlayingView: View {
    @ObservedObject var player = AudioPlayerEngine.shared
    @ObservedObject var queue = PlayQueueManager.shared
    @ObservedObject var progress = AudioProgressTracker.shared
    
    @Environment(\.dismiss) private var dismiss
    public var onDismiss: (() -> Void)? = nil
    
    @State private var showLyrics: Bool = false
    @State private var showQueue: Bool = false
    @State private var isScrubbing: Bool = false
    @State private var scrubTime: TimeInterval = 0
    @State private var dragOffset: CGFloat = 0
    
    public init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }
    
    private func closeView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height && geometry.size.width >= 600
            
            ZStack {
                // Background subtle blur/tint
                Color.platformWindowBackground.ignoresSafeArea()
                
                if isLandscape {
                    landscapeLayout(geometry: geometry)
                } else {
                    portraitLayout(geometry: geometry)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shadow(color: .black.opacity(dragOffset > 0 ? 0.3 : 0), radius: 25, x: 0, y: -6)
            .offset(y: max(0, dragOffset))
            .simultaneousGesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { value in
                        guard !isScrubbing else { return }
                        // Respond to downward pull where vertical motion dominates
                        if value.translation.height > 0 && value.translation.height > abs(value.translation.width) * 1.2 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        guard !isScrubbing else { return }
                        if dragOffset > 100 || value.predictedEndTranslation.height > 200 {
                            closeView()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .onDisappear {
                dragOffset = 0
            }
        }
        .sheet(isPresented: $showQueue) {
            iOSQueueSheet()
        }
    }
    
    // MARK: - Portrait Layout
    private func portraitLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Top Bar: Drag indicator & dismiss chevron
            headerBar
                .padding(.horizontal, 20)
                .padding(.top, max(geometry.safeAreaInsets.top, 12))
            
            Spacer(minLength: 8)
            
            // Main Artwork or Lyrics
            if showLyrics {
                LyricsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            } else {
                artworkView(maxSize: min(geometry.size.width - 56, geometry.size.height * 0.45, 420))
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            
            Spacer(minLength: 12)
            
            // Metadata
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
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20))
        }
        .frame(maxWidth: 560)
    }
    
    // MARK: - Landscape Layout (iPad / Wide screen)
    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            headerBar
                .padding(.horizontal, 32)
                .padding(.top, max(geometry.safeAreaInsets.top, 16))
            
            HStack(spacing: 48) {
                // Left: Large Artwork or Real-time Lyrics
                VStack {
                    Spacer()
                    if showLyrics {
                        LyricsView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.opacity)
                    } else {
                        let artSize = min(geometry.size.height * 0.65, geometry.size.width * 0.42, 480)
                        artworkView(maxSize: artSize)
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Right: Playback Controls & Info
                VStack(spacing: 0) {
                    Spacer()
                    
                    metadataView
                        .padding(.horizontal, 16)
                    
                    scrubberView
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                    
                    controlsView
                        .padding(.horizontal, 8)
                        .padding(.top, 24)
                    
                    volumeView
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                    
                    bottomAccessories
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    
                    Spacer()
                }
                .frame(maxWidth: min(geometry.size.width * 0.46, 500))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Header
    private var headerBar: some View {
        VStack(spacing: 4) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 2)
                .contentShape(Rectangle().inset(by: -10))
            
            HStack {
                Button {
                    closeView()
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
                
                // Balance placeholder matching dismiss button width
                Color.clear
                    .frame(width: 44, height: 44)
            }
        }
        .contentShape(Rectangle())
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
            CompactSlider(
                value: Binding(
                    get: { isScrubbing ? scrubTime : progress.currentTime },
                    set: { scrubTime = $0 }
                ),
                in: 0...max(progress.duration, 1),
                thumbSize: 10,
                trackHeight: 4,
                activeColor: .primary,
                onEditingChanged: { editing in
                    isScrubbing = editing
                    if !editing {
                        player.seek(to: scrubTime)
                    } else {
                        scrubTime = progress.currentTime
                    }
                }
            )
            
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
                if player.status == .loading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.6)
                        .frame(width: 64, height: 64)
                        .frame(maxWidth: .infinity)
                } else {
                    Image(systemName: player.status == .playing ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                }
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
                Image(systemName: queue.playMode == .repeatOne ? "repeat.1" : "repeat")
                    .font(.system(size: 18))
                    .foregroundColor(queue.playMode != .sequence ? .appleMusicRed : .secondary)
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
            
            CompactSlider(
                value: Binding(
                    get: { player.volume },
                    set: { player.volume = $0 }
                ),
                in: 0...1,
                thumbSize: 10,
                trackHeight: 4,
                activeColor: .secondary
            )
            
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

// MARK: - Queue Row Component
public struct iOSQueueRowView: View {
    public let index: Int
    public let song: Song
    public let isCurrent: Bool
    public let onSelect: () -> Void
    
    public init(index: Int, song: Song, isCurrent: Bool, onSelect: @escaping () -> Void) {
        self.index = index
        self.song = song
        self.isCurrent = isCurrent
        self.onSelect = onSelect
    }
    
    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                if isCurrent {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.appleMusicRed)
                        .font(.system(size: 13))
                        .frame(width: 24, alignment: .trailing)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
}

// MARK: - Queue Sheet
public struct iOSQueueSheet: View {
    @ObservedObject var queue = PlayQueueManager.shared
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
                    ForEach(0..<queue.queue.count, id: \.self) { index in
                        let song = queue.queue[index]
                        let isCurrent = (index == queue.currentIndex)
                        iOSQueueRowView(
                            index: index,
                            song: song,
                            isCurrent: isCurrent,
                            onSelect: { queue.playQueueItem(at: index) }
                        )
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
#endif
