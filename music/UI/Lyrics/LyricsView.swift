import SwiftUI

public struct LyricsView: View {
    @State private var lyrics: ParsedLyrics = AudioPlayerEngine.shared.parsedLyrics
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Lyrics")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            
            Divider()
            
            if lyrics.lines.isEmpty {
                VStack {
                    Spacer()
                    Text("No lyrics available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    Text(lyrics.lines.map(\.text).joined(separator: "\n"))
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                }
            }
        }
        .background(.ultraThinMaterial)
        .onReceive(AudioPlayerEngine.shared.$parsedLyrics) { newLyrics in
            self.lyrics = newLyrics
        }
    }
}
