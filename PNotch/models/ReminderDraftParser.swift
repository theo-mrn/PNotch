import Foundation

/// A reminder as typed, its date read from the words: « appeler Léa demain à 14h » is « appeler Léa »,
/// tomorrow at 2 pm.
nonisolated struct ReminderDraft: Equatable, Sendable {
    var title: String
    var due: Date?
    /// Whether a time of day was given, which rings a reminder.
    var hasTime = false
    /// « tous les jours », « chaque lundi »…
    var repeatRule: ReminderRepeat?
    /// Set in the editor.
    var note = ""
    var earlyAlert: TimeInterval?
}

/// Reads when a reminder is due from the way it's written, in French or in English:
/// « demain », « vendredi », « le 12/11 », « 3 décembre », « à 14h », « 9h30 », « ce soir », « dans 10 min »,
/// « tomorrow at 2pm », « next friday », « in 2 hours »…, and how often it comes back: « tous les jours »,
/// « chaque lundi », « en semaine », « every month »… The words that gave the date leave the title.
nonisolated enum ReminderDraftParser {
    static func parse(_ text: String, now: Date, calendar: Calendar = .current, dayFirst: Bool = ReminderDraftParser.dayFirst) -> ReminderDraft {
        var words = Words(text: text)
        var day: Date?
        var due: Date?
        var hasTime = false
        let today = calendar.startOfDay(for: now)

        // « tous les jours », « chaque lundi »
        let repeating = takeRepeat(&words)
        if let weekday = repeating?.weekday {
            // The first one is today if it's that day.
            day = calendar.nextDate(after: today.addingTimeInterval(-1), matching: DateComponents(weekday: weekday), matchingPolicy: .nextTime)
        }

        // « dans 10 min », « in 3 days »
        if let groups = words.take(Pattern.relative), let amount = groups[1].flatMap({ Int($0) }), let unit = groups[2]?.lowercased().first {
            switch unit {
            case "m":
                due = now.addingTimeInterval(TimeInterval(amount * 60))
                hasTime = true
            case "h":
                due = now.addingTimeInterval(TimeInterval(amount * 3600))
                hasTime = true
            case "j", "d":
                day = calendar.date(byAdding: .day, value: amount, to: today)
            default:
                day = calendar.date(byAdding: .day, value: amount * 7, to: today)
            }
        }

        if due == nil {
            day = day ?? takeDay(&words, today: today, now: now, calendar: calendar, dayFirst: dayFirst)
            let time = takeTime(&words)
            switch (day, time) {
            case let (day?, time?):
                due = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day)
                hasTime = due != nil
            case let (day?, nil):
                due = day
            case let (nil, time?):
                // Today, or tomorrow once that time is gone.
                if let todayAtTime = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: now) {
                    due = todayAtTime > now ? todayAtTime : calendar.date(byAdding: .day, value: 1, to: todayAtTime)
                    hasTime = due != nil
                }
            case (nil, nil):
                break
            }
        }

        var repeatRule: ReminderRepeat?
        if let frequency = repeating?.frequency {
            repeatRule = ReminderRepeat(frequency: frequency)
            // Repeating from today, unless a day was given; a time already gone today starts next time.
            if due == nil {
                due = today
            }
            if let first = due, hasTime, first <= now {
                due = frequency.next(after: first, calendar: calendar)
            }
        }

        let original = collapsed(text)
        guard words.tookSomething else {
            return ReminderDraft(title: original)
        }
        let title = cleaned(words.text)
        // Nothing but a date: keep the words as they were.
        return ReminderDraft(title: title.isEmpty ? original : title, due: due, hasTime: hasTime, repeatRule: repeatRule)
    }

    // MARK: Repeat

    private static func takeRepeat(_ words: inout Words) -> (frequency: ReminderFrequency, weekday: Int?)? {
        if let groups = words.take(Pattern.everyWeekday), let weekday = groups[1].flatMap(weekdayNumber) {
            return (.weekly, weekday)
        }
        let frequencies: [(NSRegularExpression, ReminderFrequency)] = [
            (Pattern.daily, .daily), (Pattern.weekdays, .weekdays), (Pattern.weekly, .weekly),
            (Pattern.monthly, .monthly), (Pattern.yearly, .yearly),
        ]
        for (pattern, frequency) in frequencies where words.take(pattern) != nil {
            return (frequency, nil)
        }
        return nil
    }

    /// Whether « 12/11 » is the 12th of November, as in French, or December 11th, as in American English.
    static var dayFirst: Bool {
        let format = DateFormatter.dateFormat(fromTemplate: "dM", options: 0, locale: .current) ?? "d/M"
        guard let day = format.firstIndex(of: "d"), let month = format.firstIndex(of: "M") else { return true }
        return day < month
    }

    // MARK: Day

    private static func takeDay(_ words: inout Words, today: Date, now: Date, calendar: Calendar, dayFirst: Bool) -> Date? {
        if words.take(Pattern.afterTomorrow) != nil {
            return calendar.date(byAdding: .day, value: 2, to: today)
        }
        if words.take(Pattern.tomorrow) != nil {
            return calendar.date(byAdding: .day, value: 1, to: today)
        }
        if words.take(Pattern.today) != nil {
            return today
        }
        if let groups = words.take(Pattern.weekday), let weekday = groups[1].flatMap(weekdayNumber) {
            // The next one: « vendredi » said on a Friday is next week's.
            return calendar.nextDate(after: now, matching: DateComponents(weekday: weekday), matchingPolicy: .nextTime)
        }

        var date: Date?
        _ = words.take(Pattern.numericDate) { groups in
            guard let first = groups[1].flatMap({ Int($0) }), let second = groups[2].flatMap({ Int($0) }) else { return false }
            let year = groups[3].flatMap { Int($0) }
            date = makeDate(day: dayFirst ? first : second, month: dayFirst ? second : first, year: year, today: today, calendar: calendar)
            return date != nil
        }
        if let date {
            return date
        }
        _ = words.take(Pattern.dayMonth) { groups in
            guard let day = groups[1].flatMap({ Int($0) }), let month = groups[2].flatMap(monthNumber) else { return false }
            date = makeDate(day: day, month: month, year: groups[3].flatMap { Int($0) }, today: today, calendar: calendar)
            return date != nil
        }
        if let date {
            return date
        }
        _ = words.take(Pattern.monthDay) { groups in
            guard let month = groups[1].flatMap(monthNumber), let day = groups[2].flatMap({ Int($0) }) else { return false }
            date = makeDate(day: day, month: month, year: nil, today: today, calendar: calendar)
            return date != nil
        }
        return date
    }

    /// The date, this year or the next one once it's gone; `nil` if there's no such day.
    private static func makeDate(day: Int, month: Int, year: Int?, today: Date, calendar: Calendar) -> Date? {
        guard (1 ... 31).contains(day), (1 ... 12).contains(month) else { return nil }
        let currentYear = calendar.component(.year, from: today)
        let explicitYear = year.map { $0 < 100 ? 2000 + $0 : $0 }
        guard let date = calendar.date(from: DateComponents(year: explicitYear ?? currentYear, month: month, day: day)),
              calendar.component(.day, from: date) == day else { return nil }
        if explicitYear == nil, date < today {
            return calendar.date(byAdding: .year, value: 1, to: date)
        }
        return date
    }

    // MARK: Time

    private static func takeTime(_ words: inout Words) -> (hour: Int, minute: Int)? {
        var time: (hour: Int, minute: Int)?

        // « 2pm », « at 9:30 am »
        _ = words.take(Pattern.meridiemTime) { groups in
            guard let hour = groups[1].flatMap({ Int($0) }), (1 ... 12).contains(hour) else { return false }
            let minute = groups[2].flatMap { Int($0) } ?? 0
            guard (0 ... 59).contains(minute) else { return false }
            let isAfternoon = groups[3]?.lowercased() == "pm"
            time = (hour % 12 + (isAfternoon ? 12 : 0), minute)
            return true
        }
        // « 14:30 »
        if time == nil {
            _ = words.take(Pattern.colonTime) { groups in
                guard let hour = groups[1].flatMap({ Int($0) }), let minute = groups[2].flatMap({ Int($0) }),
                      (0 ... 23).contains(hour), (0 ... 59).contains(minute) else { return false }
                time = (hour, minute)
                return true
            }
        }
        // « à 14h », « 9h30 ». Without « à », a small number of hours is a duration: « sport 1h ».
        if time == nil {
            _ = words.take(Pattern.hourTime) { groups in
                guard let hour = groups[2].flatMap({ Int($0) }), (0 ... 23).contains(hour) else { return false }
                let minute = groups[3].flatMap { Int($0) } ?? 0
                guard (0 ... 59).contains(minute), groups[1] != nil || hour >= 6 else { return false }
                time = (hour, minute)
                return true
            }
        }
        // « ce soir », « demain matin », « à midi », « tonight »
        if time == nil, let groups = words.take(Pattern.partOfDay), let word = groups[1]?.lowercased() {
            time = partOfDayTime(word)
        }
        return time
    }

    private static func partOfDayTime(_ word: String) -> (hour: Int, minute: Int) {
        let word = word.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        if word.hasPrefix("midi") || word == "noon" {
            return (12, 0)
        }
        if word.hasPrefix("matin") || word == "morning" {
            return (9, 0)
        }
        if word.hasPrefix("apres") || word == "aprem" || word == "afternoon" {
            return (14, 0)
        }
        return (19, 0)
    }

    // MARK: Words

    private static func weekdayNumber(_ name: String) -> Int? {
        let names = [
            ["dimanche", "sunday"], ["lundi", "monday"], ["mardi", "tuesday"], ["mercredi", "wednesday"],
            ["jeudi", "thursday"], ["vendredi", "friday"], ["samedi", "saturday"],
        ]
        let name = name.lowercased()
        return names.firstIndex { $0.contains(name) }.map { $0 + 1 }
    }

    private static func monthNumber(_ name: String) -> Int? {
        let name = name.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .replacingOccurrences(of: ".", with: "")
        let prefixes: [(String, Int)] = [
            ("jan", 1), ("fe", 2), ("mar", 3), ("av", 4), ("ap", 4), ("mai", 5), ("may", 5),
            ("juin", 6), ("jun", 6), ("juil", 7), ("jul", 7), ("ao", 8), ("aug", 8),
            ("sep", 9), ("oct", 10), ("nov", 11), ("de", 12),
        ]
        return prefixes.first { name.hasPrefix($0.0) }?.1
    }

    /// Words a date leaves hanging at the end: « rendre le rapport pour » (vendredi).
    private static let danglingWords: Set<String> = [
        "à", "a", "at", "le", "la", "on", "pour", "for", "by", "avant", "before", "vers", "around",
        "de", "du", "the", "ce", "cet", "this", "et", "and", "@",
    ]

    private static func cleaned(_ text: String) -> String {
        let punctuation = CharacterSet(charactersIn: ",;:–—-").union(.whitespaces)
        var tokens = collapsed(text).split(separator: " ").map(String.init)
        while let last = tokens.last, danglingWords.contains(last.lowercased()) || last.trimmingCharacters(in: punctuation).isEmpty {
            tokens.removeLast()
        }
        return tokens.joined(separator: " ").trimmingCharacters(in: punctuation)
    }

    private static func collapsed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

// MARK: - Matching

/// The text being read: each date or time found is taken out of it.
nonisolated private struct Words {
    var text: String
    private(set) var tookSomething = false

    /// Takes out the first match of `regex` that `accept` agrees with, and returns its groups: 0 is the whole match.
    mutating func take(_ regex: NSRegularExpression, where accept: ([String?]) -> Bool = { _ in true }) -> [String?]? {
        let string = text as NSString
        for match in regex.matches(in: text, range: NSRange(location: 0, length: string.length)) {
            let groups = (0 ..< match.numberOfRanges).map { index -> String? in
                let range = match.range(at: index)
                return range.location == NSNotFound ? nil : string.substring(with: range)
            }
            guard accept(groups) else { continue }
            text = string.replacingCharacters(in: match.range, with: " ")
            tookSomething = true
            return groups
        }
        return nil
    }
}

nonisolated private enum Pattern {
    /// Not followed by a letter or a digit: the end of a word, accents included.
    private static let end = #"(?![\p{L}\p{N}])"#

    private static let months = [
        #"janvier|january|janv\.?|jan\.?"#,
        #"f[ée]vrier|february|f[ée]vr?\.?|feb\.?"#,
        #"mars|march|mar\.?"#,
        #"avril|april|avr\.?|apr\.?"#,
        #"mai|may"#,
        #"juin|june|jun\.?"#,
        #"juillet|july|juil\.?|jul\.?"#,
        #"ao[uû]t|august|aug\.?"#,
        #"septembre|september|sept?\.?"#,
        #"octobre|october|oct\.?"#,
        #"novembre|november|nov\.?"#,
        #"d[ée]cembre|december|d[ée]c\.?"#,
    ].joined(separator: "|")

    static let everyWeekday = regex(
        #"\b(?:tous\s+les|chaque|every)\s+(lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche|monday|tuesday|wednesday|thursday|friday|saturday|sunday)s?"# + end
    )
    static let daily = regex(#"\b(?:tous\s+les\s+jours|chaque\s+jour|quotidiennement|every\s*day|daily)"# + end)
    static let weekdays = regex(#"\b(?:en\s+semaine|les\s+jours\s+de\s+semaine|every\s+weekday|on\s+weekdays|weekdays)"# + end)
    static let weekly = regex(#"\b(?:chaque\s+semaine|toutes\s+les\s+semaines|every\s+week|weekly)"# + end)
    static let monthly = regex(#"\b(?:chaque\s+mois|tous\s+les\s+mois|every\s+month|monthly)"# + end)
    static let yearly = regex(#"\b(?:chaque\s+ann[ée]e|tous\s+les\s+ans|every\s+year|yearly|annually)"# + end)

    static let relative = regex(#"\b(?:dans|in)\s+(\d{1,3})\s*(minutes?|mins?|mn|heures?|hours?|hrs?|h|jours?|days?|j|d|semaines?|weeks?|sem|w)"# + end)

    static let afterTomorrow = regex(#"\b(?:apr[eè]s[-\s]?demain|the\s+day\s+after\s+tomorrow)"# + end)
    static let tomorrow = regex(#"\b(?:demain|tomorrow)"# + end)
    static let today = regex(#"\b(?:aujourd['’]?hui|today)"# + end)
    static let weekday = regex(
        #"\b(?:(?:ce|le|this|on|next)\s+)?(lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche|monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?:\s+(?:prochain|next))?"# + end
    )
    static let numericDate = regex(#"\b(?:(?:le|on|the)\s+)?(\d{1,2})/(\d{1,2})(?:/(\d{4}|\d{2}))?(?![\d/])"#)
    static let dayMonth = regex(#"\b(?:(?:le|on|the)\s+)?(\d{1,2})(?:er|st|nd|rd|th)?\s+("# + months + #")(?:\s+(\d{4}))?"# + end)
    static let monthDay = regex(#"\b(?:on\s+)?("# + months + #")\s+(\d{1,2})(?:st|nd|rd|th)?"# + end)

    private static let preposition = #"(?:\b(?:à|a|at|vers|around)\s+|@\s*)"#
    static let meridiemTime = regex(preposition + #"?\b(\d{1,2})(?::(\d{2}))?\s?(am|pm)"# + end)
    static let colonTime = regex(preposition + #"?\b(\d{1,2}):(\d{2})(?![\d:])"#)
    /// Group 1 is the preposition, which tells « à 1h » from a duration.
    static let hourTime = regex(#"(?:\b(à|a|at|vers|around)\s+|(?:@)\s*)?\b(\d{1,2})\s?h(?:eures?)?(?:\s?(\d{2}))?"# + end)
    static let partOfDay = regex(
        #"(?:\b(?:à|at|vers|around)\s+)?(?:\b(?:ce|cet|cette|le|this|in\s+the)\s+)?\b(soir[ée]e?|soir|matin[ée]e?|matin|apr[eè]s[-\s]?midi|aprem|midi|evening|morning|afternoon|noon|tonight)"# + end
    )

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // The patterns are constants: a typo is caught by the tests.
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
}
