import SwiftUI

public struct ArtistListView: View {
    @ObservedObject var nav = NavigationCoordinator.shared
    @ObservedObject var storage = StorageManager.shared

    public init() {}
    
    private var displayedArtists: [Artist] {
        let query = nav.searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty {
            return storage.artists
        }
        return storage.artists.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }
    
    #if os(macOS)
    public var body: some View {
        NavigationSplitView {
            ScrollViewReader { proxy in
                List(displayedArtists, selection: $nav.selectedArtist) { artist in
                    NavigationLink(value: artist) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(artist.name)
                                .font(.system(size: 13, weight: .medium))
                            Text("\(artist.albumCount) albums · \(artist.songCount) tracks")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .id(artist.id)
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
                .onAppear {
                    if let selected = nav.selectedArtist {
                        proxy.scrollTo(selected.id, anchor: .center)
                    }
                }
                .onChange(of: nav.selectedArtist) { _, newArtist in
                    if let newArtist = newArtist {
                        withAnimation {
                            proxy.scrollTo(newArtist.id, anchor: .center)
                        }
                    }
                }
            }
        } detail: {
            if let selected = nav.selectedArtist {
                ArtistDetailView(artist: selected, songs: storage.songs(withIds: selected.songIds))
            } else {
                Text("Select an artist from the left")
                    .foregroundColor(.secondary)
            }
        }
    }
    #else
    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 190), spacing: 24)
    ]
    
    public var body: some View {
        Group {
            if let selected = nav.selectedArtist {
                let currentArtist = storage.artists.first(where: { $0.id == selected.id }) ?? selected
                ArtistDetailView(artist: currentArtist, songs: storage.songs(withIds: currentArtist.songIds)) {
                    nav.selectedArtist = nil
                }
            } else {
                if displayedArtists.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.mic")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text("No Artists Found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(displayedArtists) { artist in
                                ArtistCard(artist: artist)
                                    .onTapGesture {
                                        nav.selectedArtist = artist
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
    #endif
}

public struct ArtistCard: View {
    let artist: Artist
    
    public var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: "music.mic")
                    .font(.system(size: 42))
                    .foregroundColor(.appleMusicRed)
            }
            .shadow(color: .black.opacity(0.06), radius: 5, x: 0, y: 2)
            
            VStack(spacing: 3) {
                Text(artist.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                
                Text("\(artist.albumCount) albums · \(artist.songCount) tracks")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

public struct ArtistDetailView: View {
    public let artist: Artist
    public let songs: [Song]
    public var onBack: (() -> Void)? = nil
    @ObservedObject var storage = StorageManager.shared

    public init(artist: Artist, songs: [Song], onBack: (() -> Void)? = nil) {
        self.artist = artist
        self.songs = songs
        self.onBack = onBack
    }

    private var currentArtist: Artist {
        storage.artists.first(where: { $0.id == artist.id }) ?? artist
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let onBack = onBack {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Artists")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.appleMusicRed)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 6)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentArtist.name)
                        .font(.title2.bold())
                    Text("\(currentArtist.albumCount) albums · \(songs.count) tracks")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    if !songs.isEmpty {
                        AudioPlayerEngine.shared.playSong(songs[0], in: songs)
                    }
                } label: {
                    Label("Play All", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.appleMusicRed)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            
            Divider()
            
            SongListView(title: "", songs: songs, allowSorting: false)
                .id("artist_songs_\(currentArtist.id)_\(songs.count)")
        }
        .navigationTitle(currentArtist.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
