#if os(iOS)
import SwiftUI

public struct iOSMiniPlayerBar: View {
    @ObservedObject var player = AudioPlayerEngine.shared
    let onTap: () -> Void
    
    public init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }
    
    public var body: some View {
        if let song = player.currentSong {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    TrackCoverView(song: song, size: 44, cornerRadius: 8)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(song.artist)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.status == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        player.skipToNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 3)
                )
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
#endif
