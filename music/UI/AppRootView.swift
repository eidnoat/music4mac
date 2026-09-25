import SwiftUI

public struct AppRootView: View {
    public init() {}
    
    #if os(macOS)
    public var body: some View {
        MainView()
    }
    #elseif os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isPadLayout: Bool {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return true
        }
        if UIDevice.current.model.localizedCaseInsensitiveContains("iPad") {
            return true
        }
        if min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) >= 600 {
            return true
        }
        return horizontalSizeClass == .regular
    }
    
    public var body: some View {
        Group {
            if isPadLayout {
                iPadMainView()
            } else {
                iPhoneMainView()
            }
        }
        .tint(Color.appleMusicRed)
        .accentColor(Color.appleMusicRed)
    }
    #endif
}
