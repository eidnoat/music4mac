import Foundation

public final class BookmarkManager: @unchecked Sendable {
    public static let shared = BookmarkManager()
    
    private let lock = NSRecursiveLock()
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
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: storageUrl),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            inventory = [:]
            return
        }
        inventory = dict
    }
    
    private func saveInventory() {
        lock.lock()
        let dict = inventory
        lock.unlock()
        if let data = try? JSONEncoder().encode(dict) {
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
            lock.lock()
            inventory[url.path] = base64
            lock.unlock()
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
        lock.lock()
        inventory.removeValue(forKey: url.path)
        lock.unlock()
        saveInventory()
    }
    
    public func startAccessingAllSavedDirectories() -> [URL] {
        lock.lock()
        let items = inventory
        lock.unlock()
        
        var validUrls: [URL] = []
        for (path, base64) in items {
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
                    lock.lock()
                    activeUrls[path] = resolvedUrl
                    lock.unlock()
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
        lock.lock()
        if activeUrls[url.path] != nil {
            lock.unlock()
            return true
        }
        lock.unlock()
        
        let success = url.startAccessingSecurityScopedResource()
        if success {
            lock.lock()
            activeUrls[url.path] = url
            lock.unlock()
        }
        return success
    }
    
    // Dedicated single-track security scope tracking to avoid accumulating hundreds of open file tokens
    private var currentTrackUrl: URL?
    
    public func startAccessingTrack(url: URL) -> Bool {
        lock.lock()
        let prev = currentTrackUrl
        if let prev = prev, prev.path != url.path {
            stopAccessingTrackLocked()
        }
        currentTrackUrl = url
        lock.unlock()
        return startAccessing(url: url)
    }
    
    public func stopAccessingTrack() {
        lock.lock()
        stopAccessingTrackLocked()
        lock.unlock()
    }
    
    private func stopAccessingTrackLocked() {
        if let track = currentTrackUrl {
            stopAccessingLocked(url: track)
            currentTrackUrl = nil
        }
    }
    
    public func stopAccessing(url: URL) {
        lock.lock()
        defer { lock.unlock() }
        stopAccessingLocked(url: url)
    }
    
    private func stopAccessingLocked(url: URL) {
        if let active = activeUrls.removeValue(forKey: url.path) {
            active.stopAccessingSecurityScopedResource()
        }
    }
    
    deinit {
        lock.lock()
        stopAccessingTrackLocked()
        let urls = activeUrls
        activeUrls.removeAll()
        lock.unlock()
        for (_, url) in urls {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
