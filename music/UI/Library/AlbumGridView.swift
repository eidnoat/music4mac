import SwiftUI
#if os(iOS)
import UIKit
#endif

public struct AlbumGridView: View {
    public let albums: [Album]
    @ObservedObject var nav = NavigationCoordinator.shared
    @ObservedObject var storage = StorageManager.shared
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 20)
    ]
    
    public init(albums: [Album]) {
        self.albums = albums
    }
    
    private var displayedAlbums: [Album] {
        let query = nav.searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty {
            return storage.albums
        }
        return storage.albums.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.artist.localizedCaseInsensitiveContains(query)
        }
    }
    
    public var body: some View {
        Group {
            if let selected = nav.selectedAlbum {
                let currentAlbum = storage.albums.first(where: { $0.id == selected.id }) ?? selected
                AlbumDetailView(album: currentAlbum) {
                    nav.selectedAlbum = nil
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(displayedAlbums) { album in
                            AlbumCard(album: album)
                                .onTapGesture {
                                    nav.selectedAlbum = album
                                }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
        }
    }
}

public struct AlbumCard: View {
    let album: Album
    @State private var isHovered = false
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                CoverImageView(url: album.effectiveCoverUrl) {
                    ZStack {
                        Color.secondary.opacity(0.1)
                        Image(systemName: "square.stack")
                            .font(.system(size: 30))
                            .foregroundColor(.secondary)
                    }
                }
                
                if isHovered {
                    Button {
                        if !album.songs.isEmpty {
                            AudioPlayerEngine.shared.playSong(album.songs[0], in: album.songs)
                        }
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.accentColor)
                            .background(Circle().fill(.black.opacity(0.4)))
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 150, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(isHovered ? 0.25 : 0.1), radius: isHovered ? 8 : 4, x: 0, y: isHovered ? 4 : 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                
                Text(album.artist)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 150, alignment: .leading)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

public struct AlbumDetailView: View {
    public let album: Album
    public let onBack: () -> Void
    
    @ObservedObject private var player = AudioPlayerEngine.shared
    @ObservedObject private var queue = PlayQueueManager.shared
    @ObservedObject private var cacheManager = SongCacheManager.shared
    
    public init(album: Album, onBack: @escaping () -> Void = {}) {
        self.album = album
        self.onBack = onBack
    }
    
    private var totalDurationString: String {
        let total = album.songs.reduce(0) { $0 + $1.duration }
        guard total > 0 else { return "" }
        let mins = Int(total) / 60
        if mins < 60 {
            return "\(mins) mins"
        } else {
            let hrs = mins / 60
            let remMins = mins % 60
            if remMins == 0 {
                return "\(hrs) hr"
            } else {
                return "\(hrs) hr \(remMins) mins"
            }
        }
    }
    
    public var body: some View {
        List {
            // 1. Album Header Section
            Section {
                albumHeaderView
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            
            // 2. Tracks Section
            Section {
                ForEach(Array(album.songs.enumerated()), id: \.element.id) { index, song in
                    albumSongRow(song: song, index: index)
                }
            }
        }
        .listStyle(.plain)
        #if os(iOS)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 70) // Prevent content from being hidden by floating mini player
        }
        .navigationTitle(album.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    // MARK: - Album Header
    private var albumHeaderView: some View {
        VStack(spacing: 0) {
            #if os(macOS)
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Albums")
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            #elseif os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Albums")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.appleMusicRed)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }
            #endif
            
            VStack(spacing: 12) {
                // Large Centered Cover
                CoverImageView(url: album.effectiveCoverUrl) {
                    ZStack {
                        Color.secondary.opacity(0.12)
                        Image(systemName: "square.stack")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 190, height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
                .padding(.top, 8)
                
                // Title
                Text(album.title)
                    .font(.system(size: 20, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 24)
                
                // Artist
                Button {
                    NavigationCoordinator.shared.navigateToArtist(named: album.artist)
                } label: {
                    Text(album.artist)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.appleMusicRed)
                }
                .buttonStyle(.plain)
                
                // Metadata (Year, Track count, Total duration)
                HStack(spacing: 4) {
                    if let year = album.year {
                        Text("\(year) ·")
                    }
                    Text("\(album.songs.count) tracks")
                    if !totalDurationString.isEmpty {
                        Text("· \(totalDurationString)")
                    }
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                
                // Action Buttons: Play & Shuffle
                HStack(spacing: 14) {
                    Button {
                        if !album.songs.isEmpty {
                            queue.isShuffleEnabled = false
                            player.playSong(album.songs[0], in: album.songs)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                            Text("Play")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.appleMusicRed)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        if !album.songs.isEmpty {
                            queue.isShuffleEnabled = true
                            let randomSong = album.songs.randomElement() ?? album.songs[0]
                            player.playSong(randomSong, in: album.songs)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 14))
                            Text("Shuffle")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.appleMusicRed)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Song Row
    private func albumSongRow(song: Song, index: Int) -> some View {
        let isCurrent = player.currentSong?.id == song.id
        let isPlaying = isCurrent && player.status == .playing
        let isCached = cacheManager.isSongCached(id: song.id)
        
        return Button {
            player.playSong(song, in: album.songs)
        } label: {
            HStack(spacing: 12) {
                // 1. Track Number or Playing Waveform
                ZStack(alignment: .center) {
                    if isPlaying {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(.appleMusicRed)
                            .font(.system(size: 13))
                    } else {
                        Text("\(song.trackNumber ?? (index + 1))")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(isCurrent ? .appleMusicRed : .secondary)
                    }
                }
                .frame(width: 24, alignment: .center)
                
                // 2. Track Title & Optional Guest Artist
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
                    
                    if !song.artist.isEmpty && song.artist.localizedCaseInsensitiveCompare(album.artist) != .orderedSame {
                        Text(song.artist)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // 3. Trailing Status (Duration or Loading spinner)
                ZStack(alignment: .trailing) {
                    if isCurrent && player.status == .loading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.85)
                    } else if cacheManager.downloadingIds.contains(song.id) && !isPlaying {
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
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
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
                    Label("Download", systemImage: "arrow.down.circle")
                }
                .tint(.appleMusicRed)
            }
        }
        .contextMenu {
            Button {
                player.playSong(song, in: album.songs)
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            if isCached {
                Button(role: .destructive) {
                    cacheManager.removeSong(id: song.id)
                } label: {
                    Label("Remove Download", systemImage: "trash")
                }
            } else {
                Button {
                    cacheManager.startAutoCache(for: song)
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
            }
        }
    }
}
