import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Opens the searchable list under the notch; pressing it again moves to the next item.
    /// Keeps the "toggleClipboard" storage key so a shortcut customised in Settings carries over.
    static let clipboardList = Self("toggleClipboard", initial: .init(.v, modifiers: [.command, .control]))
}
