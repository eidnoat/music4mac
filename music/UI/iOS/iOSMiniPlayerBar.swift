#if os(iOS)
import SwiftUI

public struct iOSMiniPlayerBar: View {
    @ObservedObject var player = AudioPlayerEngine.shared
    @ObservedObject var progress = AudioProgressTracker.shared
    let onTap: () -> Void
    
    public init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }
    
    public var body: some View {
        if let song = player.currentSong {
            Button(action: onTap) {
                VStack(spacing: 0) {
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
                            if player.status == .loading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.9)
                                    .frame(width: 36, height: 36)
                            } else {
                                Image(systemName: player.status == .playing ? "pause.fill" : "play.fill")
                                    .font(.system(size: 19))
                                    .foregroundColor(.appleMusicRed)
                                    .frame(width: 36, height: 36)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            player.skipToNext()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.appleMusicRed)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, progress.duration > 0 ? 6 : 8)
                    
                    // Elegant bottom playback progress bar in Apple Music Red
                    if progress.duration > 0 {
                        let ratio = min(max(progress.currentTime / progress.duration, 0), 1)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(height: 2.5)
                                Capsule()
                                    .fill(Color.appleMusicRed)
                                    .frame(width: geo.size.width * CGFloat(ratio), height: 2.5)
                            }
                        }
                        .frame(height: 2.5)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 3)
                    }
                }
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
