import Defaults
import KeyboardShortcuts
import SwiftUI

@main
struct PNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Default(.menubarIcon) private var showMenuBarIcon

    var body: some Scene {
        MenuBarExtra("PNotch", systemImage: "rectangle.topthird.inset.filled", isInserted: $showMenuBarIcon) {
            Button("Open Clipboard") {
                appDelegate.showClipboardList()
            }
            Button("Settings…") {
                appDelegate.showSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            if appDelegate.updates.isAvailable {
                Button("Check for Updates…") {
                    appDelegate.updates.checkForUpdates()
                }
            }
            Divider()
            Button("Quit PNotch") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = PNotchViewCoordinator()
    private var notchViewModel: PNotchViewModel?
    private var clipboard: ClipboardStateViewModel?
    private var music: MusicManager?
    private let systemMonitor = SystemMonitor()
    private var companion: CompanionManager?
    private let claudeCode = ClaudeCodeManager()
    private let focus = FocusManager()
    private let reminders = RemindersManager()
    private let notes = NotesManager()
    let updates = UpdateManager()
    private var notchWindowController: NotchWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var screenParametersObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_: Notification) {
        // Unit tests are hosted by the app: keep the process inert so they don't touch the real pasteboard.
        guard !ProcessInfo.processInfo.isRunningTests else { return }

        let clipboard = ClipboardStateViewModel()
        let music = MusicManager()
        let companion = CompanionManager(music: music, system: systemMonitor)
        let notchViewModel = PNotchViewModel(screen: .preferredNotchScreen)

        clipboard.onItemCaptured = { [weak self] item in
            self?.companion?.noteCopy()
            self?.showCaptureSneakPeek(for: item)
        }
        clipboard.onItemCopied = { [weak notchViewModel] _ in
            notchViewModel?.closeAfterCopy()
        }
        clipboard.onItemPasted = { [weak notchViewModel] _ in
            notchViewModel?.dismissForPaste()
            PasteService.pasteIntoFrontmostApp()
        }
        notchViewModel.listItemCount = { [weak clipboard] in
            clipboard?.visibleItems.count ?? 0
        }
        notchViewModel.remindersPanel = { [reminders] in
            reminders.panel
        }
        // A permission request waiting in the notch, or a reminder ringing: opening it goes straight there.
        notchViewModel.urgentPage = { [claudeCode, reminders] in
            let modules = NotchModules.current
            if !claudeCode.approvals.isEmpty, modules.isInstalled(.claudeCode) {
                return .claudeCode
            }
            if reminders.isRinging, modules.isInstalled(.reminders) {
                return .reminders
            }
            return nil
        }
        coordinator.onShowSettings = { [weak self] in
            self?.showSettings()
        }
        claudeCode.onTransition = { [weak self] session, transition in
            self?.handleClaudeCode(session, transition)
        }
        focus.onEvent = { [weak self] event in
            self?.handleFocus(event)
        }
        reminders.onRing = { [weak self] due in
            self?.handleReminder(due)
        }

        self.clipboard = clipboard
        self.music = music
        self.companion = companion
        self.notchViewModel = notchViewModel
        notchWindowController = NotchWindowController(
            viewModel: notchViewModel,
            coordinator: coordinator,
            clipboard: clipboard,
            music: music,
            system: systemMonitor,
            companion: companion,
            claudeCode: claudeCode,
            focus: focus,
            reminders: reminders,
            notes: notes
        )

        // Key down rather than up: holding the shortcut keeps scrolling through the list.
        KeyboardShortcuts.onKeyDown(for: .clipboardList) { [weak self] in
            self?.handleClipboardListShortcut()
        }
        observeScreenParameters()
        clipboard.start()
        music.start()
        claudeCode.start()
        focus.start()
        reminders.start()

        if !LaunchContext.wasLaunchedAtLogin {
            notchViewModel.open(reason: .launch)
        }
    }

    func applicationWillTerminate(_: Notification) {
        clipboard?.flushPendingChanges()
        music?.stop()
        claudeCode.stop()
        focus.stop()
        reminders.stop()
        notes.flush()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    /// Opens the searchable list, focused and ready to type in.
    func showClipboardList() {
        guard let notchViewModel, let clipboard else { return }
        clipboard.filter = .all
        notchViewModel.open(reason: .keyboard, page: .clipboard)
    }

    /// First press opens the list, the following ones move down through it, like ⌘Tab.
    private func handleClipboardListShortcut() {
        guard let notchViewModel, let clipboard else { return }
        if notchViewModel.isShowingClipboard {
            clipboard.moveSelection(by: 1, wrapping: true)
        } else {
            showClipboardList()
        }
    }

    func showSettings() {
        guard let clipboard else { return }
        notchViewModel?.close(reason: .settings)

        let controller = settingsWindowController
            ?? SettingsWindowController(clipboard: clipboard, updates: updates, claudeCode: claudeCode)
        settingsWindowController = controller
        controller.present()
    }

    private func showCaptureSneakPeek(for item: ClipboardItem) {
        guard Defaults[.showCopySneakPeek], notchViewModel?.notchState == .closed else { return }
        coordinator.showSneakPeek(SneakPeek(item: item))
    }

    /// The robot brings the news; a sneak peek tells a finished turn, unless it was a quick one in plain sight.
    /// Waiting for the user needs no sneak peek: the closed notch keeps showing it until answered.
    private func handleClaudeCode(_ session: ClaudeCodeSession, _ transition: ClaudeCodeSession.Transition) {
        switch transition {
        case .startedWaiting:
            companion?.bring(.claudeCodeNeedsYou)
        case let .finished(turnDuration):
            guard ClaudeCodeAttention.announcesFinish(turnDuration: turnDuration, hostIsFrontmost: claudeCode.isFrontmost(session)) else {
                return
            }
            companion?.bring(.claudeCodeFinished)
            showClaudeCodeSneakPeek(.finished)
        case .failed:
            showClaudeCodeSneakPeek(.failed)
        }
    }

    /// The robot cheers a completed session, a chime rings, and the closed notch shows it.
    private func handleFocus(_ event: FocusTimer.Event) {
        companion?.bring(event == .focusFinished ? .focusDone : .breakOver)
        if Defaults[.focusPlaysSound] {
            NSSound(named: event == .focusFinished ? "Glass" : "Hero")?.play()
        }
        if notchViewModel?.notchState == .closed {
            coordinator.showSneakPeek(SneakPeek(focus: event), duration: .seconds(3))
        }
    }

    /// A reminder's time has come: Pixel brings the news, a chime rings, and the notch opens on it
    /// unless it's already open, where the tab shows a dot.
    private func handleReminder(_ due: [Reminder]) {
        guard NotchModules.current.isInstalled(.reminders) else { return }
        companion?.bring(.reminder)
        if Defaults[.remindersPlaySound] {
            NSSound(named: "Submarine")?.play()
        }
        guard let notchViewModel, notchViewModel.notchState == .closed else { return }
        notchViewModel.open(reason: .reminder, page: .reminders)
    }

    private func showClaudeCodeSneakPeek(_ outcome: SneakPeek.ClaudeCodeOutcome) {
        guard Defaults[.announceClaudeCode], notchViewModel?.notchState == .closed else { return }
        coordinator.showSneakPeek(SneakPeek(claudeCode: outcome), duration: .seconds(3))
    }

    private func observeScreenParameters() {
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.notchWindowController?.updateScreen(.preferredNotchScreen)
            }
        }
    }
}
