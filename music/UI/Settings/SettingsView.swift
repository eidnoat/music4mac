import SwiftUI

public struct SettingsView: View {
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var cacheManager = SongCacheManager.shared
    @AppStorage("music.settings.showMenuBarExtra") private var showMenuBarExtra: Bool = true
    @State private var showDisableCacheAlert = false
    @State private var showClearCacheAlert = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Section: Appearance
                VStack(alignment: .leading, spacing: 14) {
                    Text("Appearance")
                        .font(.title3.bold())
                    
                    Picker("Theme", selection: $themeManager.currentTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Label(theme.displayName, systemImage: theme.iconName)
                                .tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                    
                    Text("Choose between Light mode, Dark mode, or automatically match your macOS system appearance.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Section: General Settings
                VStack(alignment: .leading, spacing: 14) {
                    Text("General")
                        .font(.title3.bold())
                    
                    Toggle("Show status icon in macOS menu bar", isOn: Binding(
                        get: { showMenuBarExtra },
                        set: { newValue in
                            showMenuBarExtra = newValue
                            AppDelegate.shared?.updateStatusItemVisibility()
                        }
                    ))
                    .toggleStyle(.switch)
                    
                    Text("When enabled, quickly view the current track and control playback from the menu bar.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Section: Navidrome Server
                NavidromeServerSection()
                
                Divider()
                
                // Section: Audio Cache
                VStack(alignment: .leading, spacing: 14) {
                    Text("Audio Cache")
                        .font(.title3.bold())
                    
                    Toggle("Enable audio caching", isOn: Binding(
                        get: { cacheManager.isEnabled },
                        set: { newValue in
                            if !newValue {
                                showDisableCacheAlert = true
                            } else {
                                cacheManager.isEnabled = true
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    
                    Text("Automatically caches played songs to local disk for faster playback and offline listening.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    if cacheManager.isEnabled {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Max Cache Size:")
                                    .font(.system(size: 13, weight: .medium))
                                Text("\(cacheManager.maxSizeGB) GB")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.accentColor)
                                
                                Spacer()
                                
                                Stepper("", value: $cacheManager.maxSizeGB, in: 1...20, step: 1)
                                    .labelsHidden()
                            }
                            .frame(maxWidth: 320)
                            
                            Slider(
                                value: Binding(
                                    get: { Double(cacheManager.maxSizeGB) },
                                    set: { cacheManager.maxSizeGB = Int(round($0)) }
                                ),
                                in: 1...20,
                                step: 1
                            )
                            .frame(maxWidth: 320)
                            
                            Text("When cache limit is exceeded, songs with the oldest playback time will be automatically evicted.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 24) {
                                StatusItem(label: "Current Usage", value: cacheManager.formattedCurrentSize)
                                StatusItem(label: "Max Limit", value: "\(cacheManager.maxSizeGB) GB")
                                StatusItem(label: "Cached Tracks", value: "\(cacheManager.cachedTrackCount)")
                            }
                            .padding(.top, 4)
                            
                            Button(role: .destructive) {
                                showClearCacheAlert = true
                            } label: {
                                Label("Clear Audio Cache", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            .disabled(cacheManager.currentCacheSizeBytes == 0)
                            .padding(.top, 4)
                        }
                        .padding(.top, 4)
                    }
                }
                
                Divider()
                
                // Section: Library Overview
                VStack(alignment: .leading, spacing: 14) {
                    Text("Library Overview")
                        .font(.title3.bold())
                    
                    HStack(spacing: 24) {
                        StatusItem(label: "Synced Tracks", value: "\(storage.songs.count)")
                        StatusItem(label: "Albums", value: "\(storage.albums.count)")
                        StatusItem(label: "Artists", value: "\(storage.artists.count)")
                    }
                }
                
                Divider()
                
                // Section: About
                VStack(alignment: .leading, spacing: 8) {
                    Text("About music")
                        .font(.title3.bold())
                    Text("Version 0.0.1 · Native macOS Swift")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("A hi-fi music player for self-hosted Navidrome / Subsonic libraries.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: 500)
                }
                
                Spacer()
            }
            .padding(32)
        }
        .alert("Disable Audio Cache?", isPresented: $showDisableCacheAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Disable & Clear All", role: .destructive) {
                cacheManager.disableAndClearCache()
            }
        } message: {
            Text("Disabling audio cache will immediately and permanently delete all currently cached tracks. Are you sure you want to turn it off?")
        }
        .alert("Clear Audio Cache?", isPresented: $showClearCacheAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                cacheManager.clearAllCache()
            }
        } message: {
            Text("Are you sure you want to delete all cached audio tracks? This action cannot be undone.")
        }
    }
}
