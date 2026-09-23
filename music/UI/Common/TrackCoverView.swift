import SwiftUI
import AppKit
import ImageIO

public final class LocalCoverCache: @unchecked Sendable {
    public static let shared = LocalCoverCache()
    private let cache = NSCache<NSURL, NSImage>()
    private let maxThumbnailPixelSize: CGFloat = 320
    
    public init() {
        // Thumbnail size is max 320x320 px (~400KB decoded per image).
        // Restrict to 60 items and 16MB maximum memory usage to avoid memory growth over time.
        cache.countLimit = 60
        cache.totalCostLimit = 16 * 1024 * 1024
    }
    
    public func image(for url: URL) -> NSImage? {
        let nsUrl = url as NSURL
        if let cached = cache.object(forKey: nsUrl) {
            return cached
        }
        
        // Use ImageIO to downsample at decode time without loading the full-resolution bitmap into RAM
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            return nil
        }
        
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxThumbnailPixelSize
        ]
        
        if let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) {
            let img = NSImage(cgImage: cgThumb, size: NSSize(width: cgThumb.width, height: cgThumb.height))
            let cost = cgThumb.bytesPerRow * cgThumb.height
            cache.setObject(img, forKey: nsUrl, cost: cost)
            return img
        }
        
        // Fallback for formats not supported by thumbnail generator
        guard let img = NSImage(contentsOf: url) else { return nil }
        let cost = Int(img.size.width * img.size.height * 4)
        cache.setObject(img, forKey: nsUrl, cost: cost)
        return img
    }
    
    public func removeImage(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }
    
    public func clear() {
        cache.removeAllObjects()
    }
}

public struct TrackCoverView: View {
    public let song: Song?
    public let size: CGFloat
    public let cornerRadius: CGFloat
    
    public init(song: Song?, size: CGFloat, cornerRadius: CGFloat = 6) {
        self.song = song
        self.size = size
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        Group {
            if let song = song {
                coverContent(for: song)
                    .id(song.id)
            } else {
                fallbackCover
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
    
    @ViewBuilder
    private func coverContent(for song: Song) -> some View {
        if let coverUrl = song.effectiveCoverUrl {
            if coverUrl.isFileURL, let localImg = LocalCoverCache.shared.image(for: coverUrl) {
                Image(nsImage: localImg)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                AsyncImage(url: coverUrl, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .empty, .failure:
                        fallbackCover
                    @unknown default:
                        fallbackCover
                    }
                }
            }
        } else {
            fallbackCover
        }
    }
    
    private var fallbackCover: some View {
        ZStack {
            Color.secondary.opacity(0.12)
            Image(systemName: "music.note")
                .foregroundColor(.secondary.opacity(0.8))
                .font(.system(size: max(14, size * 0.4)))
        }
    }
}
