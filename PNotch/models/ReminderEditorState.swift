import Foundation

/// What the editor is open on.
nonisolated enum ReminderEditorTarget: Hashable, Sendable {
    case new
    case edit(Reminder.ID)
}

/// How much of the Reminders page shows, which sets the height of the notch.
nonisolated enum RemindersPanel: Equatable, Sendable {
    /// The reminders, in the chosen layout.
    case browse
    /// The reminders as a list, as tall as its rows, up to `RemindersMetrics.maxListRows`.
    case list(rows: Int)
    /// The text of a reminder being written.
    case compose
    /// Its date, time and options too, the notch unfolded.
    case settings
    /// A reminder ringing: Pixel brings it, in a small notch, to snooze or mark done.
    case alert
}

/// The reminder being written: its text first; its date, time and options behind the settings button.
/// A date written in the text (« demain à 14h ») sets them too.
nonisolated struct ReminderEditorState: Equatable, Sendable {
    var target: ReminderEditorTarget
    var text = ""
    var note = ""
    var hasDate = false
    /// The day it gets once it has a date: today until another is picked.
    var day: Date
    var hasTime = false
    var hour: Int
    var minute: Int
    /// `nil`: it doesn't repeat.
    var frequency: ReminderFrequency?
    var repeatEnd: ReminderRepeatEnd = .never
    var earlyAlert: TimeInterval?
    var showsSettings = false
    /// What the text last gave, so a date picked by hand isn't overridden at every keystroke.
    private var readDue: Date?
    private var readFrequency: ReminderFrequency?

    /// A new reminder, without a date yet. Given one, it's today; given a time, the next full hour.
    init(newAt now: Date, calendar: Calendar = .current) {
        target = .new
        let nextHour = calendar.nextDate(after: now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime) ?? now
        day = calendar.startOfDay(for: nextHour)
        hour = calendar.component(.hour, from: nextHour)
        minute = calendar.component(.minute, from: nextHour)
    }

    init(editing reminder: Reminder, at now: Date, calendar: Calendar = .current) {
        self.init(newAt: now, calendar: calendar)
        target = .edit(reminder.id)
        text = reminder.title
        note = reminder.note
        if let due = reminder.due {
            hasDate = true
            day = calendar.startOfDay(for: due)
            hasTime = reminder.hasTime
            if reminder.hasTime {
                hour = calendar.component(.hour, from: due)
                minute = calendar.component(.minute, from: due)
            }
        }
        frequency = reminder.repeatRule?.frequency
        repeatEnd = reminder.repeatRule?.end ?? .never
        earlyAlert = reminder.earlyAlert
    }

    /// The text was read: a date or a repeat written in it sets the date, the time and the repeat,
    /// once per new one found.
    mutating func read(_ parsed: ReminderDraft, calendar: Calendar = .current) {
        if let found = parsed.due, found != readDue {
            readDue = found
            hasDate = true
            day = calendar.startOfDay(for: found)
            hasTime = parsed.hasTime
            if parsed.hasTime {
                hour = calendar.component(.hour, from: found)
                minute = calendar.component(.minute, from: found)
            }
        }
        if let found = parsed.repeatRule?.frequency, found != readFrequency {
            readFrequency = found
            frequency = found
        }
    }

    func due(calendar: Calendar = .current) -> Date? {
        guard hasDate else { return nil }
        guard hasTime else { return day }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }

    /// What gets saved. The words that gave a date leave the title.
    func draft(from parsed: ReminderDraft, calendar: Calendar = .current) -> ReminderDraft {
        let readSomething = parsed.due != nil || parsed.repeatRule != nil
        return ReminderDraft(
            title: (readSomething ? parsed.title : text).trimmingCharacters(in: .whitespacesAndNewlines),
            due: due(calendar: calendar),
            hasTime: hasDate && hasTime,
            repeatRule: hasDate ? frequency.map { ReminderRepeat(frequency: $0, end: repeatEnd) } : nil,
            note: note,
            earlyAlert: hasDate && hasTime ? earlyAlert : nil
        )
    }
}
