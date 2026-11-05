import SwiftUI

/// Airy rows, like the alarms of the Clock app: the time in large, the title, how long until it, a box to tick.
struct RemindersListView: View {
    let items: [Reminder]
    let now: Date

    @Environment(RemindersManager.self) private var reminders

    var body: some View {
        VStack(spacing: 6) {
            if items.isEmpty {
                RemindersEmptyState()
                    .bloom(2)
                    .transition(.opacity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        VStack(spacing: 0) {
                            ForEach(items) { item in
                                ReminderRow(reminder: item, now: now)
                                    .bloom(2 + (items.firstIndex { $0.id == item.id } ?? 0))
                                    .id(item.id)
                                    .overlay(alignment: .bottom) {
                                        if item.id != items.last?.id {
                                            Rectangle()
                                                .fill(Palette.surface)
                                                .frame(height: 1)
                                                .padding(.leading, ReminderRow.timeWidth)
                                        }
                                    }
                                    .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 0.98))))
                            }
                        }
                    }
                    .scrollIndicators(.never)
                    .mask {
                        VStack(spacing: 0) {
                            Color.black
                            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: 6)
                        }
                    }
                    .onAppear {
                        // Back from the editor: show the reminder just written.
                        if let id = reminders.lastAdded {
                            proxy.scrollTo(id)
                        }
                    }
                }

                NewReminderButton { reminders.edit(.new) }
                    .frame(height: 30)
            }
        }
        .padding(.horizontal, RemindersMetrics.horizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}

private struct ReminderRow: View {
    let reminder: Reminder
    let now: Date

    /// The time column, which the separators start after.
    static let timeWidth: CGFloat = 80

    @Environment(RemindersManager.self) private var reminders
    @State private var isHovered = false

    var body: some View {
        let isRinging = reminders.ringing.contains(reminder.id)
        let isFinishing = reminders.finishing.contains(reminder.id)

        HStack(spacing: 0) {
            time(isRinging: isRinging)
                .frame(width: Self.timeWidth, alignment: .leading)

            Text(reminder.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.ink.opacity(isFinishing ? 0.35 : 0.92))
                .strikethrough(isFinishing, color: Palette.inkTertiary)
                .lineLimit(1)

            Spacer(minLength: 12)

            if let detail = detail(isRinging: isRinging) {
                HStack(spacing: 4) {
                    if isRinging {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .symbolEffect(.pulse)
                    }
                    Text(detail)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isRinging ? Palette.accent : reminder.isOverdue(at: now) ? ReminderStyle.late : Palette.inkTertiary)
                .padding(.trailing, 14)
            }

            ReminderCheck(reminder: reminder, size: 20)
        }
        .frame(height: RemindersMetrics.listRowHeight)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.ink.opacity(isHovered ? 0.05 : 0))
                .padding(.horizontal, -8)
        }
        .contentShape(Rectangle())
        // A click opens it in the editor; the box keeps its own click.
        .onTapGesture { reminders.edit(.edit(reminder.id)) }
        .onHover { isHovered = $0 }
        .help("Edit")
        .contextMenu { ReminderMenu(reminder: reminder) }
        .animation(Motion.hover, value: isFinishing)
    }

    @ViewBuilder
    private func time(isRinging: Bool) -> some View {
        if let due = reminder.due, reminder.hasTime {
            Text(due.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(reminder.timeColor(at: now, isRinging: isRinging))
        } else if let due = reminder.due {
            Text(ReminderDueFormatter.shortLabel(due: due, hasTime: false, at: now))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(reminder.isOverdue(at: now) ? ReminderStyle.late : Palette.inkSecondary)
        } else {
            Text(verbatim: "—")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.inkFaint)
        }
    }

    /// How long until it today, else its day.
    private func detail(isRinging: Bool) -> String? {
        guard let due = reminder.due, reminder.hasTime else { return nil }
        if let countdown = ReminderDueFormatter.countdown(to: due, hasTime: true, at: now) {
            return countdown
        }
        return ReminderDueFormatter.dayName(of: due, at: now)
    }
}

/// « + Nouveau rappel », under the list.
struct NewReminderButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("New reminder")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Palette.accent.opacity(isHovered ? 1 : 0.85))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .onHover { isHovered = $0 }
        .animation(Motion.hover, value: isHovered)
    }
}
