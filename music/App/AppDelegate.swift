import AppKit
import SwiftUI

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public static private(set) var shared: AppDelegate?
    
    private var statusItem: NSStatusItem?
    private var statusPopover: NSPopover?
    
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep playing in background even if main window is closed
        return false
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        StorageManager.shared.flushPendingSaves()
    }
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        // Constrain global URLCache to prevent unbounded memory growth from remote artwork
        let memoryCapacity = 25 * 1024 * 1024 // 25 MB RAM
        let diskCapacity = 100 * 1024 * 1024  // 100 MB Disk
        URLCache.shared = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            diskPath: "music_network_cache"
        )
        
        // Ensure saved directories are accessible
        _ = BookmarkManager.shared.startAccessingAllSavedDirectories()
        ThemeManager.shared.apply()
        updateStatusItemVisibility()
    }
    
    public func updateStatusItemVisibility() {
        let show = (UserDefaults.standard.object(forKey: "music.settings.showMenuBarExtra")
            ?? UserDefaults.standard.object(forKey: "sylvakru.settings.showMenuBarExtra")) as? Bool ?? true
        if show {
            if statusItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                if let button = item.button {
                    button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "music")
                    button.target = self
                    button.action = #selector(toggleStatusPopover(_:))
                }
                self.statusItem = item
            }
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
            statusPopover?.close()
        }
    }
    
    @objc private func toggleStatusPopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }
        if statusPopover == nil {
            let popover = NSPopover()
            popover.contentSize = NSSize(width: 260, height: 160)
            popover.behavior = .transient
            popover.contentViewController = NSHostingController(rootView: MenuBarView())
            self.statusPopover = popover
        }
        if let popover = statusPopover {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in NSApplication.shared.windows {
                if !(window is NSPanel) {
                    window.makeKeyAndOrderFront(nil)
                    return true
                }
            }
        }
        return true
    }
    
    public func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        
        let player = AudioPlayerEngine.shared
        let isPlaying = player.status == .playing
        
        let playPauseItem = NSMenuItem(
            title: isPlaying ? "Pause" : "Play",
            action: #selector(dockTogglePlayPause),
            keyEquivalent: ""
        )
        playPauseItem.target = self
        menu.addItem(playPauseItem)
        
        let nextItem = NSMenuItem(
            title: "Next Track",
            action: #selector(dockNext),
            keyEquivalent: ""
        )
        nextItem.target = self
        menu.addItem(nextItem)
        
        let prevItem = NSMenuItem(
            title: "Previous Track",
            action: #selector(dockPrevious),
            keyEquivalent: ""
        )
        prevItem.target = self
        menu.addItem(prevItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let miniItem = NSMenuItem(
            title: "Open Mini Player",
            action: #selector(dockOpenMiniPlayer),
            keyEquivalent: ""
        )
        miniItem.target = self
        menu.addItem(miniItem)
        
        return menu
    }
    
    @objc private func dockTogglePlayPause() {
        AudioPlayerEngine.shared.togglePlayPause()
    }
    
    @objc private func dockNext() {
        AudioPlayerEngine.shared.skipToNext()
    }
    
    @objc private func dockPrevious() {
        AudioPlayerEngine.shared.skipToPrevious()
    }
    
    @objc private func dockOpenMiniPlayer() {
        MiniPlayerPanel.shared.makeKeyAndOrderFront(nil)
    }
}
