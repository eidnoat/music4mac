#if os(macOS)
import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var currentSong: Song? = AudioPlayerEngine.shared.currentSong
    @State private var isPlaying: Bool = (AudioPlayerEngine.shared.status == .playing)
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 12) {
            // Track Info
            HStack(spacing: 10) {
                TrackCoverView(song: currentSong, size: 42, cornerRadius: 6)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentSong?.title ?? "Not Playing")
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                    Text(currentSong?.artist ?? "music")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            // Transport Controls
            HStack(spacing: 20) {
                Button {
                    AudioPlayerEngine.shared.skipToPrevious()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                
                Button {
                    AudioPlayerEngine.shared.togglePlayPause()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                
                Button {
                    AudioPlayerEngine.shared.skipToNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Actions
            HStack {
                Button("Mini Player") {
                    MiniPlayerPanel.shared.makeKeyAndOrderFront(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.red)
            }
        }
        .padding(14)
        .frame(width: 260)
        .preferredColorScheme(themeManager.effectiveColorScheme)
        .onReceive(AudioPlayerEngine.shared.$currentSong) { self.currentSong = $0 }
        .onReceive(AudioPlayerEngine.shared.$status) { self.isPlaying = ($0 == .playing) }
    }
}
#endif
