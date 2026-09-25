import SwiftUI

public struct ArtistListView: View {
    public let artists: [Artist]
    @ObservedObject var nav = NavigationCoordinator.shared
    @ObservedObject var storage = StorageManager.shared
    
    public init(artists: [Artist]) {
        self.artists = artists
    }
    
    private var displayedArtists: [Artist] {
        let query = nav.searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty {
            return storage.artists
        }
        return storage.artists.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }
    
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
                ArtistDetailView(artist: selected)
            } else {
                Text("Select an artist from the left")
                    .foregroundColor(.secondary)
            }
        }
    }
}

public struct ArtistDetailView: View {
    public let artist: Artist
    @ObservedObject var storage = StorageManager.shared
    
    public init(artist: Artist) {
        self.artist = artist
    }
    
    private var currentArtist: Artist {
        storage.artists.first(where: { $0.id == artist.id }) ?? artist
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentArtist.name)
                        .font(.title2.bold())
                    Text("\(currentArtist.albumCount) albums · \(currentArtist.songs.count) tracks")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    if !currentArtist.songs.isEmpty {
                        AudioPlayerEngine.shared.playSong(currentArtist.songs[0], in: currentArtist.songs)
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
            
            SongListView(title: "", songs: currentArtist.songs, allowSorting: false)
                .id("artist_songs_\(currentArtist.id)_\(currentArtist.songs.count)")
        }
        .navigationTitle(currentArtist.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
