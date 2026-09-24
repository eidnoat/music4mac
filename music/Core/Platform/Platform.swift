import SwiftUI

#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage
public typealias PlatformColor = NSColor
#elseif os(iOS)
import UIKit
public typealias PlatformImage = UIImage
public typealias PlatformColor = UIColor
#endif

extension PlatformImage {
    public var asCGImage: CGImage? {
        #if os(macOS)
        return self.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #elseif os(iOS)
        return self.cgImage
        #endif
    }
}

extension Image {
    public init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #elseif os(iOS)
        self.init(uiImage: platformImage)
        #endif
    }
}
