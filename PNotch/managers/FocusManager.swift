import Defaults
import Foundation
import Observation

/// Focus sessions with the companion: a session, then a break, then ready for the next one.
@Observable
final class FocusManager {
    private(set) var session: FocusSession?
    private(set) var log: FocusLog

    /// A session or a break came to an end.
    @ObservationIgnored var onEvent: ((FocusTimer.Event) -> Void)?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var ticking: Task<Void, Never>?

    init(now: @escaping () -> Date = { .now }) {
        self.now = now
        session = Defaults[.focusSession]
        log = (Defaults[.focusLog] ?? .empty(at: now())).today(at: now())
    }

    var rhythm: FocusRhythm {
        get { Defaults[.focusRhythm] }
        set { Defaults[.focusRhythm] = newValue }
    }

    /// The day's log, fresh after midnight.
    var today: FocusLog {
        log.today(at: now())
    }

    /// What the companion is busy with, while the clock runs.
    var runningPhase: FocusSession.Phase? {
        guard let session, !session.isPaused else { return nil }
        return session.phase
    }

    // MARK: Lifecycle

    /// Catches up with a session that ended while PNotch was closed, then waits for the next end.
    func start() {
        tick()
        scheduleNextTick()
    }

    func stop() {
        ticking?.cancel()
        ticking = nil
    }

    // MARK: Controls

    func startFocus() {
        update(.focus(rhythm: rhythm, at: now()))
    }

    func startStopwatch() {
        update(.stopwatch(at: now()))
    }

    /// « +5 min » on a countdown.
    func addTime() {
        guard var session else { return }
        session.extend(by: FocusSession.extraTime)
        update(session)
    }

    func pause() {
        guard var session else { return }
        session.pause(at: now())
        update(session)
    }

    func resume() {
        guard var session else { return }
        session.resume(at: now())
        update(session)
    }

    /// Ends the focus session or the break early: an interrupted session isn't counted.
    /// A stopwatch counts its time as focused time.
    func cancel() {
        if let session, session.phase == .stopwatch {
            let date = now()
            log = log.adding(focusedTime: session.elapsed(at: date), at: date)
            Defaults[.focusLog] = log
        }
        update(nil)
    }

    /// Checks the clock: called when the countdown should be over.
    func tick() {
        let step = FocusTimer.advance(session, log: log, rhythm: rhythm, at: now())
        guard let event = step.event else {
            scheduleNextTick()
            return
        }
        log = step.log
        Defaults[.focusLog] = step.log
        update(step.session)
        onEvent?(event)
    }

    // MARK: Private

    private func update(_ session: FocusSession?) {
        self.session = session
        Defaults[.focusSession] = session
        scheduleNextTick()
    }

    /// Sleeps until the running countdown is over, rather than checking every second.
    /// Nothing runs while paused, on the stopwatch, or without a session.
    private func scheduleNextTick() {
        ticking?.cancel()
        ticking = nil
        guard let session, session.countsDown, !session.isPaused else { return }
        let wait = session.remaining(at: now())
        ticking = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait) + .milliseconds(50))
            guard !Task.isCancelled else { return }
            self?.tick()
        }
    }
}
