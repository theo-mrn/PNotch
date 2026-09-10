import SwiftUI

/// Previous, play/pause and next.
struct MusicControlsView: View {
    @Environment(MusicManager.self) private var music

    var body: some View {
        HStack(spacing: 22) {
            MusicControlButton(systemImage: "backward.fill", symbolSize: 16) {
                music.previousTrack()
            }
            .help("Previous track")
            .disabled(music.playback == nil)

            MusicControlButton(systemImage: music.isPlaying ? "pause.fill" : "play.fill", symbolSize: 24) {
                music.togglePlayPause()
            }
            .help(music.isPlaying ? "Pause" : "Play")

            MusicControlButton(systemImage: "forward.fill", symbolSize: 16) {
                music.nextTrack()
            }
            .help("Next track")
            .disabled(music.playback == nil)
        }
    }
}

private struct MusicControlButton: View {
    let systemImage: String
    let symbolSize: CGFloat
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: symbolSize, weight: .semibold))
                .contentTransition(.symbolEffect(.replace.downUp))
                .foregroundStyle(Palette.ink.opacity(isEnabled ? 0.95 : 0.3))
                .frame(width: symbolSize * 1.9, height: symbolSize * 1.9)
                .background {
                    Circle().fill(Palette.ink.opacity(isHovered && isEnabled ? 0.12 : 0))
                }
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .onHover { isHovered = $0 }
        .animation(Motion.hover, value: isHovered)
    }
}

/// Shrinks slightly while pressed, like the system media controls.
private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(Motion.pop, value: configuration.isPressed)
    }
}
