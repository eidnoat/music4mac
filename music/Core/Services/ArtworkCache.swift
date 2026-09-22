import Foundation
import AppKit
import AVFoundation
import ImageIO

public final class ArtworkCache {
    public static let shared = ArtworkCache()
    
    private let cache = NSCache<NSString, NSImage>()
    private let noArtworkCache = NSCache<NSString, NSNumber>()
    
    private init() {
        // Cache up to 100 thumbnails, max 30 MB RAM to keep footprint minimal
        cache.countLimit = 100
        cache.totalCostLimit = 30 * 1024 * 1024
        noArtworkCache.countLimit = 2000
    }
    
    public func image(for path: String) -> NSImage? {
        return cache.object(forKey: path as NSString)
    }
    
    public func setImage(_ image: NSImage, for path: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: path as NSString, cost: cost)
        noArtworkCache.removeObject(forKey: path as NSString)
    }
    
    public func clearCache() {
        cache.removeAllObjects()
        noArtworkCache.removeAllObjects()
    }
    
    private var inFlightTasks: [String: Task<Data?, Never>] = [:]
    
    /// Loads artwork for audio file at path, downsampled to target size via ImageIO to minimize CPU & memory footprint
    @MainActor
    public func loadArtwork(for path: String, maxPixelSize: CGFloat = 300) async -> NSImage? {
        if let cached = image(for: path) {
            return cached
        }
        if noArtworkCache.object(forKey: path as NSString) != nil {
            return nil
        }
        
        let rawData: Data?
        if let inFlight = inFlightTasks[path] {
            rawData = await inFlight.value
        } else {
            let task = Task.detached(priority: .utility) { () -> Data? in
                let url = URL(fileURLWithPath: path)
                let asset = AVURLAsset(url: url)
                guard let metadata = try? await asset.load(.commonMetadata) else {
                    return nil
                }
                
                for item in metadata {
                    if item.commonKey == .commonKeyArtwork,
                       let data = try? await item.load(.dataValue) {
                        return data
                    }
                }
                return nil
            }
            inFlightTasks[path] = task
            rawData = await task.value
            inFlightTasks.removeValue(forKey: path)
        }
        
        if let cached = image(for: path) {
            return cached
        }
        
        guard let data = rawData else {
            self.noArtworkCache.setObject(1, forKey: path as NSString)
            return nil
        }
        
        let finalImage: NSImage?
        if let downsampled = self.createThumbnail(from: data, maxPixelSize: maxPixelSize) {
            finalImage = downsampled
        } else {
            finalImage = NSImage(data: data)
        }
        
        if let image = finalImage {
            self.setImage(image, for: path)
            return image
        } else {
            self.noArtworkCache.setObject(1, forKey: path as NSString)
            return nil
        }
    }
    
    /// High-performance downsampling directly from compressed data without full image buffer allocation
    private func createThumbnail(from data: Data, maxPixelSize: CGFloat) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }
        
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
