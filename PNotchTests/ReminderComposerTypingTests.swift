import AppKit
import Defaults
import SwiftUI
import Testing
@testable import PNotch

@MainActor
@Suite(.serialized)
/// Types a time into the reminder editor, in the notch's own kind of window: the digits must reach it.
struct ReminderComposerTypingTests {
    private final class SilentController: MediaControllerProtocol {
        var onPlaybackChange: ((PlaybackState?) -> Void)?
        func start() {}
        func stop() {}
        func send(_ command: MediaCommand) {}
        func seek(to position: TimeInterval) {}
    }

    private static let directory = FileManager.default.temporaryDirectory.appending(path: "typing-\(UUID().uuidString)")

    private func textFields(in view: NSView) -> [NSTextField] {
        view.subviews.flatMap { sub -> [NSTextField] in
            (sub as? NSTextField).map { [$0] } ?? textFields(in: sub)
        }
    }

    /// Waits for `condition`, a few seconds at most: other tests share the main actor.
    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private func type(_ text: String, in window: NSWindow) {
        (window.firstResponder as? NSTextView)?.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    /// The reminders page, in a window like the notch's, the editor open.
    private func host(_ reminders: RemindersManager) -> (window: PNotchWindow, hosting: NSView) {
        let vm = PNotchViewModel(screen: nil, page: .reminders)
        vm.remindersPanel = { reminders.panel }
        let size = vm.geometry.openedSize(for: .reminders(.settings))
        let music = MusicManager(controller: SilentController())
        let system = SystemMonitor()
        let view = RemindersView()
            .frame(width: size.width, height: size.height, alignment: .top)
            .background(Color.black)
            .environment(vm)
            .environment(PNotchViewCoordinator())
            .environment(music)
            .environment(system)
            .environment(CompanionManager(music: music, system: system))
            .environment(ClipboardStateViewModel(persistence: ClipboardPersistenceService(rootDirectory: Self.directory)))
            .environment(ClaudeCodeManager())
            .environment(FocusManager())
            .environment(reminders)
            .environment(\.colorScheme, .dark)

        // The notch's own kind of window: a non-activating panel.
        let window = PNotchWindow(contentRect: CGRect(origin: CGPoint(x: 0, y: 2000), size: size))
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(origin: .zero, size: size)
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        return (window, hosting)
    }

    /// The field under the LED display, which takes the time's digits: narrower than the text and the note.
    private func timeField(in hosting: NSView) async throws -> NSTextField {
        var field: NSTextField?
        try await waitUntil {
            field = textFields(in: hosting).first { $0.frame.width < 200 }
            return field != nil
        }
        return try #require(field)
    }

    private func withModules(_ body: () async throws -> Void) async rethrows {
        let savedModules = Defaults[.installedModules]
        defer { Defaults[.installedModules] = savedModules }
        Defaults[.installedModules] = [.music, .clipboard, .claudeCode, .reminders]
        try await body()
    }

    @Test func typesTheTime() async throws {
        try await withModules {
            let reminders = RemindersManager(items: [], saveItems: { _ in })
            defer { reminders.stop() }
            reminders.openEditor(.new)
            reminders.editor?.text = "Appeler Léa"
            reminders.editor?.showsSettings = true

            let (window, hosting) = host(reminders)
            defer { window.orderOut(nil) }
            window.makeFirstResponder(try await timeField(in: hosting))
            try await waitUntil { window.firstResponder is NSTextView }
            // In one go, as fast as one types.
            for digit in ["1", "4", "3", "0"] {
                type(digit, in: window)
            }
            try await waitUntil { reminders.editor?.minute == 30 }

            #expect(reminders.editor?.hour == 14)
            #expect(reminders.editor?.minute == 30)
            #expect(reminders.editor?.hasTime == true)
        }
    }

    /// Writes the text and presses ↩: the reminder is saved and the editor fades out, without a crash.
    @Test func savesWithReturn() async throws {
        try await withModules {
            let reminders = RemindersManager(items: [], saveItems: { _ in })
            defer { reminders.stop() }
            reminders.openEditor(.new)

            let (window, hosting) = host(reminders)
            defer { window.orderOut(nil) }
            var titleField: NSTextField?
            try await waitUntil {
                // The topmost wide field: the text, the note being under it.
                titleField = textFields(in: hosting)
                    .filter { $0.frame.width >= 60 }
                    .max { $0.convert($0.bounds, to: nil).maxY < $1.convert($1.bounds, to: nil).maxY }
                return titleField != nil
            }
            window.makeFirstResponder(try #require(titleField))
            try await waitUntil { window.firstResponder is NSTextView }
            type("Appeler Léa", in: window)
            try await waitUntil { reminders.editor?.text == "Appeler Léa" }

            (window.firstResponder as? NSTextView)?.insertNewline(nil)
            try await waitUntil { reminders.editor == nil }
            // Through the fade-out, its fields still on screen.
            try await Task.sleep(for: .seconds(1))

            #expect(reminders.editor == nil)
            #expect(reminders.reminders.map(\.title) == ["Appeler Léa"])
        }
    }

    /// Types a time, then saves while the minutes still have the keyboard.
    @Test func savesWhileTypingTheTime() async throws {
        try await withModules {
            let reminders = RemindersManager(items: [], saveItems: { _ in })
            defer { reminders.stop() }
            reminders.openEditor(.new)
            reminders.editor?.text = "Appeler Léa"
            reminders.editor?.showsSettings = true

            let (window, hosting) = host(reminders)
            defer { window.orderOut(nil) }
            window.makeFirstResponder(try await timeField(in: hosting))
            try await waitUntil { window.firstResponder is NSTextView }
            for digit in ["1", "4", "3"] {
                type(digit, in: window)
            }
            try await waitUntil { reminders.editor?.hour == 14 && reminders.editor?.minute == 3 }
            #expect(reminders.editor?.minute == 3)

            withAnimation(ReminderComposerView.animation) {
                _ = reminders.saveEditor()
            }
            try await Task.sleep(for: .seconds(1))

            #expect(reminders.editor == nil)
            let saved = try #require(reminders.reminders.first)
            #expect(saved.title == "Appeler Léa")
            #expect(saved.hasTime)
            #expect(saved.due.map { Calendar.current.component(.hour, from: $0) } == 14)
        }
    }
}
