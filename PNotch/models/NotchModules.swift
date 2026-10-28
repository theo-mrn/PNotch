import Defaults
import Foundation

/// The modules plugged into the notch from the Atelier: they are its tabs, in this order.
nonisolated struct NotchModules: Equatable, Sendable {
    /// Everything that can be plugged in, in the order the Atelier shows it.
    /// The Atelier itself isn't a module: it's always there, and Pixel opens it.
    static let catalog: [NotchPage] = [.music, .clipboard, .system, .claudeCode, .timer]

    /// What a fresh install starts with.
    static let defaultInstalled: [NotchPage] = [.music, .clipboard, .system, .claudeCode]

    /// Installed modules, in tab order. Never empty: the notch always has something to show.
    private(set) var installed: [NotchPage]

    init(installed: [NotchPage]) {
        var modules: [NotchPage] = []
        for page in installed where Self.catalog.contains(page) && !modules.contains(page) {
            modules.append(page)
        }
        self.installed = modules.isEmpty ? Self.defaultInstalled : modules
    }


    func isInstalled(_ page: NotchPage) -> Bool {
        installed.contains(page)
    }

    /// Plugs a module in at the end of the tabs.
    mutating func install(_ page: NotchPage) {
        guard Self.catalog.contains(page), !installed.contains(page) else { return }
        installed.append(page)
    }

    /// Unplugging the last module is refused. Returns whether it was unplugged.
    @discardableResult
    mutating func uninstall(_ page: NotchPage) -> Bool {
        guard installed.count > 1, let index = installed.firstIndex(of: page) else { return false }
        installed.remove(at: index)
        return true
    }

    mutating func move(_ page: NotchPage, by offset: Int) {
        guard let index = installed.firstIndex(of: page) else { return }
        let destination = min(max(index + offset, 0), installed.count - 1)
        installed.remove(at: index)
        installed.insert(page, at: destination)
    }

    /// Moves `page` to where `target` is, for drag and drop.
    mutating func move(_ page: NotchPage, onto target: NotchPage) {
        guard page != target, let index = installed.firstIndex(of: page),
              let destination = installed.firstIndex(of: target) else { return }
        installed.remove(at: index)
        installed.insert(page, at: destination)
    }

    /// The page an opening notch shows: the chosen start page, else the last one used,
    /// as long as they're still there, else the first module.
    func pageToOpen(startPage: NotchPage?, lastPage: NotchPage) -> NotchPage {
        if let startPage, isAvailable(startPage) {
            return startPage
        }
        if isAvailable(lastPage) {
            return lastPage
        }
        return installed[0]
    }

    /// The Atelier is always available; modules only once plugged in.
    func isAvailable(_ page: NotchPage) -> Bool {
        page == .companion || installed.contains(page)
    }
}

extension NotchModules {
    /// The modules saved in the preferences; the default ones until the user picks.
    static var current: NotchModules {
        get {
            NotchModules(installed: Defaults[.installedModules] ?? defaultInstalled)
        }
        set {
            Defaults[.installedModules] = newValue.installed
        }
    }
}
