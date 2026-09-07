import Foundation

/// An app content comes from: the one in front when something was copied, or the music player.
nonisolated struct SourceApplication: Hashable, Codable, Sendable {
    let bundleIdentifier: String
    let name: String
}
