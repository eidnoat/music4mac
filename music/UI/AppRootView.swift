import SwiftUI

public struct AppRootView: View {
    #if os(macOS)
    public var body: some View {
        MainView()
    }
    #elseif os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    public init() {}
    
    public var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad || horizontalSizeClass == .regular {
            iPadMainView()
        } else {
            iPhoneMainView()
        }
    }
    #endif
}
