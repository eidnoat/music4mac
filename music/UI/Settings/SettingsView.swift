import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var cacheManager = SongCacheManager.shared
    @AppStorage("music.settings.showMenuBarExtra") private var showMenuBarExtra: Bool = true
    @State private var folders: [URL] = []
    @State private var isScanning = false
    @State private var scanProgress = ""
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
                
                // Section: Local Folders
                VStack(alignment: .leading, spacing: 14) {
                    Text("Local Music Folders")
                        .font(.title2.bold())
                    Text("Add local music folders to automatically index audio files")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        ForEach(folders, id: \.self) { folder in
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.accentColor)
                                Text(folder.path)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Button {
                                    removeFolder(folder)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button {
                            selectFolder()
                        } label: {
                            Label("Add Folder...", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button {
                            rescanAll()
                        } label: {
                            if isScanning {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Rescan All", systemImage: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isScanning || folders.isEmpty)
                    }
                    
                    if !scanProgress.isEmpty {
                        Text(scanProgress)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Section: Library Stats
                VStack(alignment: .leading, spacing: 14) {
                    Text("Library Overview")
                        .font(.title3.bold())
                    
                    let localCount = storage.songs.filter { $0.source == .local }.count
                    let remoteCount = storage.songs.filter { $0.source == .navidrome }.count
                    
                    HStack(spacing: 24) {
                        StatusItem(label: "Local Tracks", value: "\(localCount)")
                        StatusItem(label: "Navidrome Tracks", value: "\(remoteCount)")
                        StatusItem(label: "Total Tracks", value: "\(storage.songs.count)")
                    }
                }
                
                Divider()
                
                // Section: About
                VStack(alignment: .leading, spacing: 8) {
                    Text("About music")
                        .font(.title3.bold())
                    Text("Version 1.0.0 · Native macOS Swift")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("A hi-fi music player for local and self-hosted media libraries.")
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
        .onAppear {
            folders = BookmarkManager.shared.startAccessingAllSavedDirectories()
        }
    }
    
    private func selectFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Select Music Directory"
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            if BookmarkManager.shared.saveBookmark(for: url) {
                if !folders.contains(url) {
                    folders.append(url)
                }
                scanFolder(url)
            }
        }
    }
    
    private func removeFolder(_ url: URL) {
        BookmarkManager.shared.removeBookmark(for: url)
        folders.removeAll(where: { $0 == url })
        // Remove songs belonging to this folder
        storage.songs.removeAll(where: { $0.localPath?.hasPrefix(url.path) == true })
        storage.saveLibrary()
    }
    
    private func scanFolder(_ url: URL) {
        isScanning = true
        scanProgress = "Scanning: \(url.lastPathComponent)..."
        
        Task {
            let songs = await LocalLibraryScanner.shared.scanDirectory(at: url) { progress, file in
                DispatchQueue.main.async {
                    self.scanProgress = "Scanning (\(Int(progress * 100))%): \(file)"
                }
            }
            
            await MainActor.run {
                storage.upsertSongs(songs)
                self.isScanning = false
                self.scanProgress = "Scan complete, found \(songs.count) tracks"
            }
        }
    }
    
    private func rescanAll() {
        isScanning = true
        scanProgress = "Preparing to rescan..."
        
        Task {
            var allSongs: [Song] = []
            for folder in folders {
                let songs = await LocalLibraryScanner.shared.scanDirectory(at: folder)
                allSongs.append(contentsOf: songs)
            }
            await MainActor.run {
                storage.upsertSongs(allSongs)
                self.isScanning = false
                self.scanProgress = "Rescan complete, updated \(allSongs.count) local tracks"
            }
        }
    }
}
