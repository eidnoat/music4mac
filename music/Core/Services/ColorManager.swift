import Foundation
import AppKit
import SwiftUI

extension Color {
    public static let appleMusicRed = Color(red: 250.0 / 255.0, green: 45.0 / 255.0, blue: 72.0 / 255.0)
}

extension NSColor {
    public static let appleMusicRed = NSColor(srgbRed: 250.0 / 255.0, green: 45.0 / 255.0, blue: 72.0 / 255.0, alpha: 1.0)
}

public final class ColorManager: ObservableObject {
    public static let shared = ColorManager()
    
    @Published public var dominantColor: Color = Color(nsColor: .windowBackgroundColor)
    @Published public var secondaryColor: Color = Color.appleMusicRed
    @Published public var textColor: Color = .primary
    
    private var lastImage: NSImage?
    
    private init() {}
    
    public func updateColors(from image: NSImage?) {
        guard let image = image else {
            self.lastImage = nil
            DispatchQueue.main.async {
                self.dominantColor = Color(nsColor: .windowBackgroundColor)
                self.secondaryColor = Color.appleMusicRed
                self.textColor = .primary
            }
            return
        }
        
        if lastImage === image {
            return
        }
        lastImage = image
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak image] in
            guard let self = self, let image = image else { return }
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            
            // Downsample to 16x16 to get average colors fast
            let width = 16
            let height = 16
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            var rawData = [UInt8](repeating: 0, count: width * height * 4)
            
            guard let context = CGContext(
                data: &rawData,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            var totalR: CGFloat = 0
            var totalG: CGFloat = 0
            var totalB: CGFloat = 0
            let count = CGFloat(width * height)
            
            for i in 0..<(width * height) {
                let offset = i * 4
                totalR += CGFloat(rawData[offset]) / 255.0
                totalG += CGFloat(rawData[offset + 1]) / 255.0
                totalB += CGFloat(rawData[offset + 2]) / 255.0
            }
            
            let avgR = totalR / count
            let avgG = totalG / count
            let avgB = totalB / count
            
            // Calculate luminance
            let luminance = 0.299 * avgR + 0.587 * avgG + 0.114 * avgB
            let isDark = luminance < 0.5
            
            let dominant = Color(red: avgR, green: avgG, blue: avgB)
            let secondary = Color(red: min(avgR * 1.3, 1.0), green: min(avgG * 1.3, 1.0), blue: min(avgB * 1.3, 1.0))
            let text: Color = isDark ? .white : .black
            
            DispatchQueue.main.async {
                self.dominantColor = dominant
                self.secondaryColor = secondary
                self.textColor = text
            }
        }
    }
}
