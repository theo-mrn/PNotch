import Defaults
import Foundation

/// A reminder: something to do, and when. A time of day rings, and can ring earlier too; a day alone only shows.
/// It can come back: every day, every week…
nonisolated struct Reminder: Equatable, Identifiable, Codable, Sendable, Defaults.Serializable {
    var id = UUID()
    var title: String
    /// A few lines under the title.
    var note = ""
    var due: Date?
    /// Whether `due` has a time of day, which rings, or is only a day.
    var hasTime = false
    var repeatRule: ReminderRepeat?
    /// How long before its time it rings first.
    var earlyAlert: TimeInterval?
    var createdAt: Date
    /// Set by earlier versions, where done reminders stayed on the list for the day.
    var completedAt: Date?
    /// « +10 min »: it rings again then, instead of at its time.
    var snoozedUntil: Date?
    /// It has rung at its time, or that was missed.
    var reminded = false
    /// Its early alert has rung, or was missed.
    var earlyReminded = false

    init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        due: Date? = nil,
        hasTime: Bool = false,
        repeatRule: ReminderRepeat? = nil,
        earlyAlert: TimeInterval? = nil,
        createdAt: Date,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.due = due
        self.hasTime = hasTime
        self.repeatRule = repeatRule
        self.earlyAlert = earlyAlert
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    /// When it rings next: its early alert, then its time, or the time it was snoozed to.
    var nextRing: Date? {
        guard hasTime, let due else { return nil }
        if let earlyAlert, !earlyReminded, snoozedUntil == nil {
            return due.addingTimeInterval(-earlyAlert)
        }
        return reminded ? nil : snoozedUntil ?? due
    }

    /// It still has to ring.
    var awaitsRinging: Bool {
        nextRing != nil
    }

    /// Past its time, or past its day for a reminder without a time.
    func isOverdue(at date: Date, calendar: Calendar = .current) -> Bool {
        guard let due else { return false }
        return hasTime ? due < date : due < calendar.startOfDay(for: date)
    }

    /// Notes what has rung by `date`: nothing rings for a time already gone.
    fileprivate mutating func settleRinging(at date: Date) {
        snoozedUntil = nil
        guard hasTime, let due else {
            reminded = false
            earlyReminded = false
            return
        }
        reminded = due <= date
        earlyReminded = earlyAlert.map { due.addingTimeInterval(-$0) <= date } ?? false
    }

    fileprivate mutating func markNextRing() {
        if earlyAlert != nil, !earlyReminded, snoozedUntil == nil {
            earlyReminded = true
        } else {
            reminded = true
            snoozedUntil = nil
        }
    }

    // Reminders saved by earlier versions lack the newer fields.
    private enum CodingKeys: String, CodingKey {
        case id, title, note, due, hasTime, repeatRule, earlyAlert, createdAt, completedAt, snoozedUntil, reminded, earlyReminded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        due = try container.decodeIfPresent(Date.self, forKey: .due)
        hasTime = try container.decodeIfPresent(Bool.self, forKey: .hasTime) ?? false
        repeatRule = try container.decodeIfPresent(ReminderRepeat.self, forKey: .repeatRule)
        earlyAlert = try container.decodeIfPresent(TimeInterval.self, forKey: .earlyAlert)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        snoozedUntil = try container.decodeIfPresent(Date.self, forKey: .snoozedUntil)
        reminded = try container.decodeIfPresent(Bool.self, forKey: .reminded) ?? false
        earlyReminded = try container.decodeIfPresent(Bool.self, forKey: .earlyReminded) ?? false
    }
}

// MARK: - Repeating

nonisolated enum ReminderFrequency: String, Codable, CaseIterable, Sendable {
    case daily
    /// Monday to Friday.
    case weekdays
    case weekly
    case monthly
    case yearly

    /// The occurrence after `date`.
    func next(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekdays:
            var next = calendar.date(byAdding: .day, value: 1, to: date)
            while let day = next, calendar.isDateInWeekend(day) {
                next = calendar.date(byAdding: .day, value: 1, to: day)
            }
            return next
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }
}

/// When a repeating reminder stops coming back.
nonisolated enum ReminderRepeatEnd: Codable, Equatable, Hashable, Sendable {
    case never
    /// After this many more times, the current one included.
    case after(Int)
    /// No occurrence after this day.
    case on(Date)
}

nonisolated struct ReminderRepeat: Codable, Equatable, Sendable {
    var frequency: ReminderFrequency
    var end: ReminderRepeatEnd = .never
}

/// When reminders ring, and for how long they wait.
nonisolated enum ReminderTiming {
    /// How long after its time a reminder still rings. One missed for longer, PNotch closed or the Mac off,
    /// only shows as overdue.
    static let freshness: TimeInterval = 60 * 60
    /// « +10 min ».
    static let snooze: TimeInterval = 5 * 60
    /// What an early alert can be: 5, 15 or 30 minutes, an hour or a day before.
    static let earlyAlerts: [TimeInterval] = [5 * 60, 15 * 60, 30 * 60, 60 * 60, 24 * 60 * 60]

    /// The editor's minutes go by five. The next multiple of five: 37 → 40, 55 → 0.
    static func minute(after minute: Int) -> Int {
        (minute / 5 + 1) * 5 % 60
    }

    /// The previous multiple of five: 37 → 35, 35 → 30, 0 → 55.
    static func minute(before minute: Int) -> Int {
        let previous = minute % 5 == 0 ? minute - 5 : minute / 5 * 5
        return (previous + 60) % 60
    }
}

/// Typing a time in the editor, as in a clock's time field.
nonisolated enum TimeEntry {
    enum Part: Hashable, Sendable {
        case hour
        case minute
    }

    /// What `text` sets: its last two digits, the value they give (capped at 23 or 59), and whether the part is
    /// complete: two digits, or one no other can follow (3 to 9 for the hour, 6 to 9 for the minutes).
    static func read(_ text: String, for part: Part) -> (digits: String, value: Int?, isComplete: Bool) {
        let digits = String(text.filter { $0.isASCII && $0.isNumber }.suffix(2))
        guard let value = Int(digits) else { return ("", nil, false) }
        let maximum = part == .hour ? 23 : 59
        let firstDigitLimit = part == .hour ? 2 : 5
        let isComplete = digits.count == 2 || value > firstDigitLimit
        return (digits, min(value, maximum), isComplete)
    }

    /// What typing `text` in one go sets, from the hours or from the minutes: the hours take their digits
    /// until complete, the rest goes to the minutes. Digits past the minutes are left out.
    struct Typing: Equatable, Sendable {
        /// The digits used.
        var digits = ""
        var hour: Int?
        var minute: Int?
        /// Where the next digit goes.
        var next: Part
        /// The minutes are complete: nothing more to type.
        var isComplete = false
    }

    static func type(_ text: String, from start: Part) -> Typing {
        var remaining = Array(text.filter { $0.isASCII && $0.isNumber })
        var typing = Typing(next: start)

        func take(_ part: Part) -> (value: Int?, isComplete: Bool) {
            var digits = ""
            var reading = read(digits, for: part)
            while !reading.isComplete, !remaining.isEmpty {
                digits.append(remaining.removeFirst())
                reading = read(digits, for: part)
            }
            typing.digits += digits
            return (reading.value, reading.isComplete)
        }

        if start == .hour {
            let hour = take(.hour)
            typing.hour = hour.value
            guard hour.isComplete else { return typing }
            typing.next = .minute
        }
        let minute = take(.minute)
        typing.minute = minute.value
        typing.isComplete = minute.isComplete
        return typing
    }
}

// MARK: - Board

/// The reminders, soonest first, then the ones without a date in the order they were written.
/// A reminder done leaves the list, or comes back at its next occurrence.
nonisolated struct ReminderBoard: Equatable, Sendable {
    private(set) var items: [Reminder]

    init(items: [Reminder] = []) {
        self.items = items.filter { $0.completedAt == nil }
    }

    /// Adds a reminder, unless its title is empty.
    @discardableResult
    mutating func add(_ draft: ReminderDraft, at date: Date) -> Reminder? {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        var item = Reminder(title: title, createdAt: date)
        item.apply(draft)
        item.settleRinging(at: date)
        items.append(item)
        return item
    }

    /// Changes what and when. A time still to come rings again; one already gone doesn't.
    mutating func update(_ id: Reminder.ID, with draft: ReminderDraft, at date: Date) {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let index = index(of: id) else { return }
        items[index].title = title
        items[index].apply(draft)
        items[index].settleRinging(at: date)
    }

    /// Done: it leaves, or comes back at its next occurrence still to come.
    mutating func complete(_ id: Reminder.ID, at date: Date, calendar: Calendar = .current) {
        guard let index = index(of: id) else { return }
        guard let rule = items[index].repeatRule, let due = items[index].due else {
            items.remove(at: index)
            return
        }
        let hasTime = items[index].hasTime
        let today = calendar.startOfDay(for: date)
        var next = rule.frequency.next(after: due, calendar: calendar)
        // Occurrences gone while it waited are skipped.
        var steps = 0
        while let occurrence = next, hasTime ? occurrence <= date : occurrence < today, steps < 10000 {
            next = rule.frequency.next(after: occurrence, calendar: calendar)
            steps += 1
        }
        guard let next else {
            items.remove(at: index)
            return
        }
        switch rule.end {
        case .never:
            break
        case let .after(count):
            guard count > 1 else {
                items.remove(at: index)
                return
            }
            items[index].repeatRule?.end = .after(count - 1)
        case let .on(last):
            guard calendar.startOfDay(for: next) <= calendar.startOfDay(for: last) else {
                items.remove(at: index)
                return
            }
        }
        items[index].due = next
        items[index].settleRinging(at: date)
    }

    /// Deleted.
    mutating func remove(_ id: Reminder.ID) {
        items.removeAll { $0.id == id }
    }

    /// Rings again `interval` from now.
    mutating func snooze(_ id: Reminder.ID, by interval: TimeInterval = ReminderTiming.snooze, at date: Date) {
        guard let index = index(of: id) else { return }
        if items[index].due == nil || !items[index].hasTime {
            items[index].due = date.addingTimeInterval(interval)
            items[index].hasTime = true
        }
        items[index].snoozedUntil = date.addingTimeInterval(interval)
        items[index].reminded = false
        items[index].earlyReminded = true
    }

    /// In the order they show.
    var sorted: [Reminder] {
        items.enumerated()
            .sorted { first, second in
                switch (first.element.due, second.element.due) {
                case let (lhs?, rhs?) where lhs != rhs: lhs < rhs
                case (_?, nil): true
                case (nil, _?): false
                default: first.offset < second.offset
                }
            }
            .map(\.element)
    }

    /// When the next reminder rings.
    var nextRinging: Date? {
        items.compactMap(\.nextRing).min()
    }

    /// Marks what was due to ring by `date` as rung, and returns the reminders recent enough to ring, soonest first.
    mutating func takeDue(at date: Date, freshness: TimeInterval = ReminderTiming.freshness) -> [Reminder] {
        var ringing: [(Reminder, Date)] = []
        for index in items.indices {
            var latest: Date?
            while let ring = items[index].nextRing, ring <= date {
                items[index].markNextRing()
                if date.timeIntervalSince(ring) <= freshness {
                    latest = ring
                }
            }
            if let latest {
                ringing.append((items[index], latest))
            }
        }
        return ringing.sorted { $0.1 < $1.1 }.map(\.0)
    }

    private func index(of id: Reminder.ID) -> Int? {
        items.firstIndex { $0.id == id }
    }
}

nonisolated private extension Reminder {
    mutating func apply(_ draft: ReminderDraft) {
        note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        due = draft.due
        hasTime = draft.hasTime && draft.due != nil
        repeatRule = draft.due == nil ? nil : draft.repeatRule
        earlyAlert = hasTime ? draft.earlyAlert : nil
    }
}

// MARK: - Wording

/// How a reminder's date reads: « 14:00 », « Demain », « dans 2 h 15 », « 13/11 » on the LED display.
nonisolated enum ReminderDueFormatter {
    enum Day: Equatable {
        case today
        case tomorrow
        case yesterday
        /// Within the coming week: its weekday says it.
        case thisWeek
        case other
    }

    static func day(of due: Date, at now: Date, calendar: Calendar = .current) -> Day {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: due)).day ?? 0
        return switch days {
        case 0: .today
        case 1: .tomorrow
        case -1: .yesterday
        case 2 ... 6: .thisWeek
        default: .other
        }
    }

    /// The day in words: « Aujourd’hui », « Demain », « Vendredi », « 12 décembre ».
    static func dayName(of due: Date, at now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        return switch day(of: due, at: now, calendar: calendar) {
        case .today: String(localized: "Today")
        case .tomorrow: String(localized: "Tomorrow")
        case .yesterday: String(localized: "Yesterday")
        case .thisWeek: due.formatted(style.weekday(.wide)).localizedCapitalized
        case .other: due.formatted(style.day().month(.wide))
        }
    }

    /// Short, for a list: « 14:00 », « Demain 9:00 », « ven. », « 12 déc. ».
    static func shortLabel(due: Date, hasTime: Bool, at now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        let time = hasTime ? due.formatted(style.hour().minute()) : nil
        let dayText: String? = switch day(of: due, at: now, calendar: calendar) {
        case .today: time == nil ? String(localized: "Today") : nil
        case .tomorrow: String(localized: "Tomorrow")
        case .yesterday: String(localized: "Yesterday")
        case .thisWeek: due.formatted(style.weekday(.abbreviated)).localizedCapitalized
        case .other: due.formatted(style.day().month(.abbreviated))
        }
        return [dayText, time].compactMap(\.self).joined(separator: " ")
    }

    /// For the LED display, which only has digits: « 14:00 », or « 13/11 » for a day.
    static func digits(due: Date, hasTime: Bool, calendar: Calendar = .current, dayFirst: Bool = ReminderDraftParser.dayFirst) -> String {
        let components = calendar.dateComponents([.day, .month, .hour, .minute], from: due)
        if hasTime {
            return String(format: "%02ld:%02ld", components.hour ?? 0, components.minute ?? 0)
        }
        let day = String(format: "%02ld", components.day ?? 0)
        let month = String(format: "%02ld", components.month ?? 0)
        return dayFirst ? "\(day)/\(month)" : "\(month)/\(day)"
    }

    /// « Chaque semaine », « Jamais » for a reminder that doesn't repeat.
    static func repeatName(_ frequency: ReminderFrequency?) -> String {
        switch frequency {
        case nil: String(localized: "Never")
        case .daily: String(localized: "Every day")
        case .weekdays: String(localized: "Weekdays")
        case .weekly: String(localized: "Every week")
        case .monthly: String(localized: "Every month")
        case .yearly: String(localized: "Every year")
        }
    }

    /// « Jamais », « Après 5 fois », « Jusqu’au 6 févr. ».
    static func endName(_ end: ReminderRepeatEnd) -> String {
        switch end {
        case .never: String(localized: "Never")
        case let .after(count): String(localized: "After \(count) times")
        case let .on(date): String(localized: "Until \(date.formatted(.dateTime.day().month(.abbreviated)))")
        }
    }

    /// « 15 min avant », « 1 jour avant », « Aucun ».
    static func earlyAlertName(_ interval: TimeInterval?) -> String {
        guard let interval else { return String(localized: "None") }
        let minutes = Int(interval / 60)
        switch minutes {
        case ..<60: return String(localized: "\(minutes) min before")
        case ..<(24 * 60): return String(localized: "\(minutes / 60) h before")
        default: return String(localized: "\(minutes / (24 * 60)) day before")
        }
    }

    /// How far away a time is, within the day around it: « dans 25 min », « dans 2 h 15 », « C’est l’heure »,
    /// « il y a 10 min ». `nil` further away, or without a time: the day says it.
    static func countdown(to due: Date, hasTime: Bool, at now: Date) -> String? {
        guard hasTime else { return nil }
        let minutes = Int((due.timeIntervalSince(now) / 60).rounded(.up))
        switch minutes {
        case 1 ..< 60:
            return String(localized: "in \(minutes) min")
        case 60 ..< 24 * 60:
            let hours = minutes / 60
            let rest = minutes % 60
            return rest == 0
                ? String(localized: "in \(hours) h")
                : String(localized: "in \(hours) h \(String(format: "%02ld", rest))")
        case -59 ..< 1:
            return minutes > -1 ? String(localized: "It's time") : String(localized: "\(-minutes) min ago")
        default:
            return nil
        }
    }
}
