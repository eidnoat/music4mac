import SwiftUI

public struct PlayerControlButtonStyle: ButtonStyle {
    public let scale: CGFloat
    
    public init(scale: CGFloat = 0.90) {
        self.scale = scale
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
