import SwiftUI

/// Small icon button used in the notch header.
struct HoverButton: View {
    enum Shape {
        case circle
        case roundedSquare
    }

    let systemImage: String
    var shape: Shape = .roundedSquare
    /// Highlights a toggle that is on.
    var isActive = false
    /// Overrides the fill, e.g. red for an armed destructive action.
    var tint: Color?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(Palette.ink.opacity(isActive || isHovered || tint != nil ? 1 : 0.72))
                .frame(width: NotchHeaderMetrics.controlHeight, height: NotchHeaderMetrics.controlHeight)
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(fill)
                }
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.pressable)
        .onHover { isHovered = $0 }
        .animation(Motion.hover, value: isHovered)
        .animation(Motion.hover, value: tint)
    }

    private var cornerRadius: CGFloat {
        shape == .circle ? NotchHeaderMetrics.controlHeight / 2 : 7
    }

    private var fill: Color {
        if let tint {
            return tint
        }
        if isActive {
            return Palette.inkFaint
        }
        return Palette.ink.opacity(isHovered ? 0.16 : 0.08)
    }
}
