import Defaults
import SwiftUI

/// The Reminders module, in the layout chosen in Settings › Modules, or its editor in its place.
/// Its countdowns follow the minute, only while it's on screen.
struct RemindersView: View {
    @Environment(RemindersManager.self) private var reminders
    @Default(.remindersLayout) private var layout

    var body: some View {
        VStack(spacing: 0) {
            if reminders.panel == .alert, let ringing = reminders.ringingReminder {
                ReminderAlertView(reminder: ringing)
                    .transition(.opacity)
            } else {
                page
            }
        }
        .onDisappear { reminders.stopRinging() }
    }

    private var page: some View {
        VStack(spacing: 0) {
            NotchHeaderView()

            Group {
                if reminders.editor != nil {
                    ReminderComposerView()
                        .transition(.opacity)
                } else {
                    TimelineView(.everyMinute) { timeline in
                        let items = reminders.reminders
                        Group {
                            switch layout {
                            case .spotlight: RemindersSpotlightView(items: items, now: timeline.date)
                            case .list: RemindersListView(items: items, now: timeline.date)
                            case .cards: RemindersCardsView(items: items, now: timeline.date)
                            }
                        }
                        .animation(Motion.standard, value: items)
                    }
                    .transition(.opacity)
                }
            }
            .frame(height: RemindersMetrics.bodyHeight(reminders.panel), alignment: .top)
            .pageEntrance()
        }
    }
}

extension RemindersManager {
    /// Opens the editor, the page turning into it.
    func edit(_ target: ReminderEditorTarget) {
        withAnimation(ReminderComposerView.animation) { openEditor(target) }
    }
}

// MARK: - Look

extension Reminder {
    /// The color its time shows in: the module's while it rings, red once late, white otherwise.
    func timeColor(at now: Date, isRinging: Bool) -> Color {
        if isRinging {
            return Palette.accent
        }
        return isOverdue(at: now) ? ReminderStyle.late : Palette.ink
    }
}

enum ReminderStyle {
    static let late = Palette.danger
}

// MARK: - Empty

/// No reminder yet: what the module is for, and a way to start.
struct RemindersEmptyState: View {
    /// Without it, the layout offers its own way to add one.
    var showsButton = true

    @Environment(RemindersManager.self) private var reminders

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "bell")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Palette.accent)
                .frame(width: 44, height: 44)
                .background(Palette.accent.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("No reminders")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("Tell me what and when, the way you'd say it.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Palette.inkTertiary)
            }

            Spacer(minLength: 12)

            if showsButton {
                ReminderPillButton(title: "New reminder", systemImage: "plus", isProminent: true) {
                    reminders.edit(.new)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Done

/// The round box: it fills when ticked, and the reminder leaves a moment later.
struct ReminderCheck: View {
    let reminder: Reminder
    var size: CGFloat = 18

    @Environment(RemindersManager.self) private var reminders
    @Environment(CompanionManager.self) private var companion
    @State private var isHovered = false

    var body: some View {
        let isDone = reminders.finishing.contains(reminder.id)

        Button {
            if !isDone {
                companion.bring(.reminderDone)
            }
            reminders.toggleDone(reminder.id)
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(Palette.ink.opacity(isDone ? 0 : isHovered ? 0.6 : 0.28), lineWidth: 1.5)
                Circle()
                    .fill(Palette.accent)
                    .scaleEffect(isDone ? 1 : 0.2)
                    .opacity(isDone ? 1 : 0)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.45, weight: .heavy))
                    .foregroundStyle(Palette.onAccent)
                    .scaleEffect(isDone ? 1 : 0.3)
                    .opacity(isDone ? 1 : 0)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(.pressable)
        .onHover { isHovered = $0 }
        .animation(Motion.pop, value: isDone)
        .animation(Motion.hover, value: isHovered)
        .help(isDone ? "Keep" : "Mark Done")
    }
}

/// Right-click on a reminder.
struct ReminderMenu: View {
    let reminder: Reminder
    @Environment(RemindersManager.self) private var reminders

    var body: some View {
        Button("Edit…") { reminders.edit(.edit(reminder.id)) }
        Button("Mark Done") { reminders.toggleDone(reminder.id) }
        Button("Remind Me in 5 Minutes") { reminders.snooze(reminder.id) }
        Divider()
        Button("Delete", role: .destructive) { reminders.remove(reminder.id) }
    }
}

/// A capsule button of the reminders: « Fait », « +10 min », « Enregistrer ».
struct ReminderPillButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var isProminent = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10.5, weight: .bold))
                }
                Text(title)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isProminent ? Palette.onAccent : Palette.ink)
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background {
                Capsule().fill(isProminent ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(Palette.ink.opacity(isHovered ? 0.16 : 0.1)))
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .onHover { isHovered = $0 }
        .animation(Motion.hover, value: isHovered)
    }
}
