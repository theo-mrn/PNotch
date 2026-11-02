import SwiftUI

/// Writes a reminder or changes one. The text first, a note under it; the date, time and options behind the
/// settings button, which unfolds the notch. ↩ saves at any time.
struct ReminderComposerView: View {
    @Environment(RemindersManager.self) private var reminders
    @Environment(PNotchViewModel.self) private var vm
    @FocusState private var focus: Field?

    private enum Field {
        case title
        case note
    }

    var body: some View {
        if let current = reminders.editor {
            composer(binding(from: current))
        }
    }

    /// The editor, safe to read after it closed. On save or cancel the page fades out with its fields
    /// still on screen, and a field giving up the keyboard reads and writes its value one last time:
    /// it then gets the editor as it was, and its writes go nowhere. (`Binding($reminders.editor)`
    /// traps there.)
    private func binding(from snapshot: ReminderEditorState) -> Binding<ReminderEditorState> {
        Binding(
            get: { reminders.editor ?? snapshot },
            set: { value in
                guard reminders.editor?.target == value.target else { return }
                reminders.editor = value
            }
        )
    }

    private func composer(_ editor: Binding<ReminderEditorState>) -> some View {
        let state = editor.wrappedValue
        let canSave = !(reminders.editorDraft?.title.isEmpty ?? true)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                TextField(
                    "Reminder",
                    text: editor.text,
                    prompt: Text("What should I remind you of?").foregroundStyle(Palette.inkTertiary)
                )
                .textFieldStyle(.plain)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .focused($focus, equals: .title)
                .onSubmit(save)

                WhenChip(state: state) { toggleSettings(editor) }
                SettingsToggle(isOn: state.showsSettings) { toggleSettings(editor) }
            }
            .frame(height: 32)

            TextField(
                "Note",
                text: editor.note,
                prompt: Text("Add a note").foregroundStyle(Palette.inkFaint),
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(Palette.inkSecondary)
            .lineLimit(1 ... 2)
            .focused($focus, equals: .note)
            .onSubmit(save)
            .padding(.top, 2)

            if state.showsSettings {
                Rectangle()
                    .fill(Palette.surface)
                    .frame(height: 1)
                    .padding(.vertical, 12)
                    .transition(.opacity)
                ReminderSettingsPanel(editor: editor)
                    .frame(height: ReminderSettingsPanel.height, alignment: .top)
                    .transition(.opacity.combined(with: .offset(y: -8)))
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if case .edit = state.target {
                    DeleteButton { withAnimation(Self.animation) { reminders.deleteEditorReminder() } }
                } else {
                    Text("↩ to save")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.inkTertiary)
                }
                Spacer(minLength: 8)
                ReminderPillButton(title: "Cancel") {
                    withAnimation(Self.animation) { reminders.closeEditor() }
                }
                ReminderPillButton(title: "Save", isProminent: true, action: save)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.4)
            }
            .frame(height: 28)
        }
        .padding(.horizontal, RemindersMetrics.horizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .onChange(of: state.text) {
            reminders.readEditorText()
        }
        .onAppear {
            // Opened by a click: the keyboard is welcome.
            vm.requestKeyboardFocus()
            focus = .title
        }
    }

    static let animation = Motion.standard

    private func toggleSettings(_ editor: Binding<ReminderEditorState>) {
        withAnimation(Self.animation) {
            editor.wrappedValue.showsSettings.toggle()
        }
    }

    private func save() {
        withAnimation(Self.animation) {
            _ = reminders.saveEditor()
        }
    }
}

/// When it's due, next to the text: « Ajouter une date », or « Demain 14:00 » and its repeat. A click unfolds the settings.
private struct WhenChip: View {
    let state: ReminderEditorState
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        let due = state.due()

        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: state.frequency == nil ? "calendar" : "repeat")
                    .font(.system(size: 10.5, weight: .semibold))
                if let due {
                    Text(ReminderDueFormatter.shortLabel(due: due, hasTime: state.hasTime, at: .now))
                        .monospacedDigit()
                } else {
                    Text("Add a date")
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(due == nil ? Palette.ink.opacity(isHovered ? 0.8 : 0.5) : Palette.accent)
            .padding(.horizontal, 11)
            .frame(height: 26)
            .background(due == nil ? AnyShapeStyle(Palette.ink.opacity(isHovered ? 0.1 : 0.06)) : AnyShapeStyle(Palette.accent.opacity(isHovered ? 0.22 : 0.15)), in: Capsule())
            .fixedSize()
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .onHover { isHovered = $0 }
        .animation(Motion.hover, value: isHovered)
        .help("Date, time and options")
    }
}

/// The settings button: unfolds the notch on the date, the time and the options.
private struct SettingsToggle: View {
    let isOn: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOn ? Palette.onAccent : Palette.ink.opacity(isHovered ? 1 : 0.75))
                .frame(width: 28, height: 28)
                .background(isOn ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(Palette.ink.opacity(isHovered ? 0.16 : 0.1)), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.pressable)
        .onHover { isHovered = $0 }
        .animation(Motion.hover, value: isHovered)
        .help(isOn ? "Hide the settings" : "Date, time and options")
    }
}

private struct DeleteButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label("Delete", systemImage: "trash")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ReminderStyle.late.opacity(isHovered ? 1 : 0.8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Settings

/// Three columns: the day on the month's calendar, the time on the LED display, and the options.
private struct ReminderSettingsPanel: View {
    @Binding var editor: ReminderEditorState

    static let height: CGFloat = 166

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                PanelSwitch(title: "Date", isOn: $editor.hasDate)
                MiniCalendar(selection: $editor.day) {
                    // Picking a day gives a date.
                    editor.hasDate = true
                }
                .opacity(editor.hasDate ? 1 : 0.35)
            }
            .frame(width: 186)

            VStack(alignment: .leading, spacing: 6) {
                PanelSwitch(title: "Time", isOn: Binding(
                    get: { editor.hasTime },
                    set: { isOn in
                        editor.hasTime = isOn
                        // A time needs a day.
                        if isOn {
                            editor.hasDate = true
                        }
                    }
                ))
                TimeSpinner(hour: $editor.hour, minute: $editor.minute) {
                    editor.hasTime = true
                    editor.hasDate = true
                }
                .opacity(editor.hasTime ? 1 : 0.3)
                .padding(.top, 8)
            }
            .frame(width: 112, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                Text("Options")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(height: 18)

                OptionMenu(title: "Repeat", value: ReminderDueFormatter.repeatName(editor.frequency)) {
                    Button(ReminderDueFormatter.repeatName(nil)) { editor.frequency = nil }
                    Divider()
                    ForEach(ReminderFrequency.allCases, id: \.self) { frequency in
                        Button(ReminderDueFormatter.repeatName(frequency)) {
                            editor.frequency = frequency
                            editor.hasDate = true
                        }
                    }
                }

                if editor.frequency != nil {
                    OptionMenu(title: "End", value: ReminderDueFormatter.endName(editor.repeatEnd)) {
                        Button(ReminderDueFormatter.endName(.never)) { editor.repeatEnd = .never }
                        Divider()
                        ForEach([3, 5, 10, 30], id: \.self) { count in
                            Button(ReminderDueFormatter.endName(.after(count))) { editor.repeatEnd = .after(count) }
                        }
                        Divider()
                        ForEach(Array(Self.endPeriods.enumerated()), id: \.offset) { _, period in
                            let end = Calendar.current.date(byAdding: period, to: editor.day) ?? editor.day
                            Button(ReminderDueFormatter.endName(.on(end))) { editor.repeatEnd = .on(end) }
                        }
                    }
                    .transition(.opacity)
                }

                OptionMenu(title: "Early alert", value: ReminderDueFormatter.earlyAlertName(editor.hasTime ? editor.earlyAlert : nil)) {
                    Button(ReminderDueFormatter.earlyAlertName(nil)) { editor.earlyAlert = nil }
                    Divider()
                    ForEach(ReminderTiming.earlyAlerts, id: \.self) { interval in
                        Button(ReminderDueFormatter.earlyAlertName(interval)) { editor.earlyAlert = interval }
                    }
                }
                .disabled(!editor.hasTime)
                .opacity(editor.hasTime ? 1 : 0.35)
                .help(editor.hasTime ? "Rings this long before its time too" : "Needs a time")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(Motion.hover, value: editor.frequency)
        }
    }

    /// The ends offered for a repeat, from its first day: in a month, three, six, a year.
    private static let endPeriods: [DateComponents] = [
        DateComponents(month: 1), DateComponents(month: 3), DateComponents(month: 6), DateComponents(year: 1),
    ]
}

/// An option and its value, which opens a menu of the others.
private struct OptionMenu<Items: View>: View {
    let title: LocalizedStringKey
    let value: String
    @ViewBuilder let items: () -> Items

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.inkSecondary)
                .frame(width: 92, alignment: .leading)
            Menu {
                items()
            } label: {
                HStack(spacing: 5) {
                    Text(value)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Palette.inkTertiary)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Palette.surface, in: Capsule())
                .contentShape(Capsule())
            }
            .menuStyle(.button)
            .buttonStyle(.pressable)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A title and its switch, drawn here so it keeps its color while the notch doesn't have the keyboard,
/// where macOS draws its own switches grey.
private struct PanelSwitch: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(Motion.standard) { isOn.toggle() }
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ink.opacity(isOn ? 0.85 : 0.5))
                Capsule()
                    .fill(isOn ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(Palette.inkFaint))
                    .frame(width: 28, height: 16)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Palette.ink)
                            .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                            .padding(2)
                    }
            }
            .frame(height: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Calendar

/// The month, a day to pick in it. Today is in the module's color; days gone are dimmed.
private struct MiniCalendar: View {
    @Binding var selection: Date
    let onPick: () -> Void
    @State private var month: Date

    private let calendar = Calendar.autoupdatingCurrent

    init(selection: Binding<Date>, onPick: @escaping () -> Void) {
        _selection = selection
        self.onPick = onPick
        let calendar = Calendar.autoupdatingCurrent
        _month = State(initialValue: calendar.dateInterval(of: .month, for: selection.wrappedValue)?.start ?? selection.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 2) {
                Text(month.formatted(.dateTime.month(.wide).year()).localizedCapitalized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.opacity)
                Spacer()
                MonthArrow(systemImage: "chevron.left") { shiftMonth(by: -1) }
                    .help("Previous month")
                MonthArrow(systemImage: "chevron.right") { shiftMonth(by: 1) }
                    .help("Next month")
            }
            .frame(height: 18)

            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Palette.inkTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 12)

            VStack(spacing: 1) {
                ForEach(0 ..< 6, id: \.self) { week in
                    HStack(spacing: 0) {
                        ForEach(0 ..< 7, id: \.self) { weekday in
                            cell(days[week * 7 + weekday])
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    /// The weekday initials, starting on the week's first day where you are.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Six weeks of cells: the month's days, `nil` around them.
    private var days: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return Array(repeating: nil, count: 42) }
        let offset = (calendar.component(.weekday, from: month) - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: offset)
        cells += range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
        cells += Array(repeating: nil, count: max(42 - cells.count, 0))
        return Array(cells.prefix(42))
    }

    @ViewBuilder
    private func cell(_ date: Date?) -> some View {
        if let date {
            let isSelected = calendar.isDate(date, inSameDayAs: selection)
            let isToday = calendar.isDateInToday(date)
            let isPast = date < calendar.startOfDay(for: .now)

            Button {
                withAnimation(Motion.hover) {
                    selection = date
                    onPick()
                }
            } label: {
                Text(verbatim: "\(calendar.component(.day, from: date))")
                    .font(.system(size: 11.5, weight: isSelected || isToday ? .bold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(
                        isSelected ? Palette.onAccent
                            : isToday ? Palette.accent
                            : Palette.ink.opacity(isPast ? 0.25 : 0.85)
                    )
                    .frame(width: 24, height: 16)
                    .background {
                        if isSelected {
                            Capsule().fill(Palette.accent)
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
        } else {
            Color.clear.frame(height: 16)
        }
    }

    private func shiftMonth(by months: Int) {
        guard let shifted = calendar.date(byAdding: .month, value: months, to: month) else { return }
        withAnimation(Motion.hover) { month = shifted }
    }
}

private struct MonthArrow: View {
    let systemImage: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(Palette.ink.opacity(isHovered ? 0.9 : 0.5))
                .frame(width: 20, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Time

/// Hours and minutes on the LED display. A click on either starts typing the time there, in one go: « 1430 »
/// gives 14:30. The arrows above and below step it, minutes by five.
private struct TimeSpinner: View {
    @Binding var hour: Int
    @Binding var minute: Int
    /// A change gives the reminder a time.
    let onChange: () -> Void

    @Environment(PNotchViewModel.self) private var vm
    /// One field takes the digits of both parts, so none is lost on the way from the hours to the minutes.
    @FocusState private var isTyping: Bool
    /// Where the typing started.
    @State private var start: TimeEntry.Part = .hour
    /// The digits typed since the click.
    @State private var digits = ""

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            column(.hour, value: hour, up: { hour = (hour + 1) % 24 }, down: { hour = (hour + 23) % 24 })
            DotMatrixText(text: ":", color: Palette.ink, glows: false)
                .frame(width: 7, height: 28)
            column(.minute, value: minute, up: { minute = ReminderTiming.minute(after: minute) }, down: { minute = ReminderTiming.minute(before: minute) })
        }
        .background {
            // A real text field takes the digits: the notch only gives the keyboard to text.
            // It stays invisible, under the display, which shows what's typed.
            TextField("", text: entry)
                .textFieldStyle(.plain)
                .focused($isTyping)
                .opacity(0.02)
                .allowsHitTesting(false)
                .accessibilityLabel("Time")
        }
    }

    /// The part the next digit goes to, while typing.
    private var selected: TimeEntry.Part? {
        guard isTyping else { return nil }
        return TimeEntry.type(digits, from: start).next
    }

    private func column(_ part: TimeEntry.Part, value: Int, up: @escaping () -> Void, down: @escaping () -> Void) -> some View {
        let isSelected = selected == part

        return VStack(spacing: 3) {
            SpinnerArrow(systemImage: "chevron.up") {
                up()
                onChange()
            }
            DotMatrixText(text: String(format: "%02ld", value), color: isSelected ? Palette.accent : .white)
                .frame(width: 44, height: 28)
                .padding(.vertical, 2)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Palette.accent.opacity(0.16) : .clear)
                        .padding(.horizontal, -3)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    vm.requestKeyboardFocus()
                    start = part
                    digits = ""
                    isTyping = true
                }
                .help(part == .hour ? "Click and type the hour" : "Click and type the minutes")
            SpinnerArrow(systemImage: "chevron.down") {
                down()
                onChange()
            }
        }
    }

    /// What's typed: each digit shows at once, the hours' then the minutes'.
    private var entry: Binding<String> {
        Binding(
            get: { digits },
            set: { text in
                // A field also hands back its text when it loses the keyboard: only new digits count.
                guard text != digits else { return }
                let typing = TimeEntry.type(text, from: start)
                digits = typing.digits
                guard typing.hour != nil || typing.minute != nil else { return }
                if let value = typing.hour { hour = value }
                if let value = typing.minute { minute = value }
                onChange()
            }
        )
    }
}

private struct SpinnerArrow: View {
    let systemImage: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Palette.ink.opacity(isHovered ? 0.95 : 0.45))
                .frame(width: 44, height: 12)
                .background(Palette.ink.opacity(isHovered ? 0.1 : 0), in: Capsule())
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .onHover { isHovered = $0 }
        .animation(Motion.hover, value: isHovered)
    }
}
