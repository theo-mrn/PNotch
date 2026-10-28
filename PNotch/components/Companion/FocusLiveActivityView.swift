import SwiftUI

/// Around the closed notch during a focus session, its break or the stopwatch: the companion busy with you,
/// and the time left, or elapsed.
struct FocusLiveActivityView: View {
    let session: FocusSession
    let notchSize: CGSize

    var body: some View {
        HStack(spacing: 0) {
            CompanionMessengerFace(mood: .content, activity: session.phase == .rest ? .resting : .focusing) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(width: NotchMetrics.timerSideWidth)

            Color.clear
                .frame(width: notchSize.width)

            // Still while paused: nothing to update.
            TimelineView(.animation(minimumInterval: 1, paused: session.isPaused)) { timeline in
                DotMatrixText(
                    text: PlaybackTimeFormatter.string(from: session.displayedTime(at: timeline.date)),
                    // White LEDs, dimmed while paused; the phase's color is on the left.
                    color: session.isPaused ? Palette.inkSecondary : Palette.ink,
                    unlitOpacity: 0.05,
                    // Small and light around the camera: fine dots, no glow.
                    glows: false,
                    dotScale: 0.7
                )
                .frame(height: 12)
                // A little more room on the outside, where the notch's corner curves.
                .padding(.leading, 4)
                .padding(.trailing, 8)
            }
            .frame(width: NotchMetrics.timerSideWidth)
        }
        .frame(height: notchSize.height)
    }

    private var color: Color {
        session.phase == .rest ? FocusColor.rest : FocusColor.focus
    }

    private var symbol: String {
        switch session.phase {
        case .focus: "timer"
        case .rest: "cup.and.saucer.fill"
        case .stopwatch: "stopwatch"
        }
    }
}

/// Flashes around the closed notch when a focus session or a break comes to an end.
struct FocusSneakPeekView: View {
    let event: FocusTimer.Event
    let notchSize: CGSize

    @State private var hasAppeared = false

    var body: some View {
        HStack(spacing: 0) {
            CompanionMessengerFace {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FocusColor.focus)
            }
            .frame(width: NotchMetrics.sneakPeekSideWidth)

            Color.clear
                .frame(width: notchSize.width)

            Image(systemName: event == .focusFinished ? "checkmark.seal.fill" : "play.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(event == .focusFinished ? FocusColor.focus : Palette.ink)
                .symbolEffect(.bounce, value: hasAppeared)
                .frame(width: NotchMetrics.sneakPeekSideWidth)
        }
        .frame(height: notchSize.height)
        .onAppear { hasAppeared = true }
    }
}
