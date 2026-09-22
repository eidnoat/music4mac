import SwiftUI
import AppKit

@main
public struct MusicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var themeManager = ThemeManager.shared
    
    public init() {}
    
    public var body: some Scene {
        // Main Application Window
        WindowGroup {
            MainView()
                .frame(minWidth: 850, minHeight: 550)
                .background(Color(nsColor: .windowBackgroundColor))
                .preferredColorScheme(themeManager.effectiveColorScheme)
                .tint(Color.appleMusicRed)
                .accentColor(Color.appleMusicRed)
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1080, height: 700)
        .commands {
            PlaybackCommands()
        }
    }
}

public struct PlaybackCommands: Commands {
    @ObservedObject var player = AudioPlayerEngine.shared
    
    public var body: some Commands {
        CommandMenu("Playback") {
            Button(player.status == .playing ? "Pause" : "Play") {
                player.togglePlayPause()
            }
            .keyboardShortcut(.space, modifiers: [])
            
            Button("Next Track") {
                player.skipToNext()
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)
            
            Button("Previous Track") {
                player.skipToPrevious()
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)
            
            Divider()
            
            Button("Volume Up") {
                player.volume = min(player.volume + 0.05, 1.0)
            }
            .keyboardShortcut(.upArrow, modifiers: .command)
            
            Button("Volume Down") {
                player.volume = max(player.volume - 0.05, 0.0)
            }
            .keyboardShortcut(.downArrow, modifiers: .command)
            
            Divider()
            
            Button("Toggle Mini Player") {
                let panel = MiniPlayerPanel.shared
                if panel.isVisible {
                    panel.orderOut(nil)
                } else {
                    panel.makeKeyAndOrderFront(nil)
                }
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
        }
    }
}
