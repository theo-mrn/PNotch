import Defaults
import KeyboardShortcuts
import os
import ServiceManagement
import SwiftUI

/// Settings window: a sidebar of panes, like System Settings.
struct SettingsView: View {
    @State private var selection: SettingsPane = .general

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(SettingsPane.allCases) { pane in
                    Label {
                        Text(pane.title)
                    } icon: {
                        SettingsPaneIcon(pane: pane)
                    }
                    .tag(pane)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 200)

            Divider()

            Group {
                switch selection {
                case .general: GeneralPane()
                case .tabs: ModulesPane()
                case .clipboard: ClipboardPane()
                case .music: MusicPane()
                case .companion: CompanionPane()
                case .shortcuts: ShortcutsPane()
                case .about: AboutPane()
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 720, height: 520)
    }
}

// MARK: - Panes

enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case tabs
    case clipboard
    case music
    case companion
    case shortcuts
    case about

    var id: Self {
        self
    }

    var title: LocalizedStringKey {
        switch self {
        case .general: "General"
        case .tabs: "Modules"
        case .clipboard: "Clipboard"
        case .music: "Music"
        case .companion: "Companion"
        case .shortcuts: "Shortcuts"
        case .about: "About"
        }
    }

    fileprivate var symbolName: String {
        switch self {
        case .general: "gearshape.fill"
        case .tabs: "square.grid.2x2.fill"
        case .clipboard: "doc.on.clipboard.fill"
        case .music: "music.note"
        case .companion: "face.smiling.inverse"
        case .shortcuts: "command"
        case .about: "info.circle.fill"
        }
    }

}

/// Colored rounded tile behind the pane symbol, as in System Settings.
private struct SettingsPaneIcon: View {
    let pane: SettingsPane

    var body: some View {
        Image(systemName: pane.symbolName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .frame(width: 22, height: 22)
            .background(Color(hex: 0x636366).gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - General

private struct GeneralPane: View {
    @Environment(UpdateManager.self) private var updates
    @Default(.menubarIcon) private var menubarIcon
    @Default(.openNotchOnHover) private var openNotchOnHover
    @Default(.enableHaptics) private var enableHaptics
    @State private var checksAutomatically = false

    var body: some View {
        Form {
            Section {
                LaunchAtLoginToggle()
                Toggle("Show menu bar icon", isOn: $menubarIcon)
                Toggle("Open the notch on hover", isOn: $openNotchOnHover)
                Toggle("Haptic feedback", isOn: $enableHaptics)
            }

            Section {
                if updates.isAvailable {
                    Toggle("Check for updates automatically", isOn: $checksAutomatically)
                        .onChange(of: checksAutomatically) { _, newValue in
                            updates.automaticallyChecksForUpdates = newValue
                        }
                    Button("Check for Updates Now") {
                        updates.checkForUpdates()
                    }
                } else {
                    LabeledContent("Automatic updates") {
                        Text("Available in published versions")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Updates")
            }
        }
        .onAppear {
            checksAutomatically = updates.automaticallyChecksForUpdates
        }
    }
}

// MARK: - Modules

private struct ModulesPane: View {
    /// Observed so the list follows the Atelier.
    @Default(.installedModules) private var installedModules
    @Default(.startPage) private var startPage

    var body: some View {
        let modules = installedModules.map { NotchModules(installed: $0) } ?? NotchModules.current
        let available = NotchModules.catalog.filter { !modules.isInstalled($0) }

        Form {
            Section {
                ForEach(Array(modules.installed.enumerated()), id: \.element) { index, page in
                    ModuleRow(
                        page: page,
                        isInstalled: true,
                        canUninstall: modules.installed.count > 1,
                        canMoveUp: index > 0,
                        canMoveDown: index < modules.installed.count - 1
                    ) { change in
                        update { change(&$0) }
                    }
                }
                ForEach(available, id: \.self) { page in
                    ModuleRow(page: page, isInstalled: false, canUninstall: true, canMoveUp: false, canMoveDown: false) { change in
                        update { change(&$0) }
                    }
                }
            } header: {
                Text("Modules")
            } footer: {
                Text("The installed modules are the notch's tabs, in this order. You can also plug them in from the Atelier: click Pixel, on the right of the tabs.")
            }

            Section {
                Picker("Open the notch on", selection: $startPage) {
                    Text("The last page used").tag(NotchPage?.none)
                    Divider()
                    ForEach(modules.installed + [.companion], id: \.self) { page in
                        Text(page.title).tag(NotchPage?.some(page))
                    }
                }
            } footer: {
                Text("The keyboard shortcuts always open the clipboard.")
            }
        }
    }

    private func update(_ change: (inout NotchModules) -> Void) {
        var modules = NotchModules.current
        change(&modules)
        withAnimation(Motion.hover) {
            NotchModules.current = modules
        }
    }
}

private struct ModuleRow: View {
    let page: NotchPage
    let isInstalled: Bool
    let canUninstall: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onChange: ((inout NotchModules) -> Void) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: page.cardSymbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 22, height: 22)
                .background(Color(hex: 0x636366).gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .saturation(isInstalled ? 1 : 0.4)
            Text(page.title)
                .foregroundStyle(isInstalled ? .primary : .secondary)

            Spacer()

            if isInstalled {
                Button {
                    onChange { $0.move(page, by: -1) }
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(!canMoveUp)
                .help("Move up")

                Button {
                    onChange { $0.move(page, by: 1) }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(!canMoveDown)
                .help("Move down")
            }

            Toggle("Installed", isOn: Binding(
                get: { isInstalled },
                set: { install in
                    onChange { modules in
                        if install {
                            modules.install(page)
                        } else {
                            modules.uninstall(page)
                        }
                    }
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(isInstalled && !canUninstall)
        }
        .buttonStyle(.borderless)
    }
}

// MARK: - Clipboard

private struct ClipboardPane: View {
    @Environment(ClipboardStateViewModel.self) private var clipboard
    @Default(.pasteDirectly) private var pasteDirectly
    @Default(.clipboardHistoryLimit) private var historyLimit
    @Default(.fetchLinkPreviews) private var fetchLinkPreviews
    @Default(.showCopySneakPeek) private var showCopySneakPeek
    @Default(.closeNotchAfterCopy) private var closeNotchAfterCopy
    @State private var isConfirmingClear = false

    var body: some View {
        Form {
            Section {
                Toggle("Paste directly into the app in use", isOn: $pasteDirectly)
                if pasteDirectly {
                    AccessibilityStatusRow()
                }
            } header: {
                Text("Pasting")
            } footer: {
                Text("Hold ⌥ (Option) while choosing an item to copy it without pasting.")
            }

            Section {
                Picker("Keep", selection: $historyLimit) {
                    ForEach(clipboardHistoryLimitOptions, id: \.self) { limit in
                        Text("\(limit) items").tag(limit)
                    }
                }
                Toggle("Fetch link previews", isOn: $fetchLinkPreviews)
                Toggle("Show a sneak peek when something is copied", isOn: $showCopySneakPeek)
                Toggle("Close the notch after copying", isOn: $closeNotchAfterCopy)
                Button("Clear History…", role: .destructive) {
                    isConfirmingClear = true
                }
                .confirmationDialog("Clear the clipboard history?", isPresented: $isConfirmingClear) {
                    Button("Clear History", role: .destructive) {
                        clipboard.clearHistory()
                    }
                } message: {
                    Text("Pinned items are kept.")
                }
            } header: {
                Text("History")
            } footer: {
                Text("Passwords and other content marked as confidential are never recorded. Pinned items are never removed automatically.")
            }

            Section("In the notch") {
                ShortcutRow(title: "Select", keys: "↑ ↓")
                ShortcutRow(title: pasteDirectly ? "Paste" : "Copy", keys: "↩")
                if pasteDirectly {
                    ShortcutRow(title: "Copy without pasting", keys: "⌥↩")
                }
                ShortcutRow(title: "Use as plain text", keys: "⇧↩")
                ShortcutRow(title: "Search", keys: "⌘F")
                ShortcutRow(title: "Pin / unpin", keys: "⌘P")
                ShortcutRow(title: "Delete", keys: "⌘⌫")
            }
        }
    }
}

/// Whether PNotch may paste, with the way to grant it. Refreshes while shown,
/// so it turns green as soon as access is given in System Settings.
private struct AccessibilityStatusRow: View {
    @State private var isTrusted = PasteService.isTrusted

    var body: some View {
        LabeledContent {
            if !isTrusted {
                Button("Open System Settings") {
                    PasteService.requestPermissionIfNeeded()
                    PasteService.openAccessibilitySettings()
                }
            }
        } label: {
            Label {
                Text(isTrusted ? "Accessibility access granted" : "Needs Accessibility access to paste")
            } icon: {
                Image(systemName: isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(isTrusted ? Palette.accent : Palette.danger)
            }
        }
        .task {
            while !Task.isCancelled {
                isTrusted = PasteService.isTrusted
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

// MARK: - Music

private struct MusicPane: View {
    @Default(.showMusicLiveActivity) private var showMusicLiveActivity

    var body: some View {
        Form {
            Section {
                Toggle("Show what's playing around the closed notch", isOn: $showMusicLiveActivity)
            } footer: {
                Text("Works with any app that reports to Now Playing: Music, Spotify, podcasts, video in a browser…")
            }
        }
    }
}

// MARK: - Companion

private struct CompanionPane: View {
    @Default(.companionName) private var name
    @Default(.companionOnEveryPage) private var onEveryPage
    @Default(.companionAnnouncesCopies) private var announces

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Show \(name) on every page"), isOn: $onEveryPage)
                Toggle("Announce news around the closed notch", isOn: $announces)
            } footer: {
                Text("\(name) reacts to what you do everywhere: it dances to your music and catches your copies. In the Atelier, it presents the modules you can plug in. Right-click it to pet it; its looks are behind the paintbrush.")
            }
        }
    }
}

// MARK: - Shortcuts

private struct ShortcutsPane: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Clipboard", name: .clipboardList)
            } footer: {
                Text("Press the list shortcut again to move to the next item, then ↩ to use it.")
            }
        }
    }
}

// MARK: - About

private struct AboutPane: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("PNotch")
                            .font(.title2.weight(.semibold))
                        Text("Version \(appVersion)")
                            .foregroundStyle(.secondary)
                        Text("Music, clipboard, system monitor and a robot companion, in the notch.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Acknowledgements") {
                Credit(name: "DynamicNotchKit", detail: "Notch shape · MIT")
                Credit(name: "mediaremote-adapter", detail: "Now Playing · BSD 3-Clause")
                Credit(name: "Defaults, KeyboardShortcuts", detail: "Sindre Sorhus · MIT")
                Credit(name: "Sparkle", detail: "Updates · MIT")
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}

private struct Credit: View {
    let name: String
    let detail: String

    var body: some View {
        LabeledContent(name) {
            Text(detail)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Shared rows

private struct LaunchAtLoginToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("Launch at login", isOn: Binding(get: { isEnabled }, set: setEnabled))
    }

    private func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger.app.error("Failed to update the login item: \(error.localizedDescription)")
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}

private struct ShortcutRow: View {
    let title: LocalizedStringKey
    let keys: String

    var body: some View {
        LabeledContent(title) {
            Text(keys)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}
