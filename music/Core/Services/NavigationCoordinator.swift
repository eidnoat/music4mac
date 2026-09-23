import Foundation
import SwiftUI
import Combine

public final class NavigationCoordinator: ObservableObject {
    public static let shared = NavigationCoordinator()
    
    @Published public var selectedSidebarItem: NavigationItem? = .songs
    @Published public var selectedAlbum: Album? = nil
    @Published public var selectedArtist: Artist? = nil
    @Published public var searchText: String = ""
    
    private init() {}
    
    public func showSettings() {
        for window in NSApplication.shared.windows where !(window is NSPanel) {
            window.makeKeyAndOrderFront(nil)
            break
        }
        NSApp.activate(ignoringOtherApps: true)
        self.selectedSidebarItem = .settings
    }
    
    public func navigateToArtist(named artistName: String) {
        let trimmed = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let storage = StorageManager.shared
        // 1. Exact case-insensitive match
        if let artist = storage.artists.first(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            self.selectedArtist = artist
            self.selectedSidebarItem = .artists
            return
        }
        
        // 2. Substring match fallback
        if let artist = storage.artists.first(where: {
            $0.name.localizedCaseInsensitiveContains(trimmed) || trimmed.localizedCaseInsensitiveContains($0.name)
        }) {
            self.selectedArtist = artist
            self.selectedSidebarItem = .artists
        }
    }
    
    public func navigateToAlbum(title albumTitle: String, artist: String? = nil) {
        let trimmedTitle = albumTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        let storage = StorageManager.shared
        let trimmedArtist = artist?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Try match title and artist
        if let trimmedArtist = trimmedArtist, !trimmedArtist.isEmpty {
            if let album = storage.albums.first(where: {
                $0.title.localizedCaseInsensitiveCompare(trimmedTitle) == .orderedSame &&
                ($0.artist.localizedCaseInsensitiveCompare(trimmedArtist) == .orderedSame ||
                 $0.songs.contains { $0.artist.localizedCaseInsensitiveCompare(trimmedArtist) == .orderedSame })
            }) {
                self.selectedAlbum = album
                self.selectedSidebarItem = .albums
                return
            }
        }
        
        // 2. Match title only
        if let album = storage.albums.first(where: { $0.title.localizedCaseInsensitiveCompare(trimmedTitle) == .orderedSame }) {
            self.selectedAlbum = album
            self.selectedSidebarItem = .albums
        }
    }
}
