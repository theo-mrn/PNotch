import Defaults
import SwiftUI

/// The timer module: focus sessions and breaks, 25/5 or 50/10, or a stopwatch.
/// Laid out like the music: the ring where the cover is, the phase as the title, the day under it,
/// and at the bottom the rhythm on the left and what to do on the right.
/// The clock only ticks on screen while it runs.
struct TimerView: View {
    @Environment(FocusManager.self) private var focus
    @Default(.focusRhythm) private var rhythm
    @Default(.timerUsesStopwatch) private var usesStopwatch

    var body: some View {
        VStack(spacing: 0) {
            NotchHeaderView()

            TimelineView(.animation(minimumInterval: 1, paused: !isRunning)) { timeline in
                HStack(spacing: Space.xl) {
                    TimerRing(
                        progress: focus.session?.progress(at: timeline.date) ?? 0,
                        color: color,
                        time: focus.session?.displayedTime(at: timeline.date) ?? idleTime,
                        digitColor: focus.session?.isPaused == true ? Palette.inkSecondary : Palette.ink
                    )
                    .frame(width: TimerMetrics.ringSize, height: TimerMetrics.ringSize)
                    .bloom(2, from: 0.75)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(phaseTitle)
                            .font(TypeScale.title)
                            .foregroundStyle(Palette.ink)
                            .contentTransition(.opacity)
                            .bloom(3)
                        Text(caption)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Palette.inkSecondary)
                            .lineLimit(1)
                            .padding(.top, Space.xxs)
                            .bloom(3)

                        Spacer(minLength: Space.m)

                        HStack(spacing: Space.m) {
                            leading(at: timeline.date)
                            Spacer(minLength: 0)
                            controls
                        }
                        .bloom(4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: TimerMetrics.ringSize, alignment: .leading)
                }
            }
            .padding(.horizontal, TimerMetrics.horizontalPadding)
            .frame(height: TimerMetrics.bodyHeight)
            .pageEntrance()
        }
        .animation(Motion.standard, value: focus.session)
    }

    /// Before starting, the rhythm to pick; counting down, when it ends.
    @ViewBuilder
    private func leading(at date: Date) -> some View {
        if let session = focus.session {
            if session.isPaused {
                Text("Paused")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.inkTertiary)
            } else if session.countsDown {
                Text("Ends at \(date.addingTimeInterval(session.remaining(at: date)).formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Palette.inkTertiary)
            }
        } else {
            TimerModePicker(rhythm: $rhythm, usesStopwatch: $usesStopwatch)
                .transition(.opacity)
        }
    }

    private var isRunning: Bool {
        focus.session.map { !$0.isPaused } ?? false
    }

    private var idleTime: TimeInterval {
        usesStopwatch ? 0 : rhythm.focusDuration
    }

    private var phaseTitle: String {
        guard let session = focus.session else {
            return usesStopwatch ? String(localized: "Stopwatch") : String(localized: "Ready?")
        }
        if session.isPaused {
            return String(localized: "Paused")
        }
        return switch session.phase {
        case .focus: String(localized: "Focus")
        case .rest: String(localized: "Break")
        case .stopwatch: String(localized: "Stopwatch")
        }
    }

    private var color: Color {
        guard let session = focus.session, !session.isPaused else { return Palette.inkSecondary }
        return session.phase == .rest ? FocusColor.rest : FocusColor.focus
    }

    @ViewBuilder
    private var controls: some View {
        if let session = focus.session {
            HStack(spacing: 8) {
                if session.phase == .rest {
                    TimerControlButton(systemImage: "plus", label: "5", help: "Add 5 minutes") { focus.addTime() }
                    TimerControlButton(systemImage: "forward.end.fill", help: "Skip the break") { focus.cancel() }
                } else {
                    if session.isPaused {
                        TimerControlButton(systemImage: "play.fill", help: "Resume") { focus.resume() }
                    } else {
                        TimerControlButton(systemImage: "pause.fill", help: "Pause") { focus.pause() }
                    }
                    if session.countsDown {
                        TimerControlButton(systemImage: "plus", label: "5", help: "Add 5 minutes") { focus.addTime() }
                    }
                    TimerControlButton(systemImage: "stop.fill", help: "Stop") { focus.cancel() }
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
        } else {
            Button {
                usesStopwatch ? focus.startStopwatch() : focus.startFocus()
            } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, Space.l)
                    .frame(height: 32)
                    .background(Palette.accent, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.pressable)
            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
        }
    }

    /// The day so far.
    private var caption: String {
        let today = focus.today
        return [
            String(localized: "\(today.completedSessions) sessions today"),
            String(localized: "\(Int(today.focusedTime / 60)) min of focus"),
        ].joined(separator: " · ")
    }
}

// MARK: - Pieces

enum FocusColor {
    /// Pixel's headband red.
    static let focus = Palette.accent
    static let rest = Palette.muted
}

/// The time in a ring that fills as it goes.
private struct TimerRing: View {
    let progress: Double
    let color: Color
    let time: TimeInterval
    /// White LEDs, dimmed while paused; the ring carries the phase's color.
    let digitColor: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.surface, lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.5), radius: 6)
                // The stopwatch starts a new lap each minute: no animating backwards.
                .animation(progress < 0.02 ? nil : .linear(duration: 1), value: progress)

            // An LED display, like Pixel's visor.
            DotMatrixText(text: PlaybackTimeFormatter.string(from: time), color: digitColor)
                .frame(width: 84, height: 28)
        }
    }
}

/// 25/5, 50/10 or the stopwatch.
private struct TimerModePicker: View {
    @Binding var rhythm: FocusRhythm
    @Binding var usesStopwatch: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(FocusRhythm.allCases, id: \.self) { option in
                chip(isSelected: !usesStopwatch && rhythm == option) {
                    Text(verbatim: "\(Int(option.focusDuration / 60))/\(Int(option.breakDuration / 60))")
                } action: {
                    rhythm = option
                    usesStopwatch = false
                }
            }
            chip(isSelected: usesStopwatch) {
                Text("Stopwatch")
            } action: {
                usesStopwatch = true
            }
        }
        .padding(2)
        .background(Palette.surface, in: Capsule())
        .help("Minutes of focus, then of break; or a stopwatch")
    }

    private func chip(isSelected: Bool, @ViewBuilder label: () -> some View, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label()
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(Palette.ink.opacity(isSelected ? 1 : 0.5))
                .padding(.horizontal, 9)
                .frame(height: 22)
                .background {
                    if isSelected {
                        Capsule().fill(Palette.inkFaint)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
    }
}

private struct TimerControlButton: View {
    let systemImage: String
    /// A short label next to the symbol, like the 5 of « +5 ».
    var label: String?
    let help: LocalizedStringKey
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 1) {
                Image(systemName: systemImage)
                    .font(.system(size: label == nil ? 13 : 10, weight: .bold))
                if let label {
                    Text(verbatim: label)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(Palette.ink)
            .frame(width: 34, height: 34)
            .background(Circle().fill(Palette.ink.opacity(isHovered ? 0.2 : 0.12)))
            .contentShape(Circle())
        }
        .buttonStyle(.pressable)
        .onHover { isHovered = $0 }
        .help(help)
    }
}
