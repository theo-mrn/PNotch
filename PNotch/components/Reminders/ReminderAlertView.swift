import SwiftUI

/// A reminder ringing, brought by Pixel in a small notch: what it is, its time, and two answers,
/// later or done. Answering folds the notch back if the reminder opened it.
struct ReminderAlertView: View {
    let reminder: Reminder

    @Environment(RemindersManager.self) private var reminders
    @Environment(CompanionManager.self) private var companion
    @Environment(PNotchViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 0) {
            // The camera's row stays clear.
            Color.clear
                .frame(height: vm.geometry.notchSize.height)

            HStack(spacing: Space.l) {
                PixelBadgeTile()
                    .bloom(1, from: 0.5)

                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(reminder.title)
                        .font(TypeScale.title)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .bloom(2)
                    Text(time)
                        .font(.system(size: 14, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                        .bloom(3)

                    HStack(spacing: Space.s) {
                        AlertButton(title: "5 min", systemImage: "zzz", isProminent: false) {
                            answer { reminders.snooze(reminder.id) }
                        }
                        .accessibilityLabel(Text("Remind Me in 5 Minutes"))
                        AlertButton(title: "Mark Done", systemImage: "checkmark.circle.fill", isProminent: true) {
                            companion.bring(.reminderDone)
                            answer { reminders.toggleDone(reminder.id) }
                        }
                    }
                    .padding(.top, Space.s)
                    .bloom(4)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.xxl)
            .frame(maxHeight: .infinity)
            .padding(.bottom, Space.l)
        }
    }

    /// Its time, or its day when it has none.
    private var time: String {
        guard let due = reminder.due else { return "" }
        if reminder.hasTime {
            return due.formatted(date: .omitted, time: .shortened)
        }
        return ReminderDueFormatter.shortLabel(due: due, hasTime: false, at: .now)
    }

    /// Answers it; once nothing rings any more, the notch it opened folds back.
    private func answer(_ action: () -> Void) {
        withAnimation(Motion.standard) { action() }
        if !reminders.isRinging, vm.openReason == .reminder {
            vm.close(reason: .answered)
        }
    }
}

/// Pixel in a warm tile, a bell on its corner.
private struct PixelBadgeTile: View {
    static let size: CGFloat = 72

    var body: some View {
        RobotView(followsPointer: false, mood: .excited)
            .padding(.top, Space.xs)
            .frame(width: Self.size, height: Self.size)
            .background {
                RoundedRectangle(cornerRadius: Radius.l + 2, style: .continuous)
                    .fill(Color(hex: 0xF6D3B3))
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.onAccent)
                    .modifier(RingingBell())
                    .frame(width: 24, height: 24)
                    .background(Palette.accent, in: Circle())
                    .background(Circle().stroke(.black, lineWidth: 3))
                    .offset(x: 6, y: 6)
            }
            .accessibilityHidden(true)
    }
}

/// The bell swings now and then while it rings; on macOS 14, which can't swing it, it pulses.
private struct RingingBell: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.symbolEffect(.wiggle, options: .repeat(.periodic(delay: 1.6)))
        } else {
            content.symbolEffect(.pulse)
        }
    }
}

/// « 5 min » and « Fait »: capsules big enough to hit without aiming.
private struct AlertButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let isProminent: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(TypeScale.label)
                .foregroundStyle(isProminent ? Palette.onAccent : Palette.ink)
                .padding(.horizontal, Space.m + 2)
                .frame(height: 32)
                .background {
                    Capsule().fill(isProminent ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(isHovered ? Palette.inkFaint : Palette.surfaceRaised))
                }
                .brightness(isProminent && isHovered ? 0.05 : 0)
                .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .onHover { isHovered = $0 }
        .animation(Motion.hover, value: isHovered)
    }
}
