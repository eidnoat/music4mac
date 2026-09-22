import Foundation

public final class BookmarkManager {
    public static let shared = BookmarkManager()
    
    private let fileName = "directory_inventory.json"
    private var inventory: [String: String] = [:] // Folder Path : Bookmark Base64
    private var activeUrls: [String: URL] = [:]
    private let storageUrl: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let musicDir = appSupport.appendingPathComponent("music", isDirectory: true)
        let oldDir = appSupport.appendingPathComponent("Sylvakru", isDirectory: true)
        if !FileManager.default.fileExists(atPath: musicDir.path) {
            if FileManager.default.fileExists(atPath: oldDir.path) {
                try? FileManager.default.moveItem(at: oldDir, to: musicDir)
            } else {
                try? FileManager.default.createDirectory(at: musicDir, withIntermediateDirectories: true)
            }
        }
        self.storageUrl = musicDir.appendingPathComponent(fileName)
        loadInventory()
    }
    
    private func loadInventory() {
        guard let data = try? Data(contentsOf: storageUrl),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            inventory = [:]
            return
        }
        inventory = dict
    }
    
    private func saveInventory() {
        if let data = try? JSONEncoder().encode(inventory) {
            try? data.write(to: storageUrl, options: .atomic)
        }
    }
    
    public func saveBookmark(for url: URL) -> Bool {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            let base64 = bookmarkData.base64EncodedString()
            inventory[url.path] = base64
            saveInventory()
            _ = startAccessing(url: url)
            return true
        } catch {
            print("[BookmarkManager] Failed to create bookmark for \(url.path): \(error)")
            return false
        }
    }
    
    public func removeBookmark(for url: URL) {
        stopAccessing(url: url)
        inventory.removeValue(forKey: url.path)
        saveInventory()
    }
    
    public func startAccessingAllSavedDirectories() -> [URL] {
        var validUrls: [URL] = []
        for (path, base64) in inventory {
            guard let data = Data(base64Encoded: base64) else { continue }
            var isStale = false
            do {
                let resolvedUrl = try URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                if resolvedUrl.startAccessingSecurityScopedResource() {
                    activeUrls[path] = resolvedUrl
                    validUrls.append(resolvedUrl)
                    if isStale {
                        _ = saveBookmark(for: resolvedUrl)
                    }
                }
            } catch {
                print("[BookmarkManager] Failed to resolve bookmark for \(path): \(error)")
            }
        }
        return validUrls
    }
    
    public func startAccessing(url: URL) -> Bool {
        if activeUrls[url.path] != nil {
            return true
        }
        let success = url.startAccessingSecurityScopedResource()
        if success {
            activeUrls[url.path] = url
        }
        return success
    }
    
    // Dedicated single-track security scope tracking to avoid accumulating hundreds of open file tokens
    private var currentTrackUrl: URL?
    
    public func startAccessingTrack(url: URL) -> Bool {
        if let prev = currentTrackUrl, prev.path != url.path {
            stopAccessingTrack()
        }
        currentTrackUrl = url
        return startAccessing(url: url)
    }
    
    public func stopAccessingTrack() {
        if let track = currentTrackUrl {
            stopAccessing(url: track)
            currentTrackUrl = nil
        }
    }
    
    public func stopAccessing(url: URL) {
        if let active = activeUrls.removeValue(forKey: url.path) {
            active.stopAccessingSecurityScopedResource()
        }
    }
    
    deinit {
        stopAccessingTrack()
        for (_, url) in activeUrls {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
