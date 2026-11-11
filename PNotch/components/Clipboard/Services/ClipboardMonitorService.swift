import AppKit

/// Watches the pasteboard for new content.
///
/// macOS has no pasteboard change notification: like every clipboard manager, this polls `changeCount`,
/// which is a cheap integer read. Twice a second, with some slack for macOS to group the wake-ups with
/// others, and not at all while the screens sleep or the session is locked: nothing gets copied then.
final class ClipboardMonitorService {
    var onChange: (() -> Void)?

    private let pasteboard: NSPasteboard
    private let pollingInterval: Duration
    private var lastChangeCount: Int
    private var pollingTask: Task<Void, Never>?
    private var isRunning = false
    private var observers: [NSObjectProtocol] = []

    init(pasteboard: NSPasteboard = .general, pollingInterval: Duration = .milliseconds(500)) {
        self.pasteboard = pasteboard
        self.pollingInterval = pollingInterval
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        lastChangeCount = pasteboard.changeCount
        observeScreensAndSession()
        startPolling()
    }

    func stop() {
        isRunning = false
        stopPolling()
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
    }

    /// Marks the current pasteboard content as already seen. Called after PNotch writes to the pasteboard itself.
    func skipCurrentChange() {
        lastChangeCount = pasteboard.changeCount
    }

    private func startPolling() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self, pollingInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: pollingInterval, tolerance: pollingInterval / 4)
                self?.checkForChanges()
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Pauses while the screens sleep or another user has the session; back, it looks at once.
    private func observeScreensAndSession() {
        let center = NSWorkspace.shared.notificationCenter
        let pauses: [Notification.Name] = [NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification]
        let resumes: [Notification.Name] = [NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification]
        for name in pauses {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.stopPolling() }
            })
        }
        for name in resumes {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.isRunning else { return }
                    self.checkForChanges()
                    self.startPolling()
                }
            })
        }
    }

    private func checkForChanges() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount
        onChange?()
    }
}
