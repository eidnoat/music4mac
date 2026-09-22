import SwiftUI
import AppKit

public struct SongListView: View {
    public let title: String
    public let songs: [Song]
    public let allowSorting: Bool
    
    private static let columnStorageKey = "music.songtable.customization.v5"
    private static let sortStorageKey = "music.songtable.sortOrder.v1"
    
    private struct SavedSort: Codable, Equatable {
        let key: String
        let order: SortOrder
    }
    
    private static func encodeSortOrder(_ comparators: [KeyPathComparator<Song>]) -> [SavedSort] {
        return comparators.compactMap { comparator in
            if comparator.keyPath == \Song.title {
                return SavedSort(key: "title", order: comparator.order)
            } else if comparator.keyPath == \Song.artist {
                return SavedSort(key: "artist", order: comparator.order)
            } else if comparator.keyPath == \Song.album {
                return SavedSort(key: "album", order: comparator.order)
            } else if comparator.keyPath == \Song.duration {
                return SavedSort(key: "duration", order: comparator.order)
            } else if comparator.keyPath == \Song.playCount {
                return SavedSort(key: "playCount", order: comparator.order)
            } else if comparator.keyPath == \Song.lastPlayedComparable {
                return SavedSort(key: "lastPlayed", order: comparator.order)
            } else if comparator.keyPath == \Song.dateAddedComparable {
                return SavedSort(key: "dateAdded", order: comparator.order)
            }
            return nil
        }
    }
    
    private static func decodeSortOrder(_ savedList: [SavedSort]) -> [KeyPathComparator<Song>] {
        return savedList.compactMap { item in
            switch item.key {
            case "title":
                return KeyPathComparator(\Song.title, order: item.order)
            case "artist":
                return KeyPathComparator(\Song.artist, order: item.order)
            case "album":
                return KeyPathComparator(\Song.album, order: item.order)
            case "duration":
                return KeyPathComparator(\Song.duration, order: item.order)
            case "playCount":
                return KeyPathComparator(\Song.playCount, order: item.order)
            case "lastPlayed":
                return KeyPathComparator(\Song.lastPlayedComparable, order: item.order)
            case "dateAdded":
                return KeyPathComparator(\Song.dateAddedComparable, order: item.order)
            default:
                return nil
            }
        }
    }
    
    private static func loadSavedSortOrder() -> [KeyPathComparator<Song>]? {
        let storedData = UserDefaults.standard.data(forKey: sortStorageKey)
            ?? UserDefaults.standard.data(forKey: "sylvakru.songtable.sortOrder.v1")
        guard let data = storedData,
              let savedList = try? JSONDecoder().decode([SavedSort].self, from: data) else {
            return nil
        }
        return decodeSortOrder(savedList)
    }
    
    @ObservedObject private var nav = NavigationCoordinator.shared
    @State private var sortOrder: [KeyPathComparator<Song>]
    @State private var selectedSongId: Song.ID?
    @State private var columnCustomization: TableColumnCustomization<Song> = {
        let storedData = UserDefaults.standard.data(forKey: columnStorageKey)
            ?? UserDefaults.standard.data(forKey: "sylvakru.songtable.customization.v5")
        if let data = storedData,
           let decoded = try? JSONDecoder().decode(TableColumnCustomization<Song>.self, from: data) {
            return decoded
        }
        return TableColumnCustomization<Song>()
    }()
    
    // Decoupled playback observation: avoid re-rendering body on high-frequency player ticks!
    @State private var currentPlayingSongId: Song.ID? = AudioPlayerEngine.shared.currentSong?.id
    @State private var isAudioPlaying: Bool = (AudioPlayerEngine.shared.status == .playing)
    
    private let player = AudioPlayerEngine.shared
    private let queue = PlayQueueManager.shared
    @ObservedObject private var storage = StorageManager.shared
    
    @State private var displayedSongs: [Song]
    @State private var songIndexMap: [String: Int] = [:]
    
    public init(
        title: String = "Tracks",
        songs: [Song],
        allowSorting: Bool = true,
        initialSortOrder: [KeyPathComparator<Song>]? = nil
    ) {
        self.title = title
        self.songs = songs
        self.allowSorting = allowSorting
        let defaultSort: [KeyPathComparator<Song>]
        if let custom = initialSortOrder {
            defaultSort = custom
        } else if allowSorting && (title == "Tracks" || title == "All Songs") {
            if let saved = Self.loadSavedSortOrder(), !saved.isEmpty {
                defaultSort = saved
            } else {
                defaultSort = [KeyPathComparator(\Song.title)]
            }
        } else {
            defaultSort = [] // Preserve natural chronological (Recently Played) order
        }
        self._sortOrder = State(initialValue: defaultSort)
        
        let query = NavigationCoordinator.shared.searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let base: [Song] = query.isEmpty ? songs : songs.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.artist.localizedCaseInsensitiveContains(query) ||
            $0.album.localizedCaseInsensitiveContains(query)
        }
        let initialList: [Song]
        if allowSorting && !defaultSort.isEmpty {
            initialList = base.sorted(using: defaultSort)
        } else {
            initialList = base
        }
        self._displayedSongs = State(initialValue: initialList)
        
        var initialMap: [String: Int] = [:]
        initialMap.reserveCapacity(initialList.count)
        for (i, song) in initialList.enumerated() {
            initialMap[song.id] = i + 1
        }
        self._songIndexMap = State(initialValue: initialMap)
        
        // Clean up legacy storage keys
        UserDefaults.standard.removeObject(forKey: "sylvakru.songtable.columns")
        UserDefaults.standard.removeObject(forKey: "sylvakru.songtable.v2.columns")
        UserDefaults.standard.removeObject(forKey: "sylvakru.songtable.customization.v3")
        UserDefaults.standard.removeObject(forKey: "sylvakru.songtable.customization.v4")
        UserDefaults.standard.removeObject(forKey: "sylvakru.songtable.sortOrder.v1")
    }
    
    private func updateDisplayedSongs(reSort: Bool = true) {
        let query = nav.searchText.trimmingCharacters(in: .whitespaces)
        
        // In-place metadata update when not re-sorting (e.g. playback lastPlayed/playCount updates)
        if !reSort {
            let dict = Dictionary(songs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            var updated = displayedSongs
            for i in 0..<updated.count {
                if let newSong = dict[updated[i].id] {
                    updated[i] = newSong
                }
            }
            self.displayedSongs = updated
            return
        }
        
        let base: [Song]
        if query.isEmpty {
            base = songs
        } else {
            let lowerQuery = query.lowercased()
            base = songs.filter {
                $0.title.localizedCaseInsensitiveContains(lowerQuery) ||
                $0.artist.localizedCaseInsensitiveContains(lowerQuery) ||
                $0.album.localizedCaseInsensitiveContains(lowerQuery)
            }
        }
        let result: [Song]
        if allowSorting && !sortOrder.isEmpty {
            result = base.sorted(using: sortOrder)
        } else {
            result = base
        }
        self.displayedSongs = result
        
        var map: [String: Int] = [:]
        map.reserveCapacity(result.count)
        for (i, song) in result.enumerated() {
            map[song.id] = i + 1
        }
        self.songIndexMap = map
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if displayedSongs.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(songs.isEmpty ? "Library is empty. Add a music folder in Settings or connect to Navidrome." : "No matching tracks found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if allowSorting {
                sortableTable
            } else {
                nonSortableTable
            }
        }
        .onChange(of: columnCustomization) { _, newValue in
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: Self.columnStorageKey)
            }
        }
        .onChange(of: nav.searchText) { _, _ in
            updateDisplayedSongs(reSort: true)
        }
        .onChange(of: songs) { oldSongs, newSongs in
            let countUnchanged = (oldSongs.count == newSongs.count)
            updateDisplayedSongs(reSort: !countUnchanged)
        }
        .onChange(of: sortOrder) { _, newSort in
            updateDisplayedSongs(reSort: true)
            if allowSorting && (title == "Tracks" || title == "All Songs") {
                let savedList = Self.encodeSortOrder(newSort)
                if let data = try? JSONEncoder().encode(savedList) {
                    UserDefaults.standard.set(data, forKey: Self.sortStorageKey)
                }
            }
        }
        .onReceive(player.$currentSong) { newSong in
            if currentPlayingSongId != newSong?.id {
                currentPlayingSongId = newSong?.id
            }
        }
        .onReceive(player.$status) { newStatus in
            let playing = (newStatus == .playing)
            if isAudioPlaying != playing {
                isAudioPlaying = playing
            }
        }
        .onReceive(storage.$dataVersion) { _ in
            updateDisplayedSongs(reSort: true)
        }
        .onAppear {
            currentPlayingSongId = player.currentSong?.id
            isAudioPlaying = (player.status == .playing)
        }
    }
    
    // MARK: - Tables
    
    @ViewBuilder
    private var sortableTable: some View {
        Table(
            displayedSongs,
            selection: $selectedSongId,
            sortOrder: $sortOrder,
            columnCustomization: $columnCustomization
        ) {
            // Column 1: # — fixed, always visible, cannot reorder or hide
            TableColumn("#") { song in
                indexCell(for: song)
            }
            .width(ideal: 45)
            .customizationID("index")
            .disabledCustomizationBehavior([.reorder, .visibility])
            
            // Column 2: Title — fixed, always visible, cannot reorder or hide
            TableColumn("Title", value: \.title) { song in
                titleCell(for: song)
            }
            .width(ideal: 240)
            .customizationID("title")
            .disabledCustomizationBehavior([.reorder, .visibility])
            
            // Column 3: Artist — fixed position, can show/hide
            TableColumn("Artist", value: \.artist) { song in
                artistCell(for: song)
            }
            .width(ideal: 160)
            .customizationID("artist")
            .disabledCustomizationBehavior(.reorder)
            
            // Column 4: Album — fixed position, can show/hide
            TableColumn("Album", value: \.album) { song in
                albumCell(for: song)
            }
            .width(ideal: 160)
            .customizationID("album")
            .disabledCustomizationBehavior(.reorder)
            
            // Column 5: Duration — fixed position, can show/hide
            TableColumn("Duration", value: \.duration) { song in
                durationCell(for: song)
            }
            .width(ideal: 65)
            .customizationID("duration")
            .disabledCustomizationBehavior(.reorder)
            
            // Column 6: Plays — fixed position, can show/hide
            TableColumn("Plays", value: \.playCount) { song in
                playsCell(for: song)
            }
            .width(ideal: 80)
            .customizationID("playCount")
            .disabledCustomizationBehavior(.reorder)
            
            // Column 7: Last Played — fixed position, can show/hide
            TableColumn("Last Played", value: \.lastPlayedComparable) { song in
                lastPlayedCell(for: song)
            }
            .width(ideal: 100)
            .customizationID("lastPlayed")
            .disabledCustomizationBehavior(.reorder)
            
            // Column 8: Date Added — fixed position, can show/hide
            TableColumn("Date Added", value: \.dateAddedComparable) { song in
                dateAddedCell(for: song)
            }
            .width(ideal: 95)
            .customizationID("dateAdded")
            .disabledCustomizationBehavior(.reorder)
        }
        .contextMenu(forSelectionType: Song.ID.self) { items in
            songContextMenu(items: items)
        } primaryAction: { items in
            handlePrimaryAction(items: items)
        }
    }
    
    @ViewBuilder
    private var nonSortableTable: some View {
        Table(
            displayedSongs,
            selection: $selectedSongId,
            columnCustomization: $columnCustomization
        ) {
            // Column 1: # — fixed, always visible, cannot reorder or hide
            TableColumn("#") { song in
                indexCell(for: song)
            }
            .width(ideal: 45)
            .customizationID("index")
            .disabledCustomizationBehavior([.reorder, .visibility])
            
            // Column 2: Title — fixed, always visible, non-sortable
            TableColumn("Title") { song in
                titleCell(for: song)
            }
            .width(ideal: 240)
            .customizationID("title")
            .disabledCustomizationBehavior([.reorder, .visibility])
            
            // Column 3: Artist — fixed position, non-sortable, can show/hide
            TableColumn("Artist") { song in
                artistCell(for: song)
            }
            .width(ideal: 160)
            .customizationID("artist")
            .disabledCustomizationBehavior(.reorder)
            
            // Column 4: Album — fixed position, non-sortable, can show/hide
            TableColumn("Album") { song in
                albumCell(for: song)
            }
            .width(ideal: 160)
            .customizationID("album")
            .disabledCustomizationBehavior(.reorder)
            
            // Column 5: Duration — fixed position, non-sortable, can show/hide
            TableColumn("Duration") { song in
                durationCell(for: song)
            }
            .width(ideal: 65)
            .customizationID("duration")
            .disabledCustomizationBehavior(.reorder)
            
            // Column 6: Plays — fixed position, non-sortable, can show/hide
            TableColumn("Plays") { song in
                playsCell(for: song)
            }
            .width(ideal: 80)
            .customizationID("playCount")
            .disabledCustomizationBehavior(.reorder)
            
            // Column 7: Last Played — fixed position, non-sortable, can show/hide
            TableColumn("Last Played") { song in
                lastPlayedCell(for: song)
            }
            .width(ideal: 100)
            .customizationID("lastPlayed")
            .disabledCustomizationBehavior(.reorder)
            
            // Column 8: Date Added — fixed position, non-sortable, can show/hide
            TableColumn("Date Added") { song in
                dateAddedCell(for: song)
            }
            .width(ideal: 95)
            .customizationID("dateAdded")
            .disabledCustomizationBehavior(.reorder)
        }
        .contextMenu(forSelectionType: Song.ID.self) { items in
            songContextMenu(items: items)
        } primaryAction: { items in
            handlePrimaryAction(items: items)
        }
    }
    
    // MARK: - Cells
    
    @ViewBuilder
    private func indexCell(for song: Song) -> some View {
        if currentPlayingSongId == song.id {
            Image(systemName: isAudioPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                .foregroundColor(.accentColor)
                .font(.system(size: 11))
        } else if let idx = songIndexMap[song.id] {
            Text("\(idx)")
                .foregroundColor(.secondary)
                .font(.system(size: 11, design: .monospaced))
        } else {
            Text("-")
                .foregroundColor(.secondary.opacity(0.5))
                .font(.system(size: 11))
        }
    }
    
    @ViewBuilder
    private func titleCell(for song: Song) -> some View {
        SongTitleCellView(
            song: song,
            isPlaying: currentPlayingSongId == song.id
        )
    }
    
    @ViewBuilder
    private func artistCell(for song: Song) -> some View {
        ClickableTableCell(text: song.artist) {
            NavigationCoordinator.shared.navigateToArtist(named: song.artist)
        }
    }
    
    @ViewBuilder
    private func albumCell(for song: Song) -> some View {
        ClickableTableCell(text: song.album) {
            NavigationCoordinator.shared.navigateToAlbum(title: song.album, artist: song.artist)
        }
    }
    
    @ViewBuilder
    private func durationCell(for song: Song) -> some View {
        Text(song.formattedDuration)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private func playsCell(for song: Song) -> some View {
        Text(song.playCount > 0 ? "\(song.playCount)" : "-")
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.secondary)
    }
    
    private static let lastPlayedRelativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
    
    @ViewBuilder
    private func lastPlayedCell(for song: Song) -> some View {
        if let date = song.lastPlayed {
            let interval = Date().timeIntervalSince(date)
            if interval >= 0 && interval < 7 * 86400 {
                Text(Self.lastPlayedRelativeFormatter.localizedString(for: date, relativeTo: Date()))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            } else {
                Text(Self.dateFormatter.string(from: date))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        } else {
            Text("-")
                .foregroundColor(.secondary.opacity(0.5))
                .font(.system(size: 11))
        }
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    @ViewBuilder
    private func dateAddedCell(for song: Song) -> some View {
        if let date = song.dateAdded {
            Text(Self.dateFormatter.string(from: date))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
        } else {
            Text("-")
                .foregroundColor(.secondary.opacity(0.5))
                .font(.system(size: 11))
        }
    }
    
    // MARK: - Actions
    
    @ViewBuilder
    private func songContextMenu(items: Set<Song.ID>) -> some View {
        let selectedSongs = songs.filter { items.contains($0.id) }
        if !selectedSongs.isEmpty {
            if selectedSongs.count == 1, let song = selectedSongs.first {
                Button("Play Now") {
                    player.playSong(song, in: displayedSongs)
                }
                Button("Play Next") {
                    queue.insertNext(song)
                }
                Button("Add to Queue") {
                    queue.append(song)
                }
                Divider()
                if SongCacheManager.shared.isSongCached(id: song.id) {
                    Button("Remove from Cache") {
                        SongCacheManager.shared.removeSong(id: song.id)
                    }
                    if let cachedUrl = SongCacheManager.shared.getCachedFileUrl(for: song) {
                        Button("Show Cached File in Finder") {
                            NSWorkspace.shared.selectFile(cachedUrl.path, inFileViewerRootedAtPath: "")
                        }
                    }
                } else {
                    Button("Cache Track") {
                        SongCacheManager.shared.startAutoCache(for: song)
                    }
                }
            } else {
                Button("Play First Selected") {
                    if let first = selectedSongs.first {
                        player.playSong(first, in: displayedSongs)
                    }
                }
                Button("Add All to Queue") {
                    for s in selectedSongs {
                        queue.append(s)
                    }
                }
                if !selectedSongs.isEmpty {
                    Divider()
                    Button("Cache Selected Tracks (\(selectedSongs.count))") {
                        for s in selectedSongs {
                            SongCacheManager.shared.startAutoCache(for: s)
                        }
                    }
                    Button("Remove Selected from Cache") {
                        for s in selectedSongs {
                            SongCacheManager.shared.removeSong(id: s.id)
                        }
                    }
                }
            }
        }
    }
    
    private func handlePrimaryAction(items: Set<Song.ID>) {
        if let firstId = items.first, let song = songs.first(where: { $0.id == firstId }) {
            player.playSong(song, in: displayedSongs)
        }
    }
}

private struct ClickableTableCell: View {
    let text: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(isHovered ? .accentColor : .secondary)
                .underline(isHovered)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct CircularProgressIndicator: View {
    let color: Color
    @State private var isSpinning = false
    
    var body: some View {
        Circle()
            .trim(from: 0.15, to: 0.85)
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .frame(width: 10, height: 10)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    isSpinning = true
                }
            }
    }
}

private struct SongTitleCellView: View {
    let song: Song
    let isPlaying: Bool
    
    @ObservedObject private var cacheManager = SongCacheManager.shared
    
    var body: some View {
        let isCached = cacheManager.cachedIds.contains(song.id)
        let isDownloading = cacheManager.downloadingIds.contains(song.id)
        
        HStack(spacing: 6) {
            Text(song.title)
                .font(.system(size: 12, weight: isPlaying ? .bold : .regular))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            if isDownloading {
                CircularProgressIndicator(color: .secondary)
                    .help("Caching audio...")
            } else if isCached {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .help("Cached locally")
            }
        }
    }
}
