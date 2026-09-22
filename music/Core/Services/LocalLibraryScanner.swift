import Foundation
import AVFoundation
import AppKit

public final class LocalLibraryScanner {
    public static let shared = LocalLibraryScanner()
    
    private let supportedExtensions: Set<String> = [
        "mp3", "flac", "m4a", "wav", "aac", "aif", "aiff", "ogg", "opus", "ape", "alac"
    ]
    
    private init() {}
    
    private func collectAudioUrls(at url: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }
        
        var audioUrls: [URL] = []
        while let fileUrl = enumerator.nextObject() as? URL {
            if supportedExtensions.contains(fileUrl.pathExtension.lowercased()) {
                audioUrls.append(fileUrl)
            }
        }
        return audioUrls
    }
    
    /// Scans a directory recursively and returns parsed Song models
    public func scanDirectory(at url: URL, progress: ((Double, String) -> Void)? = nil) async -> [Song] {
        let isAccessing = BookmarkManager.shared.startAccessing(url: url)
        defer {
            if isAccessing {
                // Keep access active for library playback
            }
        }
        
        let audioUrls = collectAudioUrls(at: url)
        let total = Double(max(audioUrls.count, 1))
        
        let maxConcurrent = 8
        var indexedSongs: [(Int, Song)] = []
        indexedSongs.reserveCapacity(audioUrls.count)
        
        await withTaskGroup(of: (Int, Song).self) { group in
            var submitted = 0
            
            for (index, fileUrl) in audioUrls.enumerated() {
                if submitted >= maxConcurrent {
                    if let (idx, song) = await group.next() {
                        indexedSongs.append((idx, song))
                        if indexedSongs.count % 20 == 0 {
                            progress?(Double(indexedSongs.count) / total, song.title)
                        }
                    }
                }
                
                group.addTask {
                    let song = await self.parseAudioFile(at: fileUrl)
                    return (index, song)
                }
                submitted += 1
            }
            
            while let (idx, song) = await group.next() {
                indexedSongs.append((idx, song))
                if indexedSongs.count % 20 == 0 {
                    progress?(Double(indexedSongs.count) / total, song.title)
                }
            }
        }
        
        progress?(1.0, "Complete")
        return indexedSongs.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
    }
    
    public func parseAudioFile(at fileUrl: URL) async -> Song {
        let id = fileUrl.path
        let asset = AVURLAsset(url: fileUrl)
        
        var title = fileUrl.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        var albumArtist: String?
        var genre: String?
        var year: Int?
        var trackNumber: Int?
        var discNumber: Int?
        var lyrics: String?
        
        var duration: TimeInterval = 0
        if let dur = try? await asset.load(.duration) {
            duration = CMTimeGetSeconds(dur)
        }
        
        if let metadata = try? await asset.load(.commonMetadata) {
            for item in metadata {
                guard let commonKey = item.commonKey else { continue }
                if let stringValue = try? await item.load(.stringValue) {
                    switch commonKey {
                    case .commonKeyTitle: title = stringValue
                    case .commonKeyArtist: artist = stringValue
                    case .commonKeyAlbumName: album = stringValue
                    case .commonKeyType: genre = stringValue
                    default: break
                    }
                }
            }
        }
        
        if let allMetadata = try? await asset.load(.metadata) {
            for item in allMetadata {
                let keyStr = (item.key as? String) ?? item.identifier?.rawValue ?? ""
                if let stringValue = try? await item.load(.stringValue) {
                    if keyStr.contains("year") || keyStr.contains("date") {
                        let digits = stringValue.prefix(4)
                        year = Int(digits)
                    } else if keyStr.contains("track") {
                        trackNumber = Int(stringValue.components(separatedBy: "/").first ?? "")
                    } else if keyStr.contains("disc") {
                        discNumber = Int(stringValue.components(separatedBy: "/").first ?? "")
                    } else if keyStr.contains("lyrics") || keyStr.contains("USLT") {
                        lyrics = stringValue
                    } else if keyStr.contains("albumArtist") || keyStr.contains("TPE2") {
                        albumArtist = stringValue
                    }
                }
            }
        }
        
        // Look for external .lrc file if no embedded lyrics
        if lyrics == nil || lyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            let lrcUrl = fileUrl.deletingPathExtension().appendingPathExtension("lrc")
            if FileManager.default.fileExists(atPath: lrcUrl.path),
               let lrcContent = try? String(contentsOf: lrcUrl, encoding: .utf8) {
                lyrics = lrcContent
            } else if FileManager.default.fileExists(atPath: lrcUrl.path),
                      let lrcContent = try? String(contentsOf: lrcUrl, encoding: .gb18030) {
                lyrics = lrcContent
            }
        }
        
        let ext = fileUrl.pathExtension.lowercased()
        let resValues = try? fileUrl.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        let dateAdded = resValues?.creationDate ?? resValues?.contentModificationDate
        
        return Song(
            id: id,
            title: title,
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            genre: genre,
            year: year,
            trackNumber: trackNumber,
            discNumber: discNumber,
            duration: duration,
            bitrate: nil,
            sampleRate: nil,
            format: ext,
            source: .local,
            localPath: fileUrl.path,
            coverUrl: nil,
            coverId: nil,
            lyrics: lyrics,
            dateAdded: dateAdded
        )
    }
}

extension String.Encoding {
    static let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
}
