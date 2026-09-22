import SwiftUI

public enum NavigationItem: Hashable {
    case songs
    case albums
    case artists
    case recentlyPlayed
    case navidrome
    case settings
}

public struct SidebarView: View {
    @Binding var selection: NavigationItem?
    @ObservedObject var navidrome = NavidromeClient.shared
    
    public init(selection: Binding<NavigationItem?>) {
        self._selection = selection
    }
    
    public var body: some View {
        List(selection: $selection) {
            Section("Library") {
                NavigationLink(value: NavigationItem.songs) {
                    Label("Tracks", systemImage: "music.note.list")
                }
                
                NavigationLink(value: NavigationItem.albums) {
                    Label("Albums", systemImage: "square.stack")
                }
                
                NavigationLink(value: NavigationItem.artists) {
                    Label("Artists", systemImage: "person.2")
                }
                
                NavigationLink(value: NavigationItem.recentlyPlayed) {
                    Label("Recently Played", systemImage: "clock")
                }
            }
            
            Section("Remote") {
                NavigationLink(value: NavigationItem.navidrome) {
                    HStack {
                        Label("Navidrome", systemImage: "server.rack")
                        Spacer()
                        Circle()
                            .fill(navidrome.isConnected ? Color.green : Color.gray.opacity(0.5))
                            .frame(width: 7, height: 7)
                    }
                }
            }
            
            Section("Preferences") {
                NavigationLink(value: NavigationItem.settings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .listStyle(.sidebar)
    }
}
