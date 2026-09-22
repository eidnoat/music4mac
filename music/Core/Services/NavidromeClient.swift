import Foundation
import CryptoKit

public struct NavidromeConfig: Codable, Equatable {
    public var serverUrl: String
    public var username: String
    public var password: String
    
    public init(serverUrl: String = "", username: String = "", password: String = "") {
        self.serverUrl = serverUrl
        self.username = username
        self.password = password
    }
}

public final class NavidromeClient: ObservableObject {
    public static let shared = NavidromeClient()
    
    private let configKey = "music.navidrome.config"
    @Published public var config: NavidromeConfig {
        didSet {
            saveConfig()
        }
    }
    
    @Published public var isConnected: Bool = false
    @Published public var isLoading: Bool = false
    
    private let session: URLSession
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
        
        let savedData = UserDefaults.standard.data(forKey: configKey) ?? UserDefaults.standard.data(forKey: "sylvakru.navidrome.config")
        if let data = savedData,
           let saved = try? JSONDecoder().decode(NavidromeConfig.self, from: data) {
            self.config = saved
        } else {
            self.config = NavidromeConfig()
        }
    }
    
    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }
    
    // MARK: - Subsonic Auth & Params
    
    private func buildAuthParams() -> [String: String] {
        let salt = UUID().uuidString.prefix(8).lowercased()
        let combined = "\(config.password)\(salt)"
        let digest = Insecure.MD5.hash(data: Data(combined.utf8))
        let token = digest.map { String(format: "%02hhx", $0) }.joined()
        
        return [
            "u": config.username,
            "t": token,
            "s": String(salt),
            "v": "1.16.1",
            "c": "musicMac",
            "f": "json"
        ]
    }
    
    public var hasValidCredentials: Bool {
        !config.serverUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !config.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !config.password.isEmpty
    }
    
    private func cleanBaseUrl() -> String {
        var base = config.serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.hasSuffix("/") {
            base.removeLast()
        }
        return base
    }
    
    private func request(endpoint: String, extraParams: [String: String] = [:]) async throws -> [String: Any] {
        guard !config.serverUrl.isEmpty else {
            throw URLError(.badURL)
        }
        
        let urlString = "\(cleanBaseUrl())\(endpoint)"
        guard var components = URLComponents(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var queryItems: [URLQueryItem] = []
        for (key, value) in buildAuthParams() {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        for (key, value) in extraParams {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let subsonicResponse = json["subsonic-response"] as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        
        if let status = subsonicResponse["status"] as? String, status != "ok" {
            let errorMsg = (subsonicResponse["error"] as? [String: Any])?["message"] as? String ?? "Unknown Subsonic Error"
            throw NSError(domain: "NavidromeClient", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        return subsonicResponse
    }
    
    // MARK: - Library Methods
    
    public func ping() async throws -> Bool {
        let resp = try await request(endpoint: "/rest/ping.view")
        let ok = (resp["status"] as? String) == "ok"
        await MainActor.run { self.isConnected = ok }
        return ok
    }
    
    public func getSongs(size: Int = 500, offset: Int = 0) async throws -> [Song] {
        let resp = try await request(endpoint: "/rest/search3.view", extraParams: [
            "query": "",
            "albumCount": "0",
            "artistCount": "0",
            "songCount": "\(size)",
            "songOffset": "\(offset)"
        ])
        
        guard let searchResult = resp["searchResult3"] as? [String: Any],
              let rawSongs = searchResult["song"] as? [[String: Any]] else {
            return []
        }
        
        return rawSongs.compactMap { parseSong(dict: $0) }
    }
    
    public func getAllSongs(batchSize: Int = 1000) async throws -> [Song] {
        var allSongs: [Song] = []
        var offset = 0
        while true {
            let batch = try await getSongs(size: batchSize, offset: offset)
            if batch.isEmpty { break }
            allSongs.append(contentsOf: batch)
            if batch.count < batchSize { break }
            offset += batch.count
        }
        return allSongs
    }
    
    public func getCoverArtUrl(id: String?, size: Int? = 500) -> URL? {
        guard let id = id, !id.isEmpty, !config.serverUrl.isEmpty else { return nil }
        var components = URLComponents(string: "\(cleanBaseUrl())/rest/getCoverArt.view")
        var items: [URLQueryItem] = [URLQueryItem(name: "id", value: id)]
        if let size = size {
            items.append(URLQueryItem(name: "size", value: "\(size)"))
        }
        for (k, v) in buildAuthParams() {
            items.append(URLQueryItem(name: k, value: v))
        }
        components?.queryItems = items
        return components?.url
    }
    
    public func getStreamUrl(songId: String) -> URL? {
        guard !songId.isEmpty, !config.serverUrl.isEmpty else { return nil }
        var components = URLComponents(string: "\(cleanBaseUrl())/rest/stream.view")
        var items: [URLQueryItem] = [URLQueryItem(name: "id", value: songId)]
        for (k, v) in buildAuthParams() {
            items.append(URLQueryItem(name: k, value: v))
        }
        components?.queryItems = items
        return components?.url
    }
    
    public func getLyrics(songId: String) async throws -> String? {
        if let resp = try? await request(endpoint: "/rest/getLyricsBySongId.view", extraParams: ["id": songId]),
           let lyricsList = (resp["lyricsList"] as? [String: Any])?["structuredLyrics"] as? [[String: Any]],
           let first = lyricsList.first,
           let lineList = first["line"] as? [[String: Any]] {
            let lrcLines = lineList.compactMap { line -> String? in
                guard let value = line["value"] as? String else { return nil }
                if let startMs = line["start"] as? Int {
                    let min = (startMs / 1000) / 60
                    let sec = (startMs / 1000) % 60
                    let ms = startMs % 1000
                    return String(format: "[%02d:%02d.%03d]%@", min, sec, ms, value)
                }
                return value
            }
            if !lrcLines.isEmpty {
                return lrcLines.joined(separator: "\n")
            }
        }
        
        let resp = try await request(endpoint: "/rest/getLyrics.view", extraParams: ["id": songId])
        if let lyrics = resp["lyrics"] as? [String: Any],
           let text = lyrics["content"] as? String {
            return text
        }
        return nil
    }
    
    public func scrobble(songId: String, submission: Bool = true) async {
        let timestampMs = String(Int64(Date().timeIntervalSince1970 * 1000))
        _ = try? await request(endpoint: "/rest/scrobble.view", extraParams: [
            "id": songId,
            "time": timestampMs,
            "submission": submission ? "true" : "false"
        ])
    }
    
    // MARK: - Parsing
    
    private static let isoFormatterWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let isoFormatterStandard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    private static let fallbackDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private static let spaceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    public static func parseDate(from rawValue: Any?) -> Date? {
        guard let rawValue = rawValue else { return nil }
        
        if let str = rawValue as? String {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            
            // 1. Try standard ISO8601 parsing
            if let date = try? Date(trimmed, strategy: .iso8601) {
                return date
            }
            
            // 2. Normalization: if there is a fractional second (e.g. .784818075Z or .784818075+00:00)
            // Truncate to 3 decimal digits for ISO8601DateFormatter
            if let dotIndex = trimmed.firstIndex(of: ".") {
                let prefix = trimmed[..<dotIndex]
                let afterDot = trimmed[trimmed.index(after: dotIndex)...]
                let digits = afterDot.prefix(while: { $0.isNumber })
                let tz = afterDot.dropFirst(digits.count)
                let truncatedDigits = digits.prefix(3)
                let normalized = "\(prefix).\(truncatedDigits)\(tz)"
                if let date = isoFormatterWithFraction.date(from: normalized) {
                    return date
                }
                if let date = isoFormatterStandard.date(from: String(prefix) + String(tz)) {
                    return date
                }
            }
            
            // 3. Try standard ISO8601
            if let date = isoFormatterStandard.date(from: trimmed) {
                return date
            }
            
            // 4. Fallback DateFormatters
            if let date = fallbackDateFormatter.date(from: trimmed) {
                return date
            }
            if let date = spaceDateFormatter.date(from: trimmed) {
                return date
            }
            
            // 5. Unix timestamp in string form
            if let doubleVal = Double(trimmed) {
                return Date(timeIntervalSince1970: doubleVal > 1e11 ? doubleVal / 1000.0 : doubleVal)
            }
        } else if let doubleVal = rawValue as? Double {
            return Date(timeIntervalSince1970: doubleVal > 1e11 ? doubleVal / 1000.0 : doubleVal)
        } else if let intVal = rawValue as? Int {
            let doubleVal = Double(intVal)
            return Date(timeIntervalSince1970: doubleVal > 1e11 ? doubleVal / 1000.0 : doubleVal)
        }
        
        return nil
    }
    
    private func parseSong(dict: [String: Any]) -> Song? {
        guard let id = dict["id"] as? String,
              let title = dict["title"] as? String else { return nil }
        
        let artist = dict["artist"] as? String ?? "Unknown Artist"
        let album = dict["album"] as? String ?? "Unknown Album"
        let albumArtist = dict["displayAlbumArtist"] as? String
        let genre = dict["genre"] as? String
        let year = dict["year"] as? Int
        let track = dict["track"] as? Int
        let disc = dict["discNumber"] as? Int
        let duration = Double(dict["duration"] as? Int ?? 0)
        let bitrate = dict["bitRate"] as? Int
        let sampleRate = dict["samplingRate"] as? Int
        let contentType = dict["contentType"] as? String
        let format = contentType?.components(separatedBy: "audio/").last
        let coverId = dict["coverArt"] as? String ?? id
        let playCount = dict["playCount"] as? Int ?? 0
        
        let dateAdded = Self.parseDate(from: dict["created"])
            ?? Self.parseDate(from: dict["createdAt"])
            ?? Self.parseDate(from: dict["dateAdded"])
            ?? Self.parseDate(from: dict["birthTime"])
        
        let lastPlayed = Self.parseDate(from: dict["played"])
            ?? Self.parseDate(from: dict["lastPlayed"])
        
        return Song(
            id: id,
            title: title,
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            genre: genre,
            year: year,
            trackNumber: track,
            discNumber: disc,
            duration: duration,
            bitrate: bitrate,
            sampleRate: sampleRate,
            format: format,
            source: .navidrome,
            remoteId: id,
            coverUrl: getCoverArtUrl(id: coverId),
            coverId: coverId,
            playCount: playCount,
            lastPlayed: lastPlayed,
            dateAdded: dateAdded
        )
    }
}
