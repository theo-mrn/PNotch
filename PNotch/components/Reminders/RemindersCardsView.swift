import SwiftUI

/// A card per reminder, like the modules in the Atelier; the last one writes a new reminder.
struct RemindersCardsView: View {
    let items: [Reminder]
    let now: Date

    @Environment(RemindersManager.self) private var reminders

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(items) { item in
                        ReminderCard(reminder: item, now: now)
                            .bloom(2 + (items.firstIndex { $0.id == item.id } ?? 0), from: 0.85)
                            .id(item.id)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }

                    NewReminderCard { reminders.edit(.new) }
                        .id(Self.newCardID)

                    if items.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("No reminders")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                            Text("Tell me what and when, the way you'd say it.")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(Palette.inkTertiary)
                        }
                        .padding(.leading, 8)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, RemindersMetrics.horizontalPadding)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.never)
            .mask {
                HStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: 16)
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: 24)
                }
            }
            .onAppear {
                // Back from the editor: show the reminder just written.
                if let id = reminders.lastAdded {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.top, 2)
        .padding(.bottom, 14)
    }

    private static let newCardID = "new"
}

private enum CardMetrics {
    static let size = CGSize(width: 140, height: 118)
    static let cornerRadius: CGFloat = 18
}

private struct ReminderCard: View {
    let reminder: Reminder
    let now: Date

    @Environment(RemindersManager.self) private var reminders
    @State private var isHovered = false

    var body: some View {
        let isRinging = reminders.ringing.contains(reminder.id)
        let isFinishing = reminders.finishing.contains(reminder.id)
        let shape = RoundedRectangle(cornerRadius: CardMetrics.cornerRadius, style: .continuous)

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                if let due = reminder.due {
                    DotMatrixText(
                        text: ReminderDueFormatter.digits(due: due, hasTime: reminder.hasTime),
                        color: reminder.timeColor(at: now, isRinging: isRinging),
                        unlitOpacity: 0.06,
                        glows: false,
                        alignment: .leading
                    )
                    .frame(width: 76, height: 15, alignment: .leading)
                } else {
                    Text("No date")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.inkTertiary)
                        .frame(height: 15)
                }
                Spacer(minLength: 4)
                ReminderCheck(reminder: reminder, size: 18)
            }

            if let detail {
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isRinging ? Palette.accent : reminder.isOverdue(at: now) ? ReminderStyle.late : Palette.inkTertiary)
                    .lineLimit(1)
                    .padding(.top, 6)
            }

            Spacer(minLength: 6)

            Text(reminder.title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Palette.ink.opacity(isFinishing ? 0.35 : 0.95))
                .strikethrough(isFinishing, color: Palette.inkTertiary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .frame(width: CardMetrics.size.width, height: CardMetrics.size.height, alignment: .topLeading)
        .background(shape.fill(isRinging ? Palette.accent.opacity(0.16) : Palette.ink.opacity(isHovered ? 0.09 : 0.06)))
        .overlay(shape.strokeBorder(isRinging ? Palette.accent.opacity(0.45) : Palette.surface, lineWidth: 1))
        .scaleEffect(isHovered ? 1.03 : 1)
        .contentShape(shape)
        // A click opens it in the editor; the box keeps its own click.
        .onTapGesture { reminders.edit(.edit(reminder.id)) }
        .onHover { isHovered = $0 }
        .help("Edit")
        .contextMenu { ReminderMenu(reminder: reminder) }
        .animation(Motion.snappy, value: isHovered)
        .animation(Motion.hover, value: isFinishing)
    }

    /// How long until it today, else its day.
    private var detail: String? {
        guard let due = reminder.due else { return nil }
        return ReminderDueFormatter.countdown(to: due, hasTime: reminder.hasTime, at: now)
            ?? ReminderDueFormatter.dayName(of: due, at: now)
    }
}

/// The last card: « + », a new reminder.
private struct NewReminderCard: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CardMetrics.cornerRadius, style: .continuous)

        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink.opacity(isHovered ? 1 : 0.8))
                    .frame(width: 36, height: 36)
                    .background(Palette.ink.opacity(isHovered ? 0.16 : 0.1), in: Circle())
                Text("New reminder")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.inkSecondary)
            }
            .frame(width: CardMetrics.size.width, height: CardMetrics.size.height)
            .background(shape.strokeBorder(Palette.ink.opacity(isHovered ? 0.2 : 0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            .contentShape(shape)
        }
        .buttonStyle(.pressable)
        .onHover { isHovered = $0 }
        .animation(Motion.hover, value: isHovered)
    }
}
