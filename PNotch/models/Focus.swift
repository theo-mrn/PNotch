import Defaults
import Foundation

/// How long to focus, then rest, in a row.
nonisolated enum FocusRhythm: String, CaseIterable, Codable, Sendable, Defaults.Serializable {
    /// 25 minutes of focus, 5 of rest: the classic Pomodoro.
    case short
    /// 50 minutes of focus, 10 of rest, for deep work.
    case long

    var focusDuration: TimeInterval {
        switch self {
        case .short: 25 * 60
        case .long: 50 * 60
        }
    }

    var breakDuration: TimeInterval {
        switch self {
        case .short: 5 * 60
        case .long: 10 * 60
        }
    }
}

/// A running focus session, break or stopwatch. Kept in the preferences, so it survives quitting PNotch.
nonisolated struct FocusSession: Equatable, Codable, Sendable, Defaults.Serializable {
    enum Phase: String, Codable, Sendable {
        case focus
        /// The break after a focus session.
        case rest
        /// Counts up, with no end.
        case stopwatch
    }

    /// A few more minutes, from the timer's « +5 min ».
    static let extraTime: TimeInterval = 5 * 60

    var phase: Phase
    var startedAt: Date
    /// How long the countdown lasts; 0 for the stopwatch.
    var duration: TimeInterval
    /// When it was paused. `nil` while running.
    var pausedAt: Date?

    static func focus(rhythm: FocusRhythm, at date: Date) -> FocusSession {
        FocusSession(phase: .focus, startedAt: date, duration: rhythm.focusDuration)
    }

    static func rest(rhythm: FocusRhythm, at date: Date) -> FocusSession {
        FocusSession(phase: .rest, startedAt: date, duration: rhythm.breakDuration)
    }

    static func stopwatch(at date: Date) -> FocusSession {
        FocusSession(phase: .stopwatch, startedAt: date, duration: 0)
    }

    var isPaused: Bool {
        pausedAt != nil
    }

    var countsDown: Bool {
        phase != .stopwatch
    }

    /// Time spent running, pauses left out.
    func elapsed(at date: Date) -> TimeInterval {
        max((pausedAt ?? date).timeIntervalSince(startedAt), 0)
    }

    func remaining(at date: Date) -> TimeInterval {
        max(duration - elapsed(at: date), 0)
    }

    /// What the clock shows: the time left, or the time elapsed on the stopwatch.
    func displayedTime(at date: Date) -> TimeInterval {
        countsDown ? remaining(at: date) : elapsed(at: date)
    }

    /// 0 at the start, 1 when the time is up. The stopwatch goes round once a minute.
    func progress(at date: Date) -> Double {
        guard countsDown else { return elapsed(at: date).truncatingRemainder(dividingBy: 60) / 60 }
        guard duration > 0 else { return 1 }
        return 1 - remaining(at: date) / duration
    }

    func isOver(at date: Date) -> Bool {
        countsDown && !isPaused && remaining(at: date) <= 0
    }

    mutating func pause(at date: Date) {
        guard !isPaused else { return }
        pausedAt = date
    }

    /// Picks up where it was paused: the start moves forward by the time spent paused.
    mutating func resume(at date: Date) {
        guard let pausedAt else { return }
        startedAt = startedAt.addingTimeInterval(date.timeIntervalSince(pausedAt))
        self.pausedAt = nil
    }

    /// Adds time to a countdown.
    mutating func extend(by time: TimeInterval) {
        guard countsDown else { return }
        duration += time
    }
}

/// The day's focus: how many sessions were completed, for how long.
nonisolated struct FocusLog: Equatable, Codable, Sendable, Defaults.Serializable {
    /// The start of the day it counts.
    var day: Date
    var completedSessions = 0
    var focusedTime: TimeInterval = 0

    static func empty(at date: Date, calendar: Calendar = .current) -> FocusLog {
        FocusLog(day: calendar.startOfDay(for: date))
    }

    /// The log for the day of `date`: a fresh one once the day has changed.
    func today(at date: Date, calendar: Calendar = .current) -> FocusLog {
        calendar.isDate(day, inSameDayAs: date) ? self : .empty(at: date, calendar: calendar)
    }

    func recording(_ duration: TimeInterval, at date: Date, calendar: Calendar = .current) -> FocusLog {
        var log = today(at: date, calendar: calendar)
        log.completedSessions += 1
        log.focusedTime += duration
        return log
    }

    /// Focused time that isn't a completed session, like a stopwatch.
    func adding(focusedTime time: TimeInterval, at date: Date, calendar: Calendar = .current) -> FocusLog {
        var log = today(at: date, calendar: calendar)
        log.focusedTime += time
        return log
    }
}

/// What happens when the clock runs out.
nonisolated enum FocusTimer {
    enum Event: Equatable, Sendable {
        /// A focus session was completed: the break begins.
        case focusFinished
        /// The break is over: ready for the next session.
        case breakFinished
    }

    struct Step: Equatable, Sendable {
        var session: FocusSession?
        var log: FocusLog
        var event: Event?
    }

    /// Moves on once the current phase is over: focus leads to a break, which leads back to idle.
    /// The break starts when the focus ended, even if PNotch only notices later.
    static func advance(_ session: FocusSession?, log: FocusLog, rhythm: FocusRhythm, at date: Date, calendar: Calendar = .current) -> Step {
        guard let session, session.isOver(at: date) else {
            return Step(session: session, log: log, event: nil)
        }
        let end = session.startedAt.addingTimeInterval(session.duration)
        switch session.phase {
        case .focus:
            let rest = FocusSession.rest(rhythm: rhythm, at: end)
            let log = log.recording(session.duration, at: end, calendar: calendar)
            // Away for longer than the break too: skip straight to idle.
            if rest.isOver(at: date) {
                return Step(session: nil, log: log, event: .breakFinished)
            }
            return Step(session: rest, log: log, event: .focusFinished)
        case .rest:
            return Step(session: nil, log: log, event: .breakFinished)
        case .stopwatch:
            return Step(session: session, log: log, event: nil)
        }
    }
}
