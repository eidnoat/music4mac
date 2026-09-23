import SwiftUI

public enum NavigationItem: Hashable {
    case songs
    case albums
    case artists
    case settings
}

public struct SidebarView: View {
    @Binding var selection: NavigationItem?
    
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
