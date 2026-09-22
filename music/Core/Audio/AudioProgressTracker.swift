import Foundation
import Combine

/// Dedicated lightweight progress tracker for playback time updates.
/// Decoupled from AudioPlayerEngine to prevent high-frequency 4Hz timer ticks
/// from triggering full re-renders of unrelated player UI components.
public final class AudioProgressTracker: ObservableObject {
    public static let shared = AudioProgressTracker()
    
    @Published public var currentTime: TimeInterval = 0
    @Published public var duration: TimeInterval = 0
    
    private init() {}
    
    public func reset() {
        self.currentTime = 0
        self.duration = 0
    }
}
