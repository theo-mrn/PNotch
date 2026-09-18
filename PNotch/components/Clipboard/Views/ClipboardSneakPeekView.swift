import SwiftUI

/// Live activity flanking the closed notch after a copy: source app on the left, what was copied on the right.
struct ClipboardSneakPeekView: View {
    let peek: SneakPeek.Copy
    /// Changes with every copy, to replay the symbol's bounce.
    let id: UUID
    let notchSize: CGSize

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: NotchMetrics.sneakPeekSideWidth)
            Color.clear
                .frame(width: notchSize.width)
            trailing
                .frame(width: NotchMetrics.sneakPeekSideWidth)
        }
        .frame(height: notchSize.height)
    }

    @ViewBuilder
    private var leading: some View {
        if let app = peek.sourceApp, AppIcons.icon(forBundleIdentifier: app.bundleIdentifier) != nil {
            SourceAppIcon(app: app, size: 18)
        } else {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.ink)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if let color = peek.color {
            Circle()
                .fill(Color(color))
                .overlay(Circle().strokeBorder(Palette.inkTertiary, lineWidth: 1))
                .frame(width: 14, height: 14)
        } else {
            Image(systemName: peek.kind.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .symbolEffect(.bounce, value: id)
        }
    }
}
