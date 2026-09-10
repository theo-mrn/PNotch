import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Hosts `ContentView` in a `PNotchWindow` pinned to the top of the notched display,
/// and routes keyboard and outside clicks to the view models.
final class NotchWindowController: NSWindowController {
    /// Text editing shortcuts. PNotch never becomes the active app, so the Edit menu can't deliver them.
    private static let editingActions: [String: Selector] = [
        "a": #selector(NSResponder.selectAll(_:)),
        "c": #selector(NSText.copy(_:)),
        "v": #selector(NSText.paste(_:)),
        "x": #selector(NSText.cut(_:)),
        "z": Selector(("undo:")),
    ]

    private let viewModel: PNotchViewModel
    private var keyDownMonitor: EventMonitor?
    private var outsideClickMonitor: EventMonitor?

    init(
        viewModel: PNotchViewModel,
        coordinator: PNotchViewCoordinator,
        music: MusicManager
    ) {
        self.viewModel = viewModel

        let window = PNotchWindow(contentRect: viewModel.geometry.windowFrame)
        super.init(window: window)

        let rootView = ContentView()
            .environment(viewModel)
            .environment(coordinator)
            .environment(music)
        let hostingView = NSHostingView(rootView: rootView)
        // The window frame is driven by the display geometry, never by the SwiftUI content.
        hostingView.sizingOptions = []
        window.contentView = hostingView
        window.setFrame(viewModel.geometry.windowFrame, display: false)
        window.orderFrontRegardless()

        viewModel.onKeyboardFocusRequest = { [weak self] wantsFocus in
            self?.setKeyboardFocus(wantsFocus)
        }
        viewModel.isKeyboardFocused = { [weak window] in
            window?.isKeyWindow == true
        }
        installEventMonitors()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateScreen(_ screen: NSScreen?) {
        viewModel.updateGeometry(for: screen)
        window?.setFrame(viewModel.geometry.windowFrame, display: true)
    }

    // MARK: Keyboard focus

    private func setKeyboardFocus(_ wantsFocus: Bool) {
        guard let window else { return }

        if wantsFocus {
            window.makeKey()
        } else if window.isKeyWindow {
            // A non-activating panel can't hand key status back directly: ordering it out returns
            // the keyboard to the frontmost app, so ⌘V lands where the user was typing.
            window.orderOut(nil)
            window.orderFrontRegardless()
        }
    }

    // MARK: Event monitors

    private func installEventMonitors() {
        keyDownMonitor = .local(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event) ?? event
        }
        outsideClickMonitor = .global(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.viewModel.handleClick(at: NSEvent.mouseLocation)
        }
    }

    /// Keyboard handling inside the opened notch. Returns `nil` when the event was handled.
    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard viewModel.notchState == .open, event.window === window else { return event }

        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let isEditingText = window?.firstResponder is NSTextView
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

        if isEditingText, modifiers == .command, let action = Self.editingActions[key] {
            return NSApp.sendAction(action, to: nil, from: self) ? nil : event
        }
        if isEditingText, modifiers == [.command, .shift], key == "z" {
            return NSApp.sendAction(Selector(("redo:")), to: nil, from: self) ? nil : event
        }

        // esc closes the notch; while writing, it first stops writing. The rest belongs to text fields.
        guard Int(event.keyCode) == kVK_Escape else { return event }
        if isEditingText {
            window?.makeFirstResponder(nil)
        } else {
            viewModel.close(reason: .escape)
        }
        return nil
    }
}
