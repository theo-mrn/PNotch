import SwiftUI

/// The next reminder in large, its time on the LED display; the following ones on a line below.
/// Clicking one of them brings it up.
struct RemindersSpotlightView: View {
    let items: [Reminder]
    let now: Date

    @Environment(RemindersManager.self) private var reminders
    @State private var selectedID: Reminder.ID?

    /// The one chosen, else the one ringing, else the soonest.
    private var hero: Reminder? {
        items.first { $0.id == selectedID }
            ?? items.first { reminders.ringing.contains($0.id) }
            ?? items.first
    }

    var body: some View {
        let hero = hero
        let others = items.filter { $0.id != hero?.id }

        VStack(alignment: .leading, spacing: 0) {
            if let hero {
                HeroReminder(reminder: hero, now: now)
                    .bloom(2)
                    .id(hero.id)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 6)),
                        removal: .opacity
                    ))
                    .frame(maxHeight: .infinity, alignment: .center)

                bottomLine(others: others)
                    .frame(height: 30)
                    .bloom(4)
            } else {
                RemindersEmptyState()
                    .bloom(2)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, RemindersMetrics.horizontalPadding)
        .padding(.top, 4)
        .padding(.bottom, 18)
        .onChange(of: reminders.lastAdded) { _, id in
            selectedID = id
        }
    }

    private func bottomLine(others: [Reminder]) -> some View {
        HStack(spacing: 8) {
            if others.isEmpty {
                Text("Nothing else planned")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.inkTertiary)
            } else {
                Text("Next")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.inkTertiary)
                    .padding(.trailing, 2)
                ForEach(others.prefix(2)) { item in
                    UpcomingChip(reminder: item, now: now) {
                        withAnimation(Motion.standard) { selectedID = item.id }
                    }
                }
                if others.count > 2 {
                    Text(verbatim: "+\(others.count - 2)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.inkTertiary)
                        .padding(.leading, 2)
                }
            }
            Spacer(minLength: 8)
            AddReminderButton { reminders.edit(.new) }
        }
    }
}

/// The reminder up front: its time in LED digits, its day, its title, how long until it, and what to do.
private struct HeroReminder: View {
    let reminder: Reminder
    let now: Date

    @Environment(RemindersManager.self) private var reminders

    var body: some View {
        let isRinging = reminders.ringing.contains(reminder.id)
        let color = reminder.timeColor(at: now, isRinging: isRinging)

        HStack(alignment: .center, spacing: 26) {
            VStack(alignment: .leading, spacing: 8) {
                if let due = reminder.due {
                    DotMatrixText(
                        text: ReminderDueFormatter.digits(due: due, hasTime: reminder.hasTime),
                        color: color,
                        alignment: .leading
                    )
                    .frame(width: 150, height: 38, alignment: .leading)
                    .modifier(Ringing(isActive: isRinging))
                    HStack(spacing: 5) {
                        Text(ReminderDueFormatter.dayName(of: due, at: now))
                        if let frequency = reminder.repeatRule?.frequency {
                            Label(ReminderDueFormatter.repeatName(frequency), systemImage: "repeat")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)
                } else {
                    DotMatrixText(text: "--:--", color: Palette.ink, unlitOpacity: 0.04, alignment: .leading)
                        .opacity(0.25)
                        .frame(width: 150, height: 38, alignment: .leading)
                    Text("No date")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.inkTertiary)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(reminder.title)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(reminder.note.isEmpty ? 2 : 1)
                    .fixedSize(horizontal: false, vertical: true)

                if !reminder.note.isEmpty {
                    Text(reminder.note)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                }

                if let countdown = reminder.due.flatMap({ ReminderDueFormatter.countdown(to: $0, hasTime: reminder.hasTime, at: now) }) {
                    Text(countdown)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isRinging ? Palette.accent : reminder.isOverdue(at: now) ? ReminderStyle.late : Palette.inkSecondary)
                }

                HStack(spacing: 8) {
                    ReminderPillButton(title: "Mark Done", systemImage: "checkmark", isProminent: true) {
                        reminders.toggleDone(reminder.id)
                    }
                    .opacity(reminders.finishing.contains(reminder.id) ? 0.5 : 1)
                    if reminder.hasTime {
                        ReminderPillButton(title: "+5 min") {
                            reminders.snooze(reminder.id)
                        }
                    }
                    ReminderPillButton(title: "Edit", systemImage: "pencil") {
                        reminders.edit(.edit(reminder.id))
                    }
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .contextMenu { ReminderMenu(reminder: reminder) }
    }
}

/// A reminder after the first one, on the bottom line.
private struct UpcomingChip: View {
    let reminder: Reminder
    let now: Date
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let due = reminder.due {
                    Text(ReminderDueFormatter.shortLabel(due: due, hasTime: reminder.hasTime, at: now))
                        .foregroundStyle(reminder.isOverdue(at: now) ? ReminderStyle.late : Palette.inkTertiary)
                        .monospacedDigit()
                        .fixedSize()
                }
                Text(reminder.title)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 11)
            .frame(height: 26)
            .frame(maxWidth: 230, alignment: .leading)
            .fixedSize(horizontal: true, vertical: false)
            .background(Palette.ink.opacity(isHovered ? 0.12 : 0.07), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .onHover { isHovered = $0 }
        .animation(Motion.hover, value: isHovered)
        .contextMenu { ReminderMenu(reminder: reminder) }
    }
}

/// « + »: write a new reminder.
struct AddReminderButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.ink.opacity(isHovered ? 1 : 0.8))
                .frame(width: 28, height: 28)
                .background(Palette.ink.opacity(isHovered ? 0.16 : 0.1), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.pressable)
        .onHover { isHovered = $0 }
        .animation(Motion.hover, value: isHovered)
        .help("New reminder")
    }
}

/// The LED digits breathe while the reminder rings.
private struct Ringing: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content.phaseAnimator([1.0, 0.45]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in
                .easeInOut(duration: 0.8)
            }
        } else {
            content
        }
    }
}
