import Defaults
import SwiftUI

@main
struct PNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Default(.menubarIcon) private var showMenuBarIcon

    var body: some Scene {
        MenuBarExtra("PNotch", systemImage: "rectangle.topthird.inset.filled", isInserted: $showMenuBarIcon) {
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
    private var music: MusicManager?
    let updates = UpdateManager()
    private var notchWindowController: NotchWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var screenParametersObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_: Notification) {
        // Unit tests are hosted by the app: keep the process inert.
        guard !ProcessInfo.processInfo.isRunningTests else { return }

        let music = MusicManager()
        let notchViewModel = PNotchViewModel(screen: .preferredNotchScreen)

        coordinator.onShowSettings = { [weak self] in
            self?.showSettings()
        }

        self.music = music
        self.notchViewModel = notchViewModel
        notchWindowController = NotchWindowController(
            viewModel: notchViewModel,
            coordinator: coordinator,
            music: music
        )

        observeScreenParameters()
        music.start()

        if !LaunchContext.wasLaunchedAtLogin {
            notchViewModel.open(reason: .launch)
        }
    }

    func applicationWillTerminate(_: Notification) {
        music?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    func showSettings() {
        notchViewModel?.close(reason: .settings)

        let controller = settingsWindowController
            ?? SettingsWindowController(updates: updates)
        settingsWindowController = controller
        controller.present()
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
