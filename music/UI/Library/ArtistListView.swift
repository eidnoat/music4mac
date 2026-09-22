import SwiftUI

public struct ArtistListView: View {
    public let artists: [Artist]
    @ObservedObject var nav = NavigationCoordinator.shared
    
    public init(artists: [Artist]) {
        self.artists = artists
    }
    
    public var body: some View {
        NavigationSplitView {
            ScrollViewReader { proxy in
                List(artists, selection: $nav.selectedArtist) { artist in
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
                .navigationTitle("Artists")
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
            if let artist = nav.selectedArtist {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(artist.name)
                                .font(.title2.bold())
                            Text("\(artist.albumCount) albums · \(artist.songs.count) tracks")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            if !artist.songs.isEmpty {
                                AudioPlayerEngine.shared.playSong(artist.songs[0], in: artist.songs)
                            }
                        } label: {
                            Label("Play All", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
                    Divider()
                    
                    SongListView(title: "", songs: artist.songs)
                }
            } else {
                Text("Select an artist from the left")
                    .foregroundColor(.secondary)
            }
        }
    }
}
