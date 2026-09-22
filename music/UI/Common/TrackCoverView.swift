import SwiftUI
import AppKit

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
            if coverUrl.isFileURL, let localImg = NSImage(contentsOf: coverUrl) {
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
