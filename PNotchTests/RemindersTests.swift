import Foundation
import Testing
@testable import PNotch

/// A calendar in Paris, and Friday, November 6th 2026 at 10:00.
nonisolated private enum RemindersFixture {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    static let now = date(2026, 11, 6, 10, 0)

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}

struct ReminderDraftParserTests {
    private typealias F = RemindersFixture

    private func parse(_ text: String, dayFirst: Bool = true) -> ReminderDraft {
        ReminderDraftParser.parse(text, now: F.now, calendar: F.calendar, dayFirst: dayFirst)
    }

    nonisolated struct Case: Sendable, CustomTestStringConvertible {
        let text: String
        let title: String
        let due: Date?
        var hasTime = false

        var testDescription: String {
            text
        }
    }

    @Test(arguments: [
        Case(text: "appeler Léa demain à 14h", title: "appeler Léa", due: F.date(2026, 11, 7, 14), hasTime: true),
        Case(text: "Appeler Léa demain matin", title: "Appeler Léa", due: F.date(2026, 11, 7, 9), hasTime: true),
        Case(text: "Rendre le rapport vendredi", title: "Rendre le rapport", due: F.date(2026, 11, 13)),
        Case(text: "Préparer la présentation pour vendredi", title: "Préparer la présentation", due: F.date(2026, 11, 13)),
        Case(text: "réunion lundi 9h30", title: "réunion", due: F.date(2026, 11, 9, 9, 30), hasTime: true),
        Case(text: "réunion 14:30", title: "réunion", due: F.date(2026, 11, 6, 14, 30), hasTime: true),
        Case(text: "appeler maman ce soir", title: "appeler maman", due: F.date(2026, 11, 6, 19), hasTime: true),
        Case(text: "rendez-vous après-demain à midi", title: "rendez-vous", due: F.date(2026, 11, 8, 12), hasTime: true),
        // 9:00 is gone: tomorrow.
        Case(text: "point d'équipe à 9h", title: "point d'équipe", due: F.date(2026, 11, 7, 9), hasTime: true),
        Case(text: "sortir le chien dans 10 min", title: "sortir le chien", due: F.now + 10 * 60, hasTime: true),
        Case(text: "réviser dans 3 jours", title: "réviser", due: F.date(2026, 11, 9)),
        Case(text: "payer le loyer le 12/11", title: "payer le loyer", due: F.date(2026, 11, 12)),
        // January 3rd is gone this year: next year's.
        Case(text: "dentiste le 3/1", title: "dentiste", due: F.date(2027, 1, 3)),
        Case(text: "anniversaire de Tom 3 décembre", title: "anniversaire de Tom", due: F.date(2026, 12, 3)),
        Case(text: "Call Mom tomorrow at 2pm", title: "Call Mom", due: F.date(2026, 11, 7, 14), hasTime: true),
        Case(text: "Send invoice next monday", title: "Send invoice", due: F.date(2026, 11, 9)),
        Case(text: "Submit report on December 12th", title: "Submit report", due: F.date(2026, 12, 12)),
        Case(text: "Water the plants in 2 hours", title: "Water the plants", due: F.now + 2 * 3600, hasTime: true),
    ])
    func readsTheDate(_ example: Case) {
        let draft = parse(example.text)
        #expect(draft.title == example.title)
        #expect(draft.due == example.due)
        #expect(draft.hasTime == example.hasTime)
    }

    @Test(arguments: ["acheter du pain", "appeler mon frère", "sport 1h", "31/02", "lire  le   livre"])
    func leavesWordsWithoutADateAlone(_ text: String) {
        let draft = parse(text)
        #expect(draft.due == nil)
        #expect(draft.title == text.split(whereSeparator: \.isWhitespace).joined(separator: " "))
    }

    @Test func aDateAloneStaysTheTitle() {
        let draft = parse("demain")
        #expect(draft.title == "demain")
        #expect(draft.due == F.date(2026, 11, 7))
    }

    @Test func readsMonthFirstWhereThatsTheCustom() {
        #expect(parse("12/11", dayFirst: false).due == F.date(2026, 12, 11))
        #expect(parse("12/11", dayFirst: true).due == F.date(2026, 11, 12))
    }

}

struct ReminderBoardTests {
    private typealias F = RemindersFixture

    private func draft(_ title: String, due: Date? = nil, hasTime: Bool = false) -> ReminderDraft {
        ReminderDraft(title: title, due: due, hasTime: hasTime)
    }

    @Test func ignoresAnEmptyTitle() {
        var board = ReminderBoard()
        let added = board.add(draft("   "), at: F.now)
        #expect(added == nil)
        #expect(board.items.isEmpty)
    }

    @Test func showsTheSoonestFirstThenUndated() throws {
        var board = ReminderBoard()
        let firstAdded = board.add(draft("sans date 1"), at: F.now)
        let first = try #require(firstAdded)
        let laterAdded = board.add(draft("lundi", due: F.date(2026, 11, 9)), at: F.now)
        let later = try #require(laterAdded)
        let secondAdded = board.add(draft("sans date 2"), at: F.now)
        let second = try #require(secondAdded)
        let soonAdded = board.add(draft("à 14h", due: F.date(2026, 11, 6, 14), hasTime: true), at: F.now)
        let soon = try #require(soonAdded)
        #expect(board.sorted.map(\.id) == [soon.id, later.id, first.id, second.id])

        board.remove(soon.id)
        #expect(board.sorted.map(\.id) == [later.id, first.id, second.id])
    }

    @Test func dropsWhatEarlierVersionsKeptAsDone() {
        let done = Reminder(title: "fait", createdAt: F.now, completedAt: F.now)
        let open = Reminder(title: "à faire", createdAt: F.now)
        #expect(ReminderBoard(items: [done, open]).items == [open])
    }

    @Test func ringsRecentRemindersAndOnlyMarksMissedOnes() throws {
        var board = ReminderBoard()
        let missedAdded = board.add(draft("oublié", due: F.now + 60, hasTime: true), at: F.now)
        let missed = try #require(missedAdded)
        let freshAdded = board.add(draft("à l'heure", due: F.now + 3 * 3600, hasTime: true), at: F.now)
        let fresh = try #require(freshAdded)
        let dayOnlyAdded = board.add(draft("un jour", due: F.date(2026, 11, 7)), at: F.now)
        let dayOnly = try #require(dayOnlyAdded)
        #expect(board.nextRinging == missed.due)

        // Three hours later, PNotch comes back: the one from three hours ago is only marked.
        let due = board.takeDue(at: F.now + 3 * 3600 + 30)
        #expect(due.map(\.id) == [fresh.id])
        #expect(board.items.allSatisfy { $0.id == dayOnly.id || $0.reminded })
        #expect(board.nextRinging == nil)
        let later = board.takeDue(at: F.now + 4 * 3600)
        #expect(later.isEmpty)
    }

    @Test func aTimeAlreadyGoneRingsNothing() throws {
        var board = ReminderBoard()
        let itemAdded = board.add(draft("trop tard", due: F.now - 60, hasTime: true), at: F.now)
        let item = try #require(itemAdded)
        #expect(item.reminded)
        #expect(item.isOverdue(at: F.now, calendar: F.calendar))
        #expect(board.nextRinging == nil)
    }

    @Test func snoozesForTenMinutes() throws {
        var board = ReminderBoard()
        let added = board.add(draft("appeler", due: F.now, hasTime: true), at: F.now - 60)
        let item = try #require(added)
        _ = board.takeDue(at: F.now)
        board.snooze(item.id, at: F.now + 30)

        // Its time stays; it rings again ten minutes later.
        let snoozed = try #require(board.items.first)
        #expect(snoozed.due == F.now)
        #expect(board.nextRinging == F.now + 30 + ReminderTiming.snooze)
        let rung = board.takeDue(at: F.now + 30 + ReminderTiming.snooze)
        #expect(rung.map(\.id) == [item.id])
        #expect(board.nextRinging == nil)
    }

    @Test func aDayIsOverdueOnlyOnceItsOver() {
        let reminder = Reminder(title: "jour", due: F.date(2026, 11, 6), createdAt: F.now)
        #expect(!reminder.isOverdue(at: F.now, calendar: F.calendar))
        #expect(reminder.isOverdue(at: F.date(2026, 11, 7, 0, 1), calendar: F.calendar))
    }
}

struct ReminderDueFormatterTests {
    private typealias F = RemindersFixture

    @Test func namesTheDay() {
        let day = { (due: Date) in ReminderDueFormatter.day(of: due, at: F.now, calendar: F.calendar) }
        #expect(day(F.date(2026, 11, 6, 23)) == .today)
        #expect(day(F.date(2026, 11, 7, 9)) == .tomorrow)
        #expect(day(F.date(2026, 11, 5)) == .yesterday)
        #expect(day(F.date(2026, 11, 12)) == .thisWeek)
        #expect(day(F.date(2026, 11, 13)) == .other)
    }

    @Test func showsDigitsForTheLEDDisplay() {
        #expect(ReminderDueFormatter.digits(due: F.date(2026, 11, 6, 9, 5), hasTime: true, calendar: F.calendar) == "09:05")
        #expect(ReminderDueFormatter.digits(due: F.date(2026, 11, 13), hasTime: false, calendar: F.calendar, dayFirst: true) == "13/11")
        #expect(ReminderDueFormatter.digits(due: F.date(2026, 11, 13), hasTime: false, calendar: F.calendar, dayFirst: false) == "11/13")
        #expect(DotMatrixFont.layout("13/11").columns == 5 * 5 + 4)
    }

    @Test func countsDownWithinTheDay() {
        let countdown = { (due: Date, hasTime: Bool) in ReminderDueFormatter.countdown(to: due, hasTime: hasTime, at: F.now) }
        #expect(countdown(F.now + 25 * 60, true) != nil)
        #expect(countdown(F.now + 25 * 60, true) == countdown(F.now + 24 * 60 + 30, true))
        #expect(countdown(F.now + 2 * 3600, true) != countdown(F.now + 2 * 3600 + 15 * 60, true))
        // Seconds away still reads « dans 1 min »; at the time and just after, « C’est l’heure ».
        #expect(countdown(F.now + 20, true) == countdown(F.now + 60, true))
        #expect(countdown(F.now - 20, true) == countdown(F.now, true))
        #expect(countdown(F.now - 10 * 60, true) != nil)
        // Further away, or without a time: the day says it.
        #expect(countdown(F.now + 30 * 3600, true) == nil)
        #expect(countdown(F.now - 2 * 3600, true) == nil)
        #expect(countdown(F.now + 60, false) == nil)
    }
}

@MainActor
struct RemindersManagerTests {
    private typealias F = RemindersFixture

    private final class Clock {
        var date = F.now
    }

    private final class Saved {
        var items: [Reminder] = []
    }

    private func makeManager(clock: Clock, saved: Saved) -> RemindersManager {
        RemindersManager(now: { clock.date }, calendar: F.calendar, items: [], saveItems: { saved.items = $0 }, layout: { .spotlight })
    }

    @Test func ringsWhenAReminderIsDue() throws {
        let clock = Clock()
        let saved = Saved()
        let manager = makeManager(clock: clock, saved: saved)
        defer { manager.stop() }
        var rung: [Reminder] = []
        manager.onRing = { rung += $0 }

        let added = manager.add("sortir le chien dans 10 min")
        let item = try #require(added)
        #expect(saved.items.map(\.id) == [item.id])
        #expect(manager.lastAdded == item.id)

        manager.checkRinging()
        #expect(rung.isEmpty)

        clock.date = F.now + 11 * 60
        manager.checkRinging()
        #expect(rung.map(\.id) == [item.id])
        #expect(manager.isRinging)
        #expect(saved.items.first?.reminded == true)

        manager.snooze(item.id)
        #expect(!manager.isRinging)
        #expect(manager.board.nextRinging == clock.date + ReminderTiming.snooze)
    }

    @Test func theListIsAsTallAsItsRows() throws {
        let manager = RemindersManager(now: { F.now }, calendar: F.calendar, items: [], saveItems: { _ in }, layout: { .list })
        defer { manager.stop() }
        #expect(manager.panel == .browse)

        _ = try #require(manager.add("appeler Léa demain à 9h"))
        #expect(manager.panel == .list(rows: 1))
        for text in ["acheter du pain", "arroser les plantes", "rendre le dossier"] {
            _ = manager.add(text)
        }
        // Three rows, then it scrolls.
        #expect(manager.panel == .list(rows: 3))
        #expect(RemindersMetrics.bodyHeight(.list(rows: 1)) < RemindersMetrics.bodyHeight(.list(rows: 3)))
        #expect(RemindersMetrics.bodyHeight(.list(rows: 3)) <= RemindersMetrics.bodyHeight(.browse))
    }

    @Test func aTickedReminderLeavesUnlessTickedAgain() async throws {
        let manager = makeManager(clock: Clock(), saved: Saved())
        defer { manager.stop() }
        let kept = try #require(manager.add("garder"))
        let done = try #require(manager.add("finir"))

        manager.toggleDone(kept.id)
        manager.toggleDone(done.id)
        manager.toggleDone(kept.id)
        #expect(manager.finishing == [done.id])

        // Other tests share the main actor: wait for it to leave rather than for a fixed time.
        let deadline = ContinuousClock.now + .seconds(5)
        while !manager.finishing.isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(manager.reminders.map(\.id) == [kept.id])
        #expect(manager.finishing.isEmpty)
    }
}

struct NotesTests {
    @Test func readsTitleAndPreview() {
        let note = Note(text: "\n  Idées cadeau \n- livre pour Tom\n\n- resto", createdAt: .now, modifiedAt: .now)
        #expect(note.title == "Idées cadeau")
        #expect(note.bodyLines == ["• livre pour Tom", "• resto"])
        #expect(note.preview == "livre pour Tom")
        #expect(Note(text: " \n ", createdAt: .now, modifiedAt: .now).isBlank)
    }

    @MainActor
    @Test func keepsNotesLastEditedFirstAndDropsBlankOnes() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "notes-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        var date = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let manager = NotesManager(now: { date }, store: NotesStore(fileURL: file))

        manager.setSheetText("courses")
        let groceries = try #require(manager.notes.first)
        date += 60
        let ideas = manager.create()
        manager.update(ideas.id, text: "idées")
        #expect(manager.notes.map(\.id) == [ideas.id, groceries.id])

        date += 60
        manager.update(groceries.id, text: "courses\nlait")
        #expect(manager.notes.map(\.id) == [groceries.id, ideas.id])
        #expect(manager.sheetText == "courses\nlait")

        // A new note left blank goes once another is opened.
        let blank = manager.create()
        #expect(manager.selectedID == blank.id)
        manager.select(ideas.id)
        #expect(manager.notes.count == 2)

        manager.flush()
        let reloaded = NotesManager(store: NotesStore(fileURL: file))
        #expect(reloaded.notes.map(\.text) == ["courses\nlait", "idées"])

        manager.delete(ideas.id)
        #expect(manager.selectedID == nil)
        #expect(manager.notes.map(\.id) == [groceries.id])
    }
}

struct ReminderRepeatTests {
    private typealias F = RemindersFixture

    @Test func findsTheNextOccurrence() {
        let friday = F.date(2026, 11, 6, 9)
        #expect(ReminderFrequency.daily.next(after: friday, calendar: F.calendar) == F.date(2026, 11, 7, 9))
        #expect(ReminderFrequency.weekdays.next(after: friday, calendar: F.calendar) == F.date(2026, 11, 9, 9))
        #expect(ReminderFrequency.weekly.next(after: friday, calendar: F.calendar) == F.date(2026, 11, 13, 9))
        #expect(ReminderFrequency.monthly.next(after: F.date(2026, 1, 31), calendar: F.calendar) == F.date(2026, 2, 28))
        #expect(ReminderFrequency.yearly.next(after: friday, calendar: F.calendar) == F.date(2027, 11, 6, 9))
    }

    @Test func comesBackWhenDoneUntilItsEnd() throws {
        var board = ReminderBoard()
        let rule = ReminderRepeat(frequency: .daily, end: .after(2))
        let added = board.add(ReminderDraft(title: "pilule", due: F.now + 3600, hasTime: true, repeatRule: rule), at: F.now)
        let item = try #require(added)

        board.complete(item.id, at: F.now, calendar: F.calendar)
        let next = try #require(board.items.first)
        #expect(next.due == F.now + 3600 + 86400)
        #expect(next.repeatRule?.end == .after(1))
        #expect(next.awaitsRinging)

        // The last time: it leaves.
        board.complete(item.id, at: F.now, calendar: F.calendar)
        #expect(board.items.isEmpty)
    }

    @Test func skipsOccurrencesGoneWhileItWaited() throws {
        var board = ReminderBoard()
        let added = board.add(ReminderDraft(title: "arroser", due: F.date(2026, 11, 1), repeatRule: ReminderRepeat(frequency: .daily)), at: F.date(2026, 11, 1))
        let item = try #require(added)
        board.complete(item.id, at: F.now, calendar: F.calendar)
        // Ticked on the 6th: next is today's, not the 2nd.
        #expect(board.items.first?.due == F.date(2026, 11, 6))
    }

    @Test func stopsAfterItsLastDay() throws {
        var board = ReminderBoard()
        let rule = ReminderRepeat(frequency: .weekly, end: .on(F.date(2026, 11, 12)))
        let added = board.add(ReminderDraft(title: "cours", due: F.date(2026, 11, 6), repeatRule: rule), at: F.now)
        let item = try #require(added)
        board.complete(item.id, at: F.now, calendar: F.calendar)
        #expect(board.items.isEmpty)
    }

    @Test func ringsEarlyThenOnTime() throws {
        var board = ReminderBoard()
        let added = board.add(ReminderDraft(title: "réunion", due: F.now + 3600, hasTime: true, earlyAlert: 15 * 60), at: F.now)
        let item = try #require(added)
        #expect(board.nextRinging == F.now + 45 * 60)

        let early = board.takeDue(at: F.now + 45 * 60)
        #expect(early.map(\.id) == [item.id])
        #expect(board.nextRinging == F.now + 3600)

        let onTime = board.takeDue(at: F.now + 3600)
        #expect(onTime.map(\.id) == [item.id])
        #expect(board.nextRinging == nil)
    }

    @Test func readsRemindersSavedBeforeTheOptions() throws {
        let json = #"{"createdAt":815686309.759869,"due":815749200,"hasTime":true,"id":"A13FF3B4-EA60-4F28-B88E-70420322E7C3","reminded":false,"title":"appeler john"}"#
        let reminder = try JSONDecoder().decode(Reminder.self, from: Data(json.utf8))
        #expect(reminder.title == "appeler john")
        #expect(reminder.hasTime)
        #expect(reminder.note.isEmpty)
        #expect(reminder.repeatRule == nil)
        #expect(reminder.earlyAlert == nil)

        var repeating = reminder
        repeating.repeatRule = ReminderRepeat(frequency: .monthly, end: .on(F.now))
        let roundTrip = try JSONDecoder().decode(Reminder.self, from: JSONEncoder().encode(repeating))
        #expect(roundTrip == repeating)
    }

    @Test func readsHowOftenFromTheWords() {
        let parse = { (text: String) in ReminderDraftParser.parse(text, now: F.now, calendar: F.calendar) }

        let bins = parse("sortir les poubelles tous les lundis à 19h")
        #expect(bins.title == "sortir les poubelles")
        #expect(bins.repeatRule?.frequency == .weekly)
        #expect(bins.due == F.date(2026, 11, 9, 19))

        let pill = parse("prendre la pilule tous les jours à 8h")
        #expect(pill.title == "prendre la pilule")
        #expect(pill.repeatRule?.frequency == .daily)
        // 8:00 is gone today: tomorrow's.
        #expect(pill.due == F.date(2026, 11, 7, 8))

        let rent = parse("payer le loyer chaque mois")
        #expect(rent.repeatRule?.frequency == .monthly)
        #expect(rent.due == F.date(2026, 11, 6))
        #expect(parse("Stand-up every weekday at 9:30").repeatRule?.frequency == .weekdays)
    }
}

struct ReminderEditingTests {
    private typealias F = RemindersFixture

    @Test func minutesGoByFive() {
        #expect(ReminderTiming.minute(after: 37) == 40)
        #expect(ReminderTiming.minute(after: 55) == 0)
        #expect(ReminderTiming.minute(after: 0) == 5)
        #expect(ReminderTiming.minute(before: 37) == 35)
        #expect(ReminderTiming.minute(before: 35) == 30)
        #expect(ReminderTiming.minute(before: 0) == 55)
    }

    @Test func changesWhatAndWhen() throws {
        var board = ReminderBoard()
        let added = board.add(ReminderDraft(title: "appeler", due: F.now + 60, hasTime: true), at: F.now)
        let item = try #require(added)
        _ = board.takeDue(at: F.now + 120)
        #expect(board.nextRinging == nil)

        // Moved to later: it rings again.
        board.update(item.id, with: ReminderDraft(title: "appeler Léa", due: F.now + 3600, hasTime: true), at: F.now + 120)
        #expect(board.items.first?.title == "appeler Léa")
        #expect(board.nextRinging == F.now + 3600)

        // A day without a time: nothing to ring.
        board.update(item.id, with: ReminderDraft(title: "appeler Léa", due: F.date(2026, 11, 9), hasTime: false), at: F.now + 120)
        #expect(board.items.first?.hasTime == false)
        #expect(board.nextRinging == nil)

        // An empty title changes nothing.
        board.update(item.id, with: ReminderDraft(title: "  ", due: nil), at: F.now + 120)
        #expect(board.items.first?.title == "appeler Léa")
    }
}

struct ReminderEditorStateTests {
    private typealias F = RemindersFixture

    @Test func startsWithoutADate() {
        let editor = ReminderEditorState(newAt: F.now, calendar: F.calendar)
        #expect(!editor.hasDate)
        #expect(editor.due(calendar: F.calendar) == nil)
        // Given a date, today; given a time, the next full hour.
        #expect(editor.day == F.date(2026, 11, 6))
        #expect(editor.hour == 11)
        #expect(editor.minute == 0)
    }

    @Test func theWordsSetTheDateOnceAndLeaveTheTitle() {
        var editor = ReminderEditorState(newAt: F.now, calendar: F.calendar)
        editor.text = "appeler Léa demain à 14h"
        let parse = { ReminderDraftParser.parse(editor.text, now: F.now, calendar: F.calendar) }
        editor.read(parse(), calendar: F.calendar)
        #expect(editor.hasDate)
        #expect(editor.due(calendar: F.calendar) == F.date(2026, 11, 7, 14))

        // A day picked by hand stays while the text goes on.
        editor.day = F.date(2026, 11, 10)
        editor.text += " pour le dîner"
        editor.read(parse(), calendar: F.calendar)
        #expect(editor.day == F.date(2026, 11, 10))

        editor.note = "  son nouveau numéro  "
        editor.earlyAlert = 15 * 60
        editor.frequency = .weekly
        let draft = editor.draft(from: parse(), calendar: F.calendar)
        #expect(draft.title == "appeler Léa pour le dîner")
        #expect(draft.due == F.date(2026, 11, 10, 14))
        #expect(draft.repeatRule == ReminderRepeat(frequency: .weekly))
        #expect(draft.earlyAlert == TimeInterval(15 * 60))

        // Without a date, no repeat and no early alert.
        editor.hasDate = false
        let undated = editor.draft(from: parse(), calendar: F.calendar)
        #expect(undated.due == nil)
        #expect(undated.repeatRule == nil)
        #expect(undated.earlyAlert == nil)
    }

    @MainActor
    @Test func savesAndUnfolds() throws {
        let manager = RemindersManager(now: { RemindersFixture.now }, calendar: F.calendar, items: [], saveItems: { _ in })
        defer { manager.stop() }
        #expect(manager.panel == .browse)
        manager.openEditor(.new)
        #expect(manager.panel == .compose)
        manager.editor?.showsSettings = true
        #expect(manager.panel == .settings)

        // Nothing written: nothing saved.
        #expect(!manager.saveEditor())
        manager.editor?.text = "acheter du pain"
        #expect(manager.saveEditor())
        #expect(manager.editor == nil)
        let saved = try #require(manager.reminders.first)
        #expect(saved.title == "acheter du pain")
        #expect(saved.due == nil)

        manager.openEditor(.edit(saved.id))
        #expect(manager.editor?.text == "acheter du pain")
        manager.deleteEditorReminder()
        #expect(manager.reminders.isEmpty)
    }
}

struct TimeEntryTests {
    @Test func readsDigitsAsAClockFieldDoes() {
        #expect(TimeEntry.read("1", for: .hour) == ("1", 1, false))
        #expect(TimeEntry.read("14", for: .hour) == ("14", 14, true))
        // No hour starts with 3 to 9: one digit is enough.
        #expect(TimeEntry.read("9", for: .hour) == ("9", 9, true))
        #expect(TimeEntry.read("29", for: .hour) == ("29", 23, true))
        #expect(TimeEntry.read("5", for: .minute) == ("5", 5, false))
        #expect(TimeEntry.read("7", for: .minute) == ("7", 7, true))
        #expect(TimeEntry.read("1430", for: .minute) == ("30", 30, true))
        #expect(TimeEntry.read("ab", for: .hour) == ("", nil, false))
    }

    @Test func typesHoursThenMinutesInOneGo() {
        #expect(TimeEntry.type("", from: .hour) == TimeEntry.Typing(next: .hour))
        #expect(TimeEntry.type("1", from: .hour) == TimeEntry.Typing(digits: "1", hour: 1, next: .hour))
        #expect(TimeEntry.type("14", from: .hour) == TimeEntry.Typing(digits: "14", hour: 14, next: .minute))
        #expect(TimeEntry.type("143", from: .hour) == TimeEntry.Typing(digits: "143", hour: 14, minute: 3, next: .minute))
        #expect(TimeEntry.type("1430", from: .hour) == TimeEntry.Typing(digits: "1430", hour: 14, minute: 30, next: .minute, isComplete: true))
        // 9 is a whole hour: the next digit is the minutes'.
        #expect(TimeEntry.type("94", from: .hour) == TimeEntry.Typing(digits: "94", hour: 9, minute: 4, next: .minute))
        #expect(TimeEntry.type("143059", from: .hour) == TimeEntry.Typing(digits: "1430", hour: 14, minute: 30, next: .minute, isComplete: true))
        #expect(TimeEntry.type("45", from: .minute) == TimeEntry.Typing(digits: "45", minute: 45, next: .minute, isComplete: true))
        #expect(TimeEntry.type("7", from: .minute) == TimeEntry.Typing(digits: "7", minute: 7, next: .minute, isComplete: true))
    }
}
