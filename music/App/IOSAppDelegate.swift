#if os(iOS)
import UIKit
import AVFoundation

public final class IOSAppDelegate: NSObject, UIApplicationDelegate {
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("[Music] Failed to activate AVAudioSession: \(error)")
        }
        application.beginReceivingRemoteControlEvents()
        return true
    }
}
#endif
