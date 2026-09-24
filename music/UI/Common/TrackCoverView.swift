import SwiftUI
import ImageIO

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

public typealias LocalCoverCache = CoverImageCache

public final class CoverImageCache: @unchecked Sendable {
    public static let shared = CoverImageCache()
    private let cache = NSCache<NSURL, PlatformImage>()
    private let maxThumbnailPixelSize: CGFloat = 320
    private let lock = NSLock()
    private var inFlightTasks: [URL: Task<PlatformImage?, Never>] = [:]
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 30.0
        config.urlCache = nil
        return URLSession(configuration: config)
    }()
    
    public init() {
        // Thumbnail size is max 320x320 px (~400KB decoded per image).
        // Restrict to 80 items and 20MB maximum memory usage to avoid memory growth over time.
        cache.countLimit = 80
        cache.totalCostLimit = 20 * 1024 * 1024
    }
    
    /// Synchronously returns cached image if already decoded in memory, or decodes local file URLs with downsampling.
    public func cachedImage(for url: URL) -> PlatformImage? {
        let nsUrl = url as NSURL
        if let cached = cache.object(forKey: nsUrl) {
            return cached
        }
        
        guard url.isFileURL else { return nil }
        return downsample(fileUrl: url)
    }
    
    /// Backward-compatible synchronous lookup for local URLs
    public func image(for url: URL) -> PlatformImage? {
        return cachedImage(for: url)
    }
    
    /// Asynchronously loads and downsamples image (supports local file URLs and remote HTTP/HTTPS URLs).
    public func loadImage(for url: URL) async -> PlatformImage? {
        let nsUrl = url as NSURL
        if let cached = cache.object(forKey: nsUrl) {
            return cached
        }
        
        if url.isFileURL {
            return downsample(fileUrl: url)
        }
        
        // Coalesce duplicate in-flight requests for the same URL
        if let existing = getInFlightTask(for: url) {
            return await existing.value
        }
        
        let newTask = Task<PlatformImage?, Never> { [session, weak self] in
            guard let self = self else { return nil }
            defer {
                self.removeInFlightTask(for: url)
            }
            
            do {
                let (data, response) = try await session.data(from: url)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    return nil
                }
                guard !data.isEmpty else { return nil }
                return self.downsample(data: data, for: url)
            } catch {
                return nil
            }
        }
        
        setInFlightTask(newTask, for: url)
        return await newTask.value
    }
    
    private func getInFlightTask(for url: URL) -> Task<PlatformImage?, Never>? {
        lock.lock()
        defer { lock.unlock() }
        return inFlightTasks[url]
    }
    
    private func setInFlightTask(_ task: Task<PlatformImage?, Never>, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        inFlightTasks[url] = task
    }
    
    private func removeInFlightTask(for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        inFlightTasks.removeValue(forKey: url)
    }
    
    private func downsample(fileUrl: URL) -> PlatformImage? {
        let nsUrl = fileUrl as NSURL
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(fileUrl as CFURL, sourceOptions) else {
            return nil
        }
        return createThumbnail(from: source, key: nsUrl)
    }
    
    private func downsample(data: Data, for url: URL) -> PlatformImage? {
        let nsUrl = url as NSURL
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        return createThumbnail(from: source, key: nsUrl)
    }
    
    private func createThumbnail(from source: CGImageSource, key: NSURL) -> PlatformImage? {
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxThumbnailPixelSize
        ]
        
        if let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) {
            #if os(macOS)
            let img = NSImage(cgImage: cgThumb, size: NSSize(width: cgThumb.width, height: cgThumb.height))
            #elseif os(iOS)
            let img = UIImage(cgImage: cgThumb)
            #endif
            let cost = cgThumb.bytesPerRow * cgThumb.height
            cache.setObject(img, forKey: key, cost: cost)
            return img
        }
        return nil
    }
    
    public func removeImage(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }
    
    public func clear() {
        cache.removeAllObjects()
    }
}

public struct CoverImageView<Placeholder: View>: View {
    public let url: URL?
    public let contentMode: ContentMode
    private let placeholder: () -> Placeholder
    
    @State private var loadedImage: PlatformImage?
    
    public init(
        url: URL?,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder
        if let url = url, let cached = CoverImageCache.shared.cachedImage(for: url) {
            _loadedImage = State(initialValue: cached)
        }
    }
    
    public var body: some View {
        Group {
            if let image = loadedImage {
                Image(platformImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url = url else {
                loadedImage = nil
                return
            }
            if let cached = CoverImageCache.shared.cachedImage(for: url) {
                loadedImage = cached
                return
            }
            let img = await CoverImageCache.shared.loadImage(for: url)
            if !Task.isCancelled {
                loadedImage = img
            }
        }
    }
}

extension CoverImageView where Placeholder == Color {
    public init(url: URL?, contentMode: ContentMode = .fill) {
        self.init(url: url, contentMode: contentMode) {
            Color.secondary.opacity(0.1)
        }
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
        CoverImageView(url: song?.effectiveCoverUrl) {
            fallbackCover
        }
        .id(song?.id)
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
