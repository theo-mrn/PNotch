import Defaults
import SwiftUI

/// The Atelier's shelf: every module, presented by Pixel. Hovering one, Pixel explains it;
/// clicking plugs it into the notch, or unplugs it.
struct AtelierView: View {
    @Environment(CompanionManager.self) private var companion
    @Environment(FocusManager.self) private var focus
    @Default(.companionName) private var name
    /// Observed so the cards follow what's plugged in.
    @Default(.installedModules) private var installedModules
    @State private var hovered: NotchPage?
    @State private var announcement: (text: String, date: Date)?

    /// How long Pixel's answer to a click stays up.
    private static let announcementDuration: TimeInterval = 2.5

    var body: some View {
        let modules = installedModules.map { NotchModules(installed: $0) } ?? NotchModules.current

        VStack(alignment: .leading, spacing: 8) {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                PixelBubble(text: bubbleText(at: timeline.date))
            }
            .bloom(3, from: 0.85)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(NotchModules.catalog, id: \.self) { page in
                        ModuleCard(page: page, isInstalled: modules.isInstalled(page)) {
                            toggle(page)
                        }
                        .bloom(4 + (NotchModules.catalog.firstIndex(of: page) ?? 0), from: 0.8)
                        .onHover { isHovering in
                            if isHovering {
                                hovered = page
                            } else if hovered == page {
                                hovered = nil
                            }
                        }
                    }
                }
                .padding(.vertical, 3)
                .padding(.trailing, 24)
            }
            .scrollIndicators(.never)
            // Fades out on the right: there's more on the shelf.
            .mask {
                HStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 28)
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func bubbleText(at date: Date) -> String {
        if let hovered {
            return hovered.pitch
        }
        if let announcement, date.timeIntervalSince(announcement.date) < Self.announcementDuration {
            return announcement.text
        }
        return CompanionMoodLine.text(name: name, companion: companion, focus: focus, at: date)
    }

    private func toggle(_ page: NotchPage) {
        var modules = NotchModules.current
        if modules.isInstalled(page) {
            if modules.uninstall(page) {
                announce(String(localized: "Unplugged. It's still here if you want it back."))
            } else {
                announce(String(localized: "I need at least one module to show in the notch."))
                return
            }
        } else {
            modules.install(page)
            announce(String(localized: "\(page.title) is plugged in!"))
            companion.bring(.pluggedIn)
        }
        withAnimation(Motion.standard) {
            NotchModules.current = modules
        }
    }

    private func announce(_ text: String) {
        hovered = nil
        announcement = (text, .now)
    }
}

// MARK: - Pixel's bubble

/// What Pixel says, in a speech bubble pointing at it.
private struct PixelBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(Palette.ink)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .padding(.vertical, 7)
            .background(BubbleShape().fill(Palette.surface))
            .contentTransition(.opacity)
            .animation(Motion.hover, value: text)
    }
}

/// A rounded bubble with a small tail on its left, towards Pixel.
nonisolated private struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let tail: CGFloat = 6
        let body = CGRect(x: rect.minX + tail, y: rect.minY, width: rect.width - tail, height: rect.height)
        var path = Path(roundedRect: body, cornerRadius: 11, style: .continuous)
        path.move(to: CGPoint(x: body.minX, y: body.midY - 5))
        path.addLine(to: CGPoint(x: rect.minX, y: body.midY))
        path.addLine(to: CGPoint(x: body.minX, y: body.midY + 5))
        path.closeSubpath()
        return path
    }
}

// MARK: - Module card

private struct ModuleCard: View {
    let page: NotchPage
    let isInstalled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)

        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(isInstalled ? Palette.accentSoft : Palette.surface)
                    Image(systemName: page.cardSymbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isInstalled ? Palette.accent : Palette.inkSecondary)
                        .symbolEffect(.bounce, value: isHovered)
                }
                .frame(height: 52)
                // Plugged in or not, on the tile's corner rather than spelled out on every card.
                .overlay(alignment: .topTrailing) {
                    Image(systemName: isInstalled ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(isInstalled ? Palette.onAccent : Palette.ink, isInstalled ? Palette.accent : Palette.selection)
                        .contentTransition(.symbolEffect(.replace))
                        .background(Circle().fill(.black).padding(-1.5))
                        .offset(x: 5, y: -5)
                }

                Text(page.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(isInstalled ? Palette.ink : Palette.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(8)
            .frame(width: AtelierMetrics.cardWidth)
            .background(shape.fill(Palette.ink.opacity(isHovered ? 0.1 : 0.05)))
            .overlay {
                shape.strokeBorder(Palette.line, lineWidth: 1)
            }
            .scaleEffect(isHovered ? 1.03 : 1)
            .contentShape(shape)
        }
        .buttonStyle(.pressable)
        .onHover { isHovered = $0 }
        .animation(Motion.snappy, value: isHovered)
        .animation(Motion.standard, value: isInstalled)
        .help(isInstalled ? String(localized: "Unplug \(page.title)") : String(localized: "Plug \(page.title) into the notch"))
    }
}

// MARK: - Modules, as the Atelier presents them

extension NotchPage {
    /// What Pixel says about the module.
    var pitch: String {
        switch self {
        case .music: String(localized: "I show what's playing, cover and all, and let you skip or pause.")
        case .clipboard: String(localized: "I keep everything you copy, to find and paste again.")
        case .system: String(localized: "I watch the processor, memory, network and battery for you.")
        case .claudeCode: String(localized: "I follow your Claude Code sessions and tell you when they need you.")
        case .timer: String(localized: "Focus sessions and breaks, or a stopwatch: I keep the time.")
        case .reminders: String(localized: "Tell me what and when, in plain words: I'll remind you when it's time.")
        case .companion: ""
        }
    }

    /// A fuller symbol than the tab's, for the card.
    var cardSymbol: String {
        switch self {
        case .music: "music.note"
        case .clipboard: "doc.on.clipboard.fill"
        case .system: "gauge.with.dots.needle.67percent"
        case .claudeCode: "terminal.fill"
        case .timer: "timer"
        case .reminders: "bell.fill"
        case .companion: "plus"
        }
    }
}
