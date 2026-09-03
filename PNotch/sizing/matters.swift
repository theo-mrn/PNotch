import CoreGraphics

/// Corner radii fed to `NotchShape` for each notch state.
nonisolated struct NotchCornerRadii: Equatable, Sendable {
    let top: CGFloat
    let bottom: CGFloat

    static let closed = NotchCornerRadii(top: 6, bottom: 14)
    static let sneakPeek = NotchCornerRadii(top: 8, bottom: 16)
    static let opened = NotchCornerRadii(top: 14, bottom: 30)
}

nonisolated enum NotchMetrics {
    /// Used on displays without a camera housing, where PNotch draws its own notch.
    static let fallbackNotchSize = CGSize(width: 190, height: 32)
    /// Room left below the opened notch so its shadow is not clipped by the window.
    static let shadowPadding: CGFloat = 36
    /// Width added on each side of the notch while a sneak peek is shown.
    static let sneakPeekSideWidth: CGFloat = 40
    /// Growth of the closed notch while the pointer rests on it.
    static let hoverGrowth = CGSize(width: 14, height: 3)
    /// Free space kept around the camera housing in the opened header.
    static let cameraClearance: CGFloat = 28
    /// The left and right margin of every page and of the header: one edge for everything.
    static let pageInset: CGFloat = 20
}

nonisolated enum MusicMetrics {
    static let width: CGFloat = 640
    static let bodyHeight: CGFloat = 156
    static let artworkSize: CGFloat = 120
    static let artworkCornerRadius: CGFloat = 16
    static let horizontalPadding: CGFloat = NotchMetrics.pageInset
}

/// The top row of every page, level with the menu bar.
nonisolated enum NotchHeaderMetrics {
    /// The same inset as the pages', so the tabs and the content share one edge.
    static let horizontalPadding: CGFloat = NotchMetrics.pageInset
    /// Tabs and buttons.
    static let controlHeight: CGFloat = 24
    /// An icon tab; tighter ones for the widest camera housings.
    static let tabWidth: CGFloat = 24
    static let tightTabWidth: CGFloat = 21
    static let tabSpacing: CGFloat = 2
    static let tabBarPadding: CGFloat = 3

    /// The bar with `count` icon tabs.
    static func iconBarWidth(count: Int, tight: Bool = false) -> CGFloat {
        let tabs = CGFloat(count)
        return tabs * (tight ? tightTabWidth : tabWidth) + max(tabs - 1, 0) * tabSpacing + 2 * tabBarPadding
    }
}
