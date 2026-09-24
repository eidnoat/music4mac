#if os(iOS)
import SwiftUI

public enum iPadSidebarItem: String, CaseIterable, Identifiable {
    case tracks = "Tracks"
    case albums = "Albums"
    case artists = "Artists"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .tracks: return "music.note.list"
        case .albums: return "square.stack"
        case .artists: return "music.mic"
        case .settings: return "gearshape"
        }
    }
}

public struct iPadMainView: View {
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var player = AudioPlayerEngine.shared
    @ObservedObject var queue = PlayQueueManager.shared
    @ObservedObject var progress = AudioProgressTracker.shared
    
    @State private var selectedItem: iPadSidebarItem? = .tracks
    @State private var isShowingNowPlayingModal = false
    @State private var showSideBySideLyrics = false
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            List(iPadSidebarItem.allCases, selection: $selectedItem) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue, systemImage: item.icon)
                        .font(.system(size: 15, weight: .medium))
                }
            }
            .navigationTitle("music")
        } detail: {
            VStack(spacing: 0) {
                // Main Content
                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Divider()
                
                // Wide iPad Player Bar
                iPadPlayerBar(
                    onTapNowPlaying: { isShowingNowPlayingModal = true },
                    onToggleLyrics: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSideBySideLyrics.toggle()
                        }
                    },
                    isLyricsActive: showSideBySideLyrics
                )
            }
        }
        .sheet(isPresented: $isShowingNowPlayingModal) {
            iPadNowPlayingSideBySideView()
        }
    }
    
    @ViewBuilder
    private var detailContent: some View {
        switch selectedItem {
        case .tracks, .none:
            SongListView(title: "Tracks", songs: storage.songs)
        case .albums:
            AlbumGridView(albums: storage.albums)
        case .artists:
            ArtistListView(artists: storage.artists)
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Wide iPad Player Bar
public struct iPadPlayerBar: View {
    @ObservedObject var player = AudioPlayerEngine.shared
    @ObservedObject var progress = AudioProgressTracker.shared
    @ObservedObject var queue = PlayQueueManager.shared
    
    let onTapNowPlaying: () -> Void
    let onToggleLyrics: () -> Void
    let isLyricsActive: Bool
    
    @State private var isScrubbing = false
    @State private var scrubTime: TimeInterval = 0
    @State private var showQueue = false
    
    public var body: some View {
        HStack(spacing: 20) {
            // Track Info
            Button(action: onTapNowPlaying) {
                HStack(spacing: 12) {
                    TrackCoverView(song: player.currentSong, size: 48, cornerRadius: 8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.currentSong?.title ?? "Not Playing")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(player.currentSong?.artist ?? "Select a track to start")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(width: 180, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Center Controls & Timeline
            VStack(spacing: 4) {
                HStack(spacing: 24) {
                    Button {
                        queue.toggleShuffle()
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 14))
                            .foregroundColor(queue.isShuffleEnabled ? .appleMusicRed : .secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        player.skipToPrevious()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        player.togglePlayPause()
                    } label: {
                        if player.status == .loading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.0)
                                .frame(width: 34, height: 34)
                        } else {
                            Image(systemName: player.status == .playing ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 34))
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        player.skipToNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        queue.cycleRepeatMode()
                    } label: {
                        Image(systemName: queue.playMode == .repeatOne ? "repeat.1" : "repeat")
                            .font(.system(size: 14))
                            .foregroundColor(queue.playMode != .sequence ? .appleMusicRed : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                // Scrubber
                HStack(spacing: 8) {
                    Text(formatTime(isScrubbing ? scrubTime : progress.currentTime))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                    
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
                            }
                        }
                    )
                    .tint(.primary)
                    
                    let remaining = max(0, progress.duration - (isScrubbing ? scrubTime : progress.currentTime))
                    Text("-\(formatTime(remaining))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .leading)
                }
                .frame(maxWidth: 420)
            }
            
            Spacer()
            
            // Right Accessories: Volume + Queue
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Slider(
                    value: Binding(
                        get: { player.volume },
                        set: { player.volume = $0 }
                    ),
                    in: 0...1
                )
                .frame(width: 90)
                .tint(.secondary)
                
                Button {
                    showQueue.toggle()
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16))
                        .foregroundColor(showQueue ? .appleMusicRed : .secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showQueue) {
                    iOSQueueSheet()
                        .frame(width: 340, height: 420)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(Color.platformWindowBackground)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        guard !seconds.isNaN && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Side-by-Side iPad Modal (Cover + Real-time Scrolling Lyrics)
public struct iPadNowPlayingSideBySideView: View {
    @ObservedObject var player = AudioPlayerEngine.shared
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            HStack(spacing: 40) {
                // Left: Big Cover
                VStack(spacing: 20) {
                    Spacer()
                    if let song = player.currentSong {
                        CoverImageView(url: song.effectiveCoverUrl) {
                            ZStack {
                                Color.secondary.opacity(0.12)
                                Image(systemName: "music.note")
                                    .font(.system(size: 80))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 320, height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                        
                        VStack(spacing: 6) {
                            Text(song.title)
                                .font(.title2.bold())
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text("\(song.artist) — \(song.album)")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: 400)
                .padding(.leading, 30)
                
                Divider()
                
                // Right: Real-time Lyrics
                VStack {
                    LyricsView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.trailing, 20)
            }
            .navigationTitle("Now Playing")
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
