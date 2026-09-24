#if os(macOS)
import SwiftUI
import AppKit

public final class MiniPlayerPanel: NSPanel {
    public static let shared = MiniPlayerPanel()
    
    private init() {
        super.init(
            contentRect: NSRect(x: 100, y: 100, width: 320, height: 110),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        
        let hostingView = NSHostingView(rootView: MiniPlayerView())
        self.contentView = hostingView
    }
}

public struct MiniPlayerView: View {
    @ObservedObject var player = AudioPlayerEngine.shared
    @ObservedObject var progress = AudioProgressTracker.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var isHovering = false
    @State private var isPinned = true
    
    public init() {}
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 8) {
                // Top control buttons (Pin / Expand to Main Window)
                if isHovering {
                    HStack {
                        Button {
                            isPinned.toggle()
                            MiniPlayerPanel.shared.level = isPinned ? .floating : .normal
                        } label: {
                            Image(systemName: isPinned ? "pin.fill" : "pin")
                                .font(.system(size: 10))
                                .foregroundColor(isPinned ? .accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Button {
                            MiniPlayerPanel.shared.orderOut(nil)
                            NSApp.activate(ignoringOtherApps: true)
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .transition(.opacity)
                }
                
                HStack(spacing: 12) {
                    // Cover Image
                    TrackCoverView(song: player.currentSong, size: 50, cornerRadius: 8)
                    
                    // Titles & Controls
                    VStack(alignment: .leading, spacing: 4) {
                        Text(player.currentSong?.title ?? "Not Playing")
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                        
                        if case .error(let msg) = player.status {
                            Text(msg)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.orange)
                                .lineLimit(1)
                        } else {
                            Text(player.currentSong?.artist ?? "music")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        // Mini Controls
                        HStack(spacing: 14) {
                            Button {
                                player.skipToPrevious()
                            } label: {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                player.togglePlayPause()
                            } label: {
                                if player.status == .loading {
                                    ProgressView()
                                        .controlSize(.mini)
                                        .frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: player.status == .playing ? "pause.fill" : "play.fill")
                                        .font(.system(size: 14))
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                player.skipToNext()
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 2)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                
                // Progress bar
                ProgressView(value: progress.currentTime, total: max(progress.duration, 1.0))
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
            }
        }
        .frame(width: 320, height: 110)
        .preferredColorScheme(themeManager.effectiveColorScheme)
        .tint(Color.appleMusicRed)
        .accentColor(Color.appleMusicRed)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
#endif
