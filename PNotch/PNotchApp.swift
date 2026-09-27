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
    let updates = UpdateManager()
    private var notchWindowController: NotchWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var screenParametersObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_: Notification) {
        // Unit tests are hosted by the app: keep the process inert so they don't touch the real pasteboard.
        guard !ProcessInfo.processInfo.isRunningTests else { return }

        let clipboard = ClipboardStateViewModel()
        let music = MusicManager()
        let notchViewModel = PNotchViewModel(screen: .preferredNotchScreen)

        clipboard.onItemCaptured = { [weak self] item in
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
        coordinator.onShowSettings = { [weak self] in
            self?.showSettings()
        }

        self.clipboard = clipboard
        self.music = music
        self.notchViewModel = notchViewModel
        notchWindowController = NotchWindowController(
            viewModel: notchViewModel,
            coordinator: coordinator,
            clipboard: clipboard,
            music: music,
            system: systemMonitor
        )

        // Key down rather than up: holding the shortcut keeps scrolling through the list.
        KeyboardShortcuts.onKeyDown(for: .clipboardList) { [weak self] in
            self?.handleClipboardListShortcut()
        }
        observeScreenParameters()
        clipboard.start()
        music.start()

        if !LaunchContext.wasLaunchedAtLogin {
            notchViewModel.open(reason: .launch)
        }
    }

    func applicationWillTerminate(_: Notification) {
        clipboard?.flushPendingChanges()
        music?.stop()
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
            ?? SettingsWindowController(clipboard: clipboard, updates: updates)
        settingsWindowController = controller
        controller.present()
    }

    private func showCaptureSneakPeek(for item: ClipboardItem) {
        guard Defaults[.showCopySneakPeek], notchViewModel?.notchState == .closed else { return }
        coordinator.showSneakPeek(SneakPeek(item: item))
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
