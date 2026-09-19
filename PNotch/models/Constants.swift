import Defaults
import Foundation

extension Defaults.Keys {
    // MARK: General

    static let menubarIcon = Key<Bool>("menubarIcon", default: true)
    static let openNotchOnHover = Key<Bool>("openNotchOnHover", default: true)
    static let minimumHoverDuration = Key<TimeInterval>("minimumHoverDuration", default: 0.2)
    static let enableHaptics = Key<Bool>("enableHaptics", default: true)
    /// The page the notch was left on.
    static let lastNotchPage = Key<NotchPage>("lastNotchPage", default: .music)
    /// The page the notch opens on; `nil` reopens the last one used.
    static let startPage = Key<NotchPage?>("startPage", default: nil)
    /// The modules plugged into the notch, in tab order. `nil` until set: the default modules.
    static let installedModules = Key<[NotchPage]?>("installedModules", default: nil)

    // MARK: Music

    static let showMusicLiveActivity = Key<Bool>("showMusicLiveActivity", default: true)

    // MARK: Clipboard

    static let clipboardHistoryLimit = Key<Int>("clipboardHistoryLimit", default: 200)
    static let fetchLinkPreviews = Key<Bool>("fetchLinkPreviews", default: true)
    static let showCopySneakPeek = Key<Bool>("showCopySneakPeek", default: true)
    static let closeNotchAfterCopy = Key<Bool>("closeNotchAfterCopy", default: true)
    /// Choosing an item pastes it into the app in use (needs the Accessibility permission), ⌥ only copies.
    static let pasteDirectly = Key<Bool>("pasteDirectly", default: true)
}

/// History sizes offered in Settings.
let clipboardHistoryLimitOptions = [50, 100, 200, 500]

extension NotchPage: Defaults.Serializable {}

