import SwiftUI

public struct NavidromeServerSection: View {
    @ObservedObject var client = NavidromeClient.shared
    @ObservedObject var storage = StorageManager.shared
    
    @State private var serverUrl: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    
    @State private var testResult: String?
    @State private var isTesting = false
    @State private var isSyncing = false
    @State private var syncProgress = ""
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Navidrome Server")
                    .font(.title3.bold())
                
                Circle()
                    .fill(client.isConnected ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .help(client.isConnected ? "Server connected" : "Server not connected")
            }
            
            Text("Connect to your self-hosted Navidrome or Subsonic server to stream and sync your music library.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server URL")
                        .font(.system(size: 12, weight: .medium))
                    TextField("e.g. https://music.example.com", text: $serverUrl)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Username")
                        .font(.system(size: 12, weight: .medium))
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Password")
                        .font(.system(size: 12, weight: .medium))
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .frame(maxWidth: 380)
            
            HStack(spacing: 12) {
                Button {
                    testConnection()
                } label: {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Save & Test Connection")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(serverUrl.isEmpty || username.isEmpty)
                
                if client.isConnected {
                    Button {
                        syncLibrary()
                    } label: {
                        if isSyncing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Sync All Tracks", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSyncing)
                }
            }
            .padding(.top, 2)
            
            if let result = testResult {
                HStack(spacing: 8) {
                    Image(systemName: client.isConnected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(client.isConnected ? .green : .red)
                    Text(result)
                        .font(.system(size: 12))
                }
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            if !syncProgress.isEmpty {
                Text(syncProgress)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            if client.isConnected {
                HStack(spacing: 24) {
                    StatusItem(label: "Status", value: "Connected")
                    StatusItem(label: "Protocol", value: "Subsonic 1.16.1")
                    StatusItem(label: "Auth", value: "Verified (Token+Salt)")
                }
                .padding(.top, 4)
            }
        }
        .onAppear {
            serverUrl = client.config.serverUrl
            username = client.config.username
            password = client.config.password
        }
    }
    
    private func testConnection() {
        client.config = NavidromeConfig(serverUrl: serverUrl, username: username, password: password)
        isTesting = true
        testResult = nil
        
        Task {
            do {
                let success = try await client.ping()
                await MainActor.run {
                    self.isTesting = false
                    if success {
                        self.testResult = "Connected successfully to Navidrome server"
                    } else {
                        self.testResult = "Server returned abnormal status"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isTesting = false
                    self.testResult = "Connection failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func syncLibrary() {
        isSyncing = true
        syncProgress = "Fetching track list..."
        
        Task {
            do {
                let songs = try await client.getAllSongs()
                await MainActor.run {
                    storage.upsertSongs(songs)
                    self.isSyncing = false
                    self.syncProgress = "Sync complete, imported \(songs.count) tracks"
                }
            } catch {
                await MainActor.run {
                    self.isSyncing = false
                    self.syncProgress = "Sync failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

public struct NavidromeConfigView: View {
    public init() {}
    
    public var body: some View {
        ScrollView {
            NavidromeServerSection()
                .padding(32)
        }
    }
}

public struct StatusItem: View {
    let label: String
    let value: String
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
        }
    }
}
