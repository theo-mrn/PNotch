import Defaults
import Foundation
import Observation

/// The reminders and their ringing. Sleeps until the next one rather than watching the clock.
@Observable
final class RemindersManager {
    private(set) var board: ReminderBoard
    /// Reminders ringing, until the page has been seen.
    private(set) var ringing: Set<Reminder.ID> = []
    /// The last reminder written, for the page to show it.
    private(set) var lastAdded: Reminder.ID?
    /// Ticked, about to leave: a second click keeps them.
    private(set) var finishing: Set<Reminder.ID> = []
    /// The reminder being written or changed, if any.
    var editor: ReminderEditorState?

    /// Reminders came due: the ones to ring, soonest first.
    @ObservationIgnored var onRing: (([Reminder]) -> Void)?
    @ObservationIgnored private let now: () -> Date
    /// The layout chosen in Settings, which decides how tall the page is.
    @ObservationIgnored private let layout: () -> RemindersLayout
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let saveItems: ([Reminder]) -> Void
    @ObservationIgnored private var ringTask: Task<Void, Never>?
    @ObservationIgnored private var finishTasks: [Reminder.ID: Task<Void, Never>] = [:]

    /// How long a ticked reminder stays, its box filled, before it leaves.
    static let finishDelay: Duration = .milliseconds(800)

    init(
        now: @escaping () -> Date = { .now },
        calendar: Calendar = .current,
        items: [Reminder] = Defaults[.reminders],
        saveItems: @escaping ([Reminder]) -> Void = { Defaults[.reminders] = $0 },
        layout: @escaping () -> RemindersLayout = { Defaults[.remindersLayout] }
    ) {
        self.layout = layout
        self.now = now
        self.calendar = calendar
        self.saveItems = saveItems
        board = ReminderBoard(items: items)
    }

    var isRinging: Bool {
        !ringing.isEmpty
    }

    /// In the order they show.
    var reminders: [Reminder] {
        board.sorted
    }

    /// Reads what's typed.
    func draft(for text: String) -> ReminderDraft {
        ReminderDraftParser.parse(text, now: now(), calendar: calendar)
    }

    /// How much of the page shows: the reminders, the editor, or the editor and its settings.
    var panel: RemindersPanel {
        guard let editor else {
            if layout() == .list, !reminders.isEmpty {
                return .list(rows: min(reminders.count, RemindersMetrics.maxListRows))
            }
            return .browse
        }
        return editor.showsSettings ? .settings : .compose
    }

    // MARK: Editor

    func openEditor(_ target: ReminderEditorTarget) {
        switch target {
        case .new:
            editor = ReminderEditorState(newAt: now(), calendar: calendar)
        case let .edit(id):
            guard let reminder = board.items.first(where: { $0.id == id }) else { return }
            editor = ReminderEditorState(editing: reminder, at: now(), calendar: calendar)
        }
    }

    func closeEditor() {
        editor = nil
    }

    /// The editor's text changed: a date or a repeat written in it sets the settings.
    func readEditorText() {
        guard let text = editor?.text else { return }
        editor?.read(draft(for: text), calendar: calendar)
    }

    /// What the editor would save.
    var editorDraft: ReminderDraft? {
        editor.map { $0.draft(from: draft(for: $0.text), calendar: calendar) }
    }

    /// Saves the editor's reminder and closes it. Returns whether there was something to save.
    @discardableResult
    func saveEditor() -> Bool {
        guard let editor, let draft = editorDraft, !draft.title.isEmpty else { return false }
        switch editor.target {
        case .new:
            add(draft)
        case let .edit(id):
            update(id, with: draft)
        }
        self.editor = nil
        return true
    }

    /// Deletes the reminder being changed.
    func deleteEditorReminder() {
        if case let .edit(id) = editor?.target {
            remove(id)
        }
        editor = nil
    }

    // MARK: Lifecycle

    /// Rings what came due while PNotch was closed, then waits for the next one.
    func start() {
        checkRinging()
    }

    func stop() {
        ringTask?.cancel()
        ringTask = nil
        // Ticked before quitting: done.
        for id in finishing {
            finishTasks.removeValue(forKey: id)?.cancel()
            board.complete(id, at: now(), calendar: calendar)
        }
        if !finishing.isEmpty {
            finishing.removeAll()
            saveItems(board.items)
        }
    }

    // MARK: Changes

    /// Adds a reminder written in plain words. Returns it, or `nil` if there was nothing to add.
    @discardableResult
    func add(_ text: String) -> Reminder? {
        add(ReminderDraftParser.parse(text, now: now(), calendar: calendar))
    }

    /// Adds a reminder set in the editor.
    @discardableResult
    func add(_ draft: ReminderDraft) -> Reminder? {
        guard let item = board.add(draft, at: now()) else { return nil }
        lastAdded = item.id
        changed()
        return item
    }

    /// Changes a reminder from the editor.
    func update(_ id: Reminder.ID, with draft: ReminderDraft) {
        board.update(id, with: draft, at: now())
        ringing.remove(id)
        changed()
    }

    /// Ticks a reminder: in a moment it leaves, or comes back at its next occurrence, unless ticked again.
    func toggleDone(_ id: Reminder.ID) {
        if finishing.remove(id) != nil {
            finishTasks.removeValue(forKey: id)?.cancel()
            return
        }
        finishing.insert(id)
        ringing.remove(id)
        finishTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: Self.finishDelay)
            guard !Task.isCancelled, let self else { return }
            finishTasks[id] = nil
            finishing.remove(id)
            board.complete(id, at: now(), calendar: calendar)
            changed()
        }
    }

    /// Deleted.
    func remove(_ id: Reminder.ID) {
        board.remove(id)
        ringing.remove(id)
        changed()
    }

    /// « +10 min ».
    func snooze(_ id: Reminder.ID) {
        board.snooze(id, at: now())
        ringing.remove(id)
        changed()
    }

    /// The reminders ringing were seen.
    func stopRinging() {
        ringing.removeAll()
    }

    /// Rings the reminders that came due, then waits for the next one.
    func checkRinging() {
        let before = board
        let due = board.takeDue(at: now())
        if board != before {
            saveItems(board.items)
        }
        if !due.isEmpty {
            ringing.formUnion(due.map(\.id))
            // A new reminder not written yet makes way for the one ringing.
            if let editor, editor.target == .new, editor.text.allSatisfy(\.isWhitespace) {
                self.editor = nil
            }
            onRing?(due)
        }
        scheduleNextRing()
    }

    // MARK: Private

    private func changed() {
        saveItems(board.items)
        scheduleNextRing()
    }

    /// Sleeps until the next reminder; nothing runs without one.
    private func scheduleNextRing() {
        ringTask?.cancel()
        ringTask = nil
        guard let next = board.nextRinging else { return }
        let wait = max(next.timeIntervalSince(now()), 0)
        ringTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait) + .milliseconds(50))
            guard !Task.isCancelled else { return }
            self?.checkRinging()
        }
    }
}
