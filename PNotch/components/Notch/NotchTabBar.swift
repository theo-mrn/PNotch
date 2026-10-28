import Defaults
import SwiftUI

/// The modules plugged in from the Atelier, always all in view: no scrolling, nothing cut.
/// The selected tab spells out its name when there's room; otherwise every tab is an icon, tighter still
/// on the widest camera housings. The Atelier isn't a tab: Pixel, on the right, opens it.
struct NotchTabBar: View {
    @Environment(PNotchViewModel.self) private var vm
    /// Observed so the bar follows the Atelier.
    @Default(.installedModules) private var installedModules
    @Namespace private var selection

    var body: some View {
        let pages = installedModules.map { NotchModules(installed: $0) }?.installed ?? NotchModules.current.installed

        ViewThatFits(in: .horizontal) {
            bar(pages, style: .titled)
            bar(pages, style: .icons)
            bar(pages, style: .tight)
        }
        .animation(Motion.standard, value: pages)
    }

    private func bar(_ pages: [NotchPage], style: NotchTab.Style) -> some View {
        HStack(spacing: style == .titled ? 4 : NotchHeaderMetrics.tabSpacing) {
            ForEach(pages, id: \.self) { page in
                NotchTab(page: page, isSelected: vm.page == page, style: style, selection: selection) {
                    select(page)
                }
                // A module plugged in from the Atelier pops into place.
                .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .padding(NotchHeaderMetrics.tabBarPadding)
        .background(Palette.surface, in: Capsule())
        .fixedSize()
    }

    private func select(_ page: NotchPage) {
        withAnimation(Motion.standard) {
            vm.select(page)
        }
    }
}

private struct NotchTab: View {
    enum Style {
        /// The selected tab spells out its name.
        case titled
        /// Every tab an icon.
        case icons
        /// Every tab an icon, closer together.
        case tight
    }

    let page: NotchPage
    let isSelected: Bool
    let style: Style
    let selection: Namespace.ID
    let action: () -> Void

    @Environment(ClaudeCodeManager.self) private var claudeCode
    @State private var isHovered = false

    /// Counts the times it was chosen, to make its icon hop.
    @State private var hops = 0

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                icon
                if isSelected, style == .titled {
                    Text(page.title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
                }
            }
            .foregroundStyle(isSelected || isHovered ? Palette.ink : Palette.inkSecondary)
            .padding(.horizontal, style == .titled && isSelected ? 10 : 0)
            .frame(minWidth: style == .tight ? NotchHeaderMetrics.tightTabWidth : NotchHeaderMetrics.tabWidth)
            .frame(height: NotchHeaderMetrics.controlHeight - 4)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Palette.selection)
                        .matchedGeometryEffect(id: "selectedTab", in: selection)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .onHover { isHovered = $0 }
        .help(page.title)
        .accessibilityLabel(Text(page.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onChange(of: isSelected) { _, isSelected in
            if isSelected { hops += 1 }
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch page {
        default:
            Image(systemName: page.symbolName)
                .font(.system(size: 10.5, weight: .semibold))
                // Chosen, it hops.
                .symbolEffect(.bounce.up, value: hops)
                .overlay(alignment: .topTrailing) {
                    if let badge {
                        Circle()
                            .fill(badge)
                            .frame(width: 6, height: 6)
                            .offset(x: 4, y: -3)
                    }
                }
        }
    }

    /// A dot when the module needs you: Claude Code waiting.
    private var badge: Color? {
        switch page {
        case .claudeCode where claudeCode.needsAttention: Palette.accent
        default: nil
        }
    }
}

extension NotchPage {
    var title: String {
        switch self {
        case .music: String(localized: "Music")
        case .clipboard: String(localized: "Clipboard")
        case .system: String(localized: "System")
        case .companion: String(localized: "Atelier")
        case .claudeCode: "Claude Code"
        case .timer: String(localized: "Timer")
        }
    }

    var symbolName: String {
        switch self {
        case .music: "music.note"
        case .clipboard: "doc.on.clipboard"
        case .system: "gauge.with.dots.needle.67percent"
        case .companion: "plus"
        case .claudeCode: "terminal"
        case .timer: "timer"
        }
    }
}
