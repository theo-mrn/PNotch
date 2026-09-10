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
}

extension NotchPage: Defaults.Serializable {}

