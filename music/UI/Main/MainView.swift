#if os(macOS)
import SwiftUI

public struct MainView: View {
    @ObservedObject var nav = NavigationCoordinator.shared
    @State private var showLyrics: Bool = false
    @State private var showQueue: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var isRefreshing: Bool = false
    
    public init() {}
    
    private let sidePanelWidth: CGFloat = 260
    
    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $nav.selectedSidebarItem)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
                .toolbar {
                    ToolbarItem {
                        Button {
                            refreshServerData()
                        } label: {
                            Group {
                                if #available(macOS 15.0, *) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 12, weight: .medium))
                                        .symbolEffect(.rotate, options: .repeating, isActive: isRefreshing)
                                } else {
                                    if isRefreshing {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                }
                            }
                            .foregroundColor(isRefreshing ? .appleMusicRed : .secondary)
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isRefreshing)
                        .keyboardShortcut("r", modifiers: .command)
                        .help(
                            !NavidromeClient.shared.hasValidCredentials
                                ? "Connect to Navidrome in settings to enable server sync"
                                : (isRefreshing ? "Fetching latest data from server..." : "Refresh library from server (⌘R)")
                        )
                    }
                }
        } detail: {
            HStack(spacing: 0) {
                // Main Content View
                Group {
                    switch nav.selectedSidebarItem {
                    case .songs, .none:
                        SongListView(title: "Tracks", songs: storage.songs)
                            .id("all_songs")
                    case .albums:
                        AlbumGridView(albums: storage.albums)
                            .id("albums")
                    case .artists:
                        ArtistListView(artists: storage.artists)
                            .id("artists")
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Optional Side Lyrics Panel
                if showLyrics {
                    Divider()
                    LyricsView()
                        .frame(width: sidePanelWidth)
                        .transition(.move(edge: .trailing))
                }
                
                // Optional Side Queue Panel
                if showQueue {
                    Divider()
                    QueueSideView()
                        .frame(width: sidePanelWidth)
                        .transition(.move(edge: .trailing))
                }
            }
            .safeAreaInset(edge: .bottom) {
                BottomPlayerBar(
                    showLyrics: $showLyrics,
                    showQueue: $showQueue
                )
            }
            .toolbar {
                ToolbarItem {
                    Spacer()
                }
            }
            .searchable(text: $nav.searchText, placement: .toolbar, prompt: "Search songs, artists, or albums")
        }
        .navigationTitle("music")
        .tint(Color.appleMusicRed)
        .accentColor(Color.appleMusicRed)
        .preferredColorScheme(themeManager.effectiveColorScheme)
        .onChange(of: nav.searchText) { _, newQuery in
            if !newQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                if nav.selectedSidebarItem == .settings {
                    nav.selectedSidebarItem = .songs
                }
            }
        }
        .onChange(of: showLyrics) { _, isShown in
            if isShown { showQueue = false }
        }
        .onChange(of: showQueue) { _, isShown in
            if isShown { showLyrics = false }
        }
        .task {
            // Auto-refresh Navidrome tracks if configured and any tracks are missing dateAdded
            if NavidromeClient.shared.hasValidCredentials &&
                storage.songs.contains(where: { $0.dateAdded == nil }) {
                if let songs = try? await NavidromeClient.shared.getAllSongs(), !songs.isEmpty {
                    await MainActor.run {
                        storage.upsertSongs(songs)
                    }
                }
            }
        }
    }
    
    private func refreshServerData() {
        guard !isRefreshing else { return }
        guard NavidromeClient.shared.hasValidCredentials else {
            nav.selectedSidebarItem = .settings
            return
        }
        
        isRefreshing = true
        Task {
            let startTime = Date()
            do {
                let songs = try await NavidromeClient.shared.getAllSongs()
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed < 0.8 {
                    try? await Task.sleep(nanoseconds: UInt64((0.8 - elapsed) * 1_000_000_000))
                }
                await MainActor.run {
                    storage.upsertSongs(songs)
                    self.isRefreshing = false
                }
            } catch {
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed < 0.8 {
                    try? await Task.sleep(nanoseconds: UInt64((0.8 - elapsed) * 1_000_000_000))
                }
                await MainActor.run {
                    self.isRefreshing = false
                }
            }
        }
    }
}

public struct QueueSideView: View {
    @ObservedObject var queue = PlayQueueManager.shared
    @ObservedObject var cacheManager = SongCacheManager.shared
    @State private var isPlaying: Bool = (AudioPlayerEngine.shared.status == .playing)
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Queue (\(queue.queue.count))")
                    .font(.subheadline.bold())
                Spacer()
                Button("Clear") {
                    queue.queue.removeAll()
                    queue.currentIndex = -1
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            List {
                ForEach(Array(queue.queue.enumerated()), id: \.element.id) { index, song in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text(song.title)
                                    .font(.system(size: 12, weight: index == queue.currentIndex ? .bold : .regular))
                                    .foregroundColor(index == queue.currentIndex ? .appleMusicRed : .primary)
                                    .lineLimit(1)
                                
                                if cacheManager.downloadingIds.contains(song.id) {
                                    DownloadProgressRingView(
                                        progress: cacheManager.downloadProgress[song.id],
                                        size: 10,
                                        lineWidth: 1.4,
                                        color: .appleMusicRed
                                    )
                                    .help("Caching audio...")
                                } else if cacheManager.cachedIds.contains(song.id) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundColor(index == queue.currentIndex ? .appleMusicRed : .secondary)
                                        .font(.system(size: 9))
                                        .help("Cached locally")
                                }
                                
                                if index == queue.currentIndex {
                                    Image(systemName: isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                                        .foregroundColor(.appleMusicRed)
                                        .font(.system(size: 10))
                                }
                            }
                            
                            Text(song.artist)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Text(song.formattedDuration)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        AudioPlayerEngine.shared.loadAndPlay(song: song)
                        queue.currentIndex = index
                    }
                }
                .onDelete { indexSet in
                    for idx in indexSet {
                        queue.remove(at: idx)
                    }
                }
                .onMove { indices, newOffset in
                    queue.move(from: indices, to: newOffset)
                }
            }
            .listStyle(.plain)
        }
        .background(.ultraThinMaterial)
        .onReceive(AudioPlayerEngine.shared.$status) { newStatus in
            let playing = (newStatus == .playing)
            if isPlaying != playing {
                isPlaying = playing
            }
        }
    }
}
#endif
