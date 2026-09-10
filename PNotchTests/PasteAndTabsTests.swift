import Defaults
import Testing
@testable import PNotch

struct NotchModulesTests {
    @Test func neverRunsOutOfModules() {
        var modules = NotchModules(installed: [.music])
        let unplugged = modules.uninstall(.music)
        #expect(!unplugged)
        #expect(modules.installed == [.music])
        // Nothing valid stored: back to the defaults.
        #expect(NotchModules(installed: []).installed == NotchModules.defaultInstalled)
        #expect(NotchModules(installed: [.music, .music]).installed == [.music])
    }

    @Test func opensOnAnInstalledPage() {
        let modules = NotchModules(installed: [.music])
        #expect(modules.pageToOpen(startPage: nil, lastPage: .music) == .music)
        #expect(modules.pageToOpen(startPage: .music, lastPage: .music) == .music)
    }
}
