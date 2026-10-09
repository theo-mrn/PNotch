import Foundation

enum NotchState {
    case closed
    case open
}

/// Why the notch was opened. It decides how the notch is allowed to close on its own.
enum NotchOpenReason {
    /// The pointer rested on the notch.
    case hover
    /// The user clicked the closed notch.
    case click
    /// The global shortcut or the menu bar item.
    case keyboard
    /// The user launched PNotch: the notch introduces itself until the next click elsewhere.
    case launch
}

/// Why the notch folded back. Logged, to make unexpected closings easy to trace.
enum NotchCloseReason {
    case pointerLeft
    case clickOutside
    case escape
    case shortcut
    case copied
    case pasted
    case settings
}

/// Pages of the opened notch. The modules plugged in from the Atelier are its tabs;
/// the Atelier itself, Pixel's home, opens from Pixel in the header.
nonisolated enum NotchPage: String, CaseIterable, Sendable {
    case music
    case clipboard
    case system
    /// The Atelier: Pixel presents the modules there, and lives there.
    case companion
}

/// What the opened notch shows, which decides its size.
nonisolated enum NotchLayout: Equatable, Sendable {
    case music
    case system
    case companion
    /// The searchable list, shrinking around `itemCount` results.
    case clipboardList(itemCount: Int)
}
