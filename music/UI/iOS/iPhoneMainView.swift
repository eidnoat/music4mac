#if os(iOS)
import SwiftUI

public struct iPhoneMainView: View {
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var player = AudioPlayerEngine.shared
    @ObservedObject var cacheManager = SongCacheManager.shared
    
    @State private var selectedTab = 0
    @State private var librarySegment = 0 // 0: Tracks, 1: Albums, 2: Artists
    @State private var searchText = ""
    @State private var isShowingNowPlaying = false
    @State private var nowPlayingPresentationID = 0
    
    @AppStorage("music.ios.songSortOption") private var songSortOption: SongSortOption = .title
    @AppStorage("music.ios.songSortAscending") private var songSortAscending: Bool = true
    @AppStorage("music.ios.albumSortOption") private var albumSortOption: AlbumSortOption = .title
    @AppStorage("music.ios.albumSortAscending") private var albumSortAscending: Bool = true
    @AppStorage("music.ios.artistSortAscending") private var artistSortAscending: Bool = true
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // Tab 1: Library
                NavigationStack {
                    libraryContent
                        .navigationTitle("Library")
                        .toolbar {
                            ToolbarItem(placement: .principal) {
                                LibrarySegmentPicker(selection: $librarySegment)
                            }
                            
                            ToolbarItem(placement: .navigationBarTrailing) {
                                sortMenu
                            }
                        }
                }
                .tabItem {
                    Label("Library", systemImage: "music.note.house.fill")
                }
                .tag(0)
                
                // Tab 2: Search
                NavigationStack {
                    searchContent
                        .navigationTitle("Search")
                        .searchable(text: $searchText, prompt: "Songs, Artists, Albums")
                }
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)
                
                // Tab 3: Settings
                NavigationStack {
                    SettingsView()
                        .navigationTitle("Settings")
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
            }
            
            // Floating Mini Player docked above the tab bar
            iOSMiniPlayerBar {
                nowPlayingPresentationID += 1
                withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                    isShowingNowPlaying = true
                }
            }
            .padding(.bottom, 54) // Align right above standard TabBar
            
            // Full-screen Now Playing Overlay preserving underlying view visibility during swipe down
            if isShowingNowPlaying {
                iOSNowPlayingView(onDismiss: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isShowingNowPlaying = false
                    }
                })
                .id("ios_now_playing_\(nowPlayingPresentationID)")
                .ignoresSafeArea()
                .transition(.move(edge: .bottom))
                .zIndex(100)
            }
        }
    }
    
    // MARK: - Library Content
    @ViewBuilder
    private var libraryContent: some View {
        switch librarySegment {
        case 0:
            // Tracks List
            let sortedSongs = storage.songs.sorted(by: songSortOption.comparator(ascending: songSortAscending))
            tracksList(songs: sortedSongs)
        case 1:
            // Albums Grid
            let sortedAlbums = storage.albums.sorted(by: albumSortOption.comparator(ascending: albumSortAscending))
            albumsGrid(albums: sortedAlbums)
        default:
            // Artists List
            let sortedArtists = storage.artists.sorted { a, b in
                artistSortAscending
                    ? a.name.localizedStandardCompare(b.name) == .orderedAscending
                    : a.name.localizedStandardCompare(b.name) == .orderedDescending
            }
            artistsList(artists: sortedArtists)
        }
    }
    
    // MARK: - Sort Menu
    private var sortMenu: some View {
        Menu {
            if librarySegment == 0 {
                Picker("Sort By", selection: $songSortOption) {
                    ForEach(SongSortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                
                Picker("Order", selection: $songSortAscending) {
                    Text("Ascending").tag(true)
                    Text("Descending").tag(false)
                }
            } else if librarySegment == 1 {
                Picker("Sort By", selection: $albumSortOption) {
                    ForEach(AlbumSortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                
                Picker("Order", selection: $albumSortAscending) {
                    Text("Ascending").tag(true)
                    Text("Descending").tag(false)
                }
            } else {
                Picker("Order", selection: $artistSortAscending) {
                    Text("Ascending").tag(true)
                    Text("Descending").tag(false)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
                .font(.system(size: 17))
                .foregroundColor(.appleMusicRed)
        }
    }
    
    // MARK: - Search Content
    @ViewBuilder
    private var searchContent: some View {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("Search your Navidrome library")
                    .foregroundColor(.secondary)
                Spacer()
            }
        } else {
            let matchedSongs = storage.songs.filter {
                $0.title.localizedCaseInsensitiveContains(query) ||
                $0.artist.localizedCaseInsensitiveContains(query) ||
                $0.album.localizedCaseInsensitiveContains(query)
            }
            tracksList(songs: matchedSongs)
        }
    }
    
    // MARK: - Tracks List
    private func tracksList(songs: [Song]) -> some View {
        List {
            ForEach(songs) { song in
                let isCurrent = player.currentSong?.id == song.id
                let isCached = cacheManager.isSongCached(id: song.id)
                let isPlaying = isCurrent && player.status == .playing
                
                Button {
                    player.playSong(song, in: songs)
                } label: {
                    HStack(spacing: 12) {
                        // 1. Stable Fixed Cover (44x44)
                        TrackCoverView(song: song, size: 44, cornerRadius: 6)
                        
                        // 2. Stable Title & Artist
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Text(song.title)
                                    .font(.system(size: 15, weight: isCurrent ? .semibold : .regular))
                                    .foregroundColor(isCurrent ? .appleMusicRed : .primary)
                                    .lineLimit(1)
                                
                                if isCached {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                } else if cacheManager.downloadingIds.contains(song.id) {
                                    DownloadProgressRingView(
                                        progress: cacheManager.downloadProgress[song.id],
                                        size: 13,
                                        lineWidth: 1.6
                                    )
                                }
                            }
                            
                            Text("\(song.artist) · \(song.album)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // 3. Stable Fixed Trailing Area (width 48) - Mutually Exclusive
                        ZStack(alignment: .trailing) {
                            if isCurrent && player.status == .loading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.85)
                            } else if isPlaying {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.appleMusicRed)
                                    .font(.system(size: 13))
                            } else {
                                Text(song.formattedDuration)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 48, alignment: .trailing)
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .transaction { $0.animation = nil }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if isCached {
                        Button(role: .destructive) {
                            cacheManager.removeSong(id: song.id)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    } else {
                        Button {
                            cacheManager.downloadSong(song)
                        } label: {
                            Label("Cache", systemImage: "arrow.down.circle")
                        }
                        .tint(.appleMusicRed)
                    }
                    
                    Button {
                        PlayQueueManager.shared.insertNext(song)
                    } label: {
                        Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                    .tint(.purple)
                }
            }
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 70) // Prevent list content from being covered by mini player
        }
    }
    
    // MARK: - Albums Grid
    private func albumsGrid(albums: [Album]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
        
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(albums) { album in
                    NavigationLink {
                        AlbumDetailView(album: album, songs: StorageManager.shared.songs(withIds: album.songIds), onBack: {})
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            CoverImageView(url: album.effectiveCoverUrl) {
                                ZStack {
                                    Color.secondary.opacity(0.12)
                                    Image(systemName: "square.stack")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
                            
                            Text(album.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Text(album.artist)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 80) // Leave space for mini player
        }
    }
    
    // MARK: - Artists List
    private func artistsList(artists: [Artist]) -> some View {
        List {
            ForEach(artists) { artist in
                NavigationLink {
                    ArtistDetailView(artist: artist, songs: StorageManager.shared.songs(withIds: artist.songIds))
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.secondary.opacity(0.12))
                                .frame(width: 44, height: 44)
                            Image(systemName: "music.mic")
                                .font(.system(size: 18))
                                .foregroundColor(.appleMusicRed)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(artist.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text("\(artist.albumCount) albums · \(artist.songCount) tracks")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 70) // Prevent list content from being covered by mini player
        }
    }
}

// MARK: - Library Segment Picker
private struct LibrarySegmentPicker: View {
    @Binding var selection: Int
    @Namespace private var segmentAnimation
    
    private let segments = [
        (0, "Tracks"),
        (1, "Albums"),
        (2, "Artists")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(segments, id: \.0) { tag, title in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        selection = tag
                    }
                } label: {
                    Text(title)
                        .font(.system(size: 13, weight: selection == tag ? .semibold : .medium))
                        .foregroundColor(selection == tag ? .white : .secondary)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 14)
                        .background {
                            if selection == tag {
                                Capsule()
                                    .fill(Color.appleMusicRed)
                                    .matchedGeometryEffect(id: "activeSegmentPill", in: segmentAnimation)
                                    .shadow(color: Color.appleMusicRed.opacity(0.35), radius: 4, x: 0, y: 1.5)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.12))
        )
    }
}
#endif
