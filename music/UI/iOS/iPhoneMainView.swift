#if os(iOS)
import SwiftUI

public struct iPhoneMainView: View {
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var player = AudioPlayerEngine.shared
    @ObservedObject var cacheManager = SongCacheManager.shared
    
    @State private var selectedTab = 0
    @State private var librarySegment = 0 // 0: Tracks, 1: Albums
    @State private var searchText = ""
    @State private var isShowingNowPlaying = false
    
    @AppStorage("music.ios.songSortOption") private var songSortOption: SongSortOption = .title
    @AppStorage("music.ios.songSortAscending") private var songSortAscending: Bool = true
    @AppStorage("music.ios.albumSortOption") private var albumSortOption: AlbumSortOption = .title
    @AppStorage("music.ios.albumSortAscending") private var albumSortAscending: Bool = true
    
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
                                Picker("Library View", selection: $librarySegment) {
                                    Text("Tracks").tag(0)
                                    Text("Albums").tag(1)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 180)
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
                isShowingNowPlaying = true
            }
            .padding(.bottom, 54) // Align right above standard TabBar
        }
        .sheet(isPresented: $isShowingNowPlaying) {
            iOSNowPlayingView()
        }
    }
    
    // MARK: - Library Content
    @ViewBuilder
    private var libraryContent: some View {
        if librarySegment == 0 {
            // Tracks List
            let sortedSongs = storage.songs.sorted(by: songSortOption.comparator(ascending: songSortAscending))
            tracksList(songs: sortedSongs)
        } else {
            // Albums Grid
            let sortedAlbums = storage.albums.sorted(by: albumSortOption.comparator(ascending: albumSortAscending))
            albumsGrid(albums: sortedAlbums)
        }
    }
    
    // MARK: - Sort Menu
    private var sortMenu: some View {
        Menu {
            if librarySegment == 0 {
                Section("Sort By") {
                    ForEach(SongSortOption.allCases) { option in
                        Button {
                            songSortOption = option
                        } label: {
                            HStack {
                                Text(option.title)
                                if songSortOption == option {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button {
                        songSortAscending = true
                    } label: {
                        HStack {
                            Text("Ascending")
                            if songSortAscending {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Button {
                        songSortAscending = false
                    } label: {
                        HStack {
                            Text("Descending")
                            if !songSortAscending {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } else {
                Section("Sort By") {
                    ForEach(AlbumSortOption.allCases) { option in
                        Button {
                            albumSortOption = option
                        } label: {
                            HStack {
                                Text(option.title)
                                if albumSortOption == option {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button {
                        albumSortAscending = true
                    } label: {
                        HStack {
                            Text("Ascending")
                            if albumSortAscending {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Button {
                        albumSortAscending = false
                    } label: {
                        HStack {
                            Text("Descending")
                            if !albumSortAscending {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
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
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.65)
                                        .frame(width: 14, height: 14)
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
                            } else if cacheManager.downloadingIds.contains(song.id) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.85)
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
                            cacheManager.startAutoCache(for: song)
                        } label: {
                            Label("Cache", systemImage: "arrow.down.circle")
                        }
                        .tint(.accentColor)
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
                    NavigationLink(destination: AlbumDetailView(album: album, onBack: {})) {
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
}
#endif
