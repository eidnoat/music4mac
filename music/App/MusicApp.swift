import SwiftUI

#if os(macOS)
import AppKit
#endif

@main
public struct MusicApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(iOS)
    @UIApplicationDelegateAdaptor(IOSAppDelegate.self) var appDelegate
    #endif
    
    @ObservedObject var themeManager = ThemeManager.shared
    
    public init() {}
    
    public var body: some Scene {
        #if os(macOS)
        // Main macOS Application Window
        WindowGroup {
            MainView()
                .frame(minWidth: 850, minHeight: 550)
                .background(Color(nsColor: .windowBackgroundColor))
                .preferredColorScheme(themeManager.currentTheme.colorScheme)
                .tint(Color.appleMusicRed)
                .accentColor(Color.appleMusicRed)
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1080, height: 700)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    NavigationCoordinator.shared.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            PlaybackCommands()
        }
        #elseif os(iOS)
        // Main iOS / iPadOS Application Scene
        WindowGroup {
            AppRootView()
                .preferredColorScheme(themeManager.currentTheme.colorScheme)
                .tint(Color.appleMusicRed)
                .accentColor(Color.appleMusicRed)
        }
        #endif
    }
}

#if os(macOS)
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
#endif
