import SwiftUI

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
                if let url = album.effectiveCoverUrl {
                    if url.isFileURL, let localImg = LocalCoverCache.shared.image(for: url) {
                        Image(nsImage: localImg)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.secondary.opacity(0.1)
                        }
                    }
                } else {
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
    let album: Album
    let onBack: () -> Void
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                
                Group {
                    if let url = album.effectiveCoverUrl {
                        if url.isFileURL, let localImg = LocalCoverCache.shared.image(for: url) {
                            Image(nsImage: localImg)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            AsyncImage(url: url) { img in
                                img.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: { Color.secondary.opacity(0.1) }
                        }
                    } else {
                        Color.secondary.opacity(0.1)
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(album.title)
                        .font(.title2.bold())
                    Button {
                        NavigationCoordinator.shared.navigateToArtist(named: album.artist)
                    } label: {
                        Text(album.artist)
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    HStack(spacing: 8) {
                        if let year = album.year {
                            Text("\(year)")
                        }
                        Text("\(album.songs.count) tracks")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
                
                Button {
                    if !album.songs.isEmpty {
                        AudioPlayerEngine.shared.playSong(album.songs[0], in: album.songs)
                    }
                } label: {
                    Label("Play Album", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            Divider()
            
            SongListView(title: "", songs: album.songs)
                .id("album_songs_\(album.id)_\(album.songs.count)")
        }
    }
}
