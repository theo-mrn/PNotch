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
    case settings
}

/// Pages of the opened notch: the modules plugged in, which are its tabs.
nonisolated enum NotchPage: String, CaseIterable, Sendable {
    case music
}

/// What the opened notch shows, which decides its size.
nonisolated enum NotchLayout: Equatable, Sendable {
    case music
}
