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
        var modules = NotchModules(installed: [.music])
        modules.install(.clipboard)
        #expect(modules.installed == [.music, .clipboard])
        modules.install(.clipboard)
        #expect(modules.installed == [.music, .clipboard])

        let unplugged = modules.uninstall(.music)
        #expect(unplugged)
        #expect(modules.installed == [.clipboard])
    }

    @Test func neverRunsOutOfModules() {
        var modules = NotchModules(installed: [.clipboard])
        let unplugged = modules.uninstall(.clipboard)
        #expect(!unplugged)
        #expect(modules.installed == [.clipboard])
        // Nothing valid stored: back to the defaults.
        #expect(NotchModules(installed: []).installed == NotchModules.defaultInstalled)
        #expect(NotchModules(installed: [.music, .music]).installed == [.music])
    }

    @Test func reorders() {
        var modules = NotchModules(installed: [.music, .clipboard])
        modules.move(.clipboard, by: -1)
        #expect(modules.installed == [.clipboard, .music])
        modules.move(.clipboard, by: -5)
        #expect(modules.installed == [.clipboard, .music])
        modules.move(.clipboard, onto: .music)
        #expect(modules.installed == [.music, .clipboard])
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
        OpeningCase(startPage: .clipboard, lastPage: .music, installed: [.music, .clipboard], expected: .clipboard),
        OpeningCase(startPage: nil, lastPage: .clipboard, installed: [.music, .clipboard], expected: .clipboard),
        OpeningCase(startPage: .clipboard, lastPage: .music, installed: [.music], expected: .music),
        OpeningCase(startPage: nil, lastPage: .clipboard, installed: [.music], expected: .music),
    ])
    func picksThePageToOpen(_ testCase: OpeningCase) {
        let modules = NotchModules(installed: testCase.installed)
        #expect(modules.pageToOpen(startPage: testCase.startPage, lastPage: testCase.lastPage) == testCase.expected)
    }
}
