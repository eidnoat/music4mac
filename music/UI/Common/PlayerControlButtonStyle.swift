import SwiftUI

public struct PlayerControlButtonStyle: ButtonStyle {
    public let scale: CGFloat
    
    public init(scale: CGFloat = 0.94) {
        self.scale = scale
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
