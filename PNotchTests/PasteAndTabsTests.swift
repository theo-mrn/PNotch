import Defaults
import Testing
@testable import PNotch

struct PasteActivationTests {
    @Test func pastesWhenAllowed() {
        #expect(ClipboardStateViewModel.activation(copyOnly: false, pasteDirectly: true, isTrusted: true) == .paste)
    }

    @Test func optionOnlyCopies() {
        #expect(ClipboardStateViewModel.activation(copyOnly: true, pasteDirectly: true, isTrusted: true) == .copy)
    }

    @Test func directPasteCanBeTurnedOff() {
        #expect(ClipboardStateViewModel.activation(copyOnly: false, pasteDirectly: false, isTrusted: true) == .copy)
    }

    @Test func missingPermissionFallsBackToCopying() {
        #expect(ClipboardStateViewModel.activation(copyOnly: false, pasteDirectly: true, isTrusted: false) == .copyAndRequestPermission)
    }

    @Test func findsTheKeyTypingV() {
        // Whatever the layout (QWERTY, AZERTY, Dvorak…), some key types "v".
        #expect(KeyboardLayout.keyCode(for: "v") != nil)
    }
}

struct NotchModulesTests {
    @Test func plugsAndUnplugs() {
        var modules = NotchModules(installed: [.music, .clipboard])
        modules.install(.system)
        #expect(modules.installed == [.music, .clipboard, .system])
        modules.install(.system)
        modules.install(.companion)
        #expect(modules.installed == [.music, .clipboard, .system])

        let unplugged = modules.uninstall(.music)
        #expect(unplugged)
        #expect(modules.installed == [.clipboard, .system])
    }

    @Test func neverRunsOutOfModules() {
        var modules = NotchModules(installed: [.clipboard])
        let unplugged = modules.uninstall(.clipboard)
        #expect(!unplugged)
        #expect(modules.installed == [.clipboard])
        // Nothing valid stored: back to the defaults.
        #expect(NotchModules(installed: [.companion]).installed == NotchModules.defaultInstalled)
        #expect(NotchModules(installed: [.system, .system]).installed == [.system])
    }

    @Test func reorders() {
        var modules = NotchModules(installed: [.music, .clipboard, .system])
        modules.move(.system, by: -1)
        #expect(modules.installed == [.music, .system, .clipboard])
        modules.move(.music, by: -5)
        #expect(modules.installed == [.music, .system, .clipboard])
        modules.move(.clipboard, onto: .music)
        #expect(modules.installed == [.clipboard, .music, .system])
    }

    struct OpeningCase: Sendable, CustomTestStringConvertible {
        let startPage: NotchPage?
        let lastPage: NotchPage
        let installed: [NotchPage]
        let expected: NotchPage

        var testDescription: String {
            "start \(String(describing: startPage)), last \(lastPage), installed \(installed.map(\.rawValue))"
        }
    }

    @Test(arguments: [
        OpeningCase(startPage: .system, lastPage: .music, installed: [.music, .system], expected: .system),
        OpeningCase(startPage: nil, lastPage: .clipboard, installed: [.music, .clipboard], expected: .clipboard),
        OpeningCase(startPage: .system, lastPage: .clipboard, installed: [.music, .clipboard], expected: .clipboard),
        OpeningCase(startPage: nil, lastPage: .system, installed: [.music, .clipboard], expected: .music),
        // The Atelier is always there.
        OpeningCase(startPage: nil, lastPage: .companion, installed: [.music], expected: .companion),
    ])
    func picksThePageToOpen(_ testCase: OpeningCase) {
        let modules = NotchModules(installed: testCase.installed)
        #expect(modules.pageToOpen(startPage: testCase.startPage, lastPage: testCase.lastPage) == testCase.expected)
    }
}
