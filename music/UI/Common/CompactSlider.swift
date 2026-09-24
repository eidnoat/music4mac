import SwiftUI

public struct CompactSlider<V: BinaryFloatingPoint>: View {
    @Binding var value: V
    let range: ClosedRange<V>
    var thumbSize: CGFloat
    var trackHeight: CGFloat
    var activeColor: Color
    var onEditingChanged: ((Bool) -> Void)?
    
    @State private var isDragging: Bool = false
    
    public init(
        value: Binding<V>,
        in range: ClosedRange<V> = 0...1,
        thumbSize: CGFloat = 10,
        trackHeight: CGFloat = 4,
        activeColor: Color = .appleMusicRed,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._value = value
        self.range = range
        self.thumbSize = thumbSize
        self.trackHeight = trackHeight
        self.activeColor = activeColor
        self.onEditingChanged = onEditingChanged
    }
    
    public var body: some View {
        GeometryReader { geo in
            let lower = Double(range.lowerBound)
            let upper = Double(range.upperBound)
            let totalRange = max(upper - lower, 0.0001)
            let currentVal = Double(value)
            let progress = min(max((currentVal - lower) / totalRange, 0), 1)
            let width = geo.size.width
            let knobX = width * CGFloat(progress)
            
            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color.secondary.opacity(0.22))
                    .frame(height: trackHeight)
                
                // Active Track
                Capsule()
                    .fill(activeColor)
                    .frame(width: max(knobX, 0), height: trackHeight)
                
                // Delicate Small Thumb Knob
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: min(max(knobX - thumbSize / 2, 0), max(width - thumbSize, 0)))
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged?(true)
                        }
                        let pct = min(max(gesture.location.x / max(width, 1), 0), 1)
                        value = V(lower + Double(pct) * totalRange)
                    }
                    .onEnded { gesture in
                        let pct = min(max(gesture.location.x / max(width, 1), 0), 1)
                        value = V(lower + Double(pct) * totalRange)
                        isDragging = false
                        onEditingChanged?(false)
                    }
            )
        }
        .frame(height: max(thumbSize + 14, 28))
    }
}
