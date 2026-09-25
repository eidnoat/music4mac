import SwiftUI

public struct DownloadProgressRingView: View {
    public let progress: Double?
    public var size: CGFloat
    public var lineWidth: CGFloat
    public var color: Color
    
    public init(
        progress: Double?,
        size: CGFloat = 14,
        lineWidth: CGFloat = 1.6,
        color: Color = .appleMusicRed
    ) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.color = color
    }
    
    public var body: some View {
        let currentProgress = CGFloat(min(max(progress ?? 0.08, 0.05), 1.0))
        
        ZStack {
            // Background Track Circle
            Circle()
                .stroke(color.opacity(0.25), lineWidth: lineWidth)
            
            // Clockwise Filling Arc starting from 12 o'clock
            Circle()
                .trim(from: 0, to: currentProgress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.15), value: currentProgress)
            
            // Center Stop Square (Apple Music download indicator style)
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: max(size * 0.28, 3.5), height: max(size * 0.28, 3.5))
        }
        .frame(width: size, height: size)
    }
}
