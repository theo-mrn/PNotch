import Foundation

/// A note: plain text, its first line is its title.
nonisolated struct Note: Equatable, Identifiable, Codable, Sendable {
    var id = UUID()
    var text: String
    var createdAt: Date
    var modifiedAt: Date

    private var lines: [Substring] {
        text.split(whereSeparator: \.isNewline).filter { !$0.allSatisfy(\.isWhitespace) }
    }

    /// Its first line.
    var title: String {
        lines.first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
    }

    /// The lines after the first, list markers (« - », « * », « • ») made into bullets.
    var bodyLines: [String] {
        lines.dropFirst().map { line in
            let text = line.trimmingCharacters(in: .whitespaces)
            for marker in ["- ", "* ", "• ", "– "] where text.hasPrefix(marker) {
                return "• " + text.dropFirst(marker.count).trimmingCharacters(in: .whitespaces)
            }
            return text
        }
    }

    /// The line after the title, without its bullet: what a list shows under it.
    var preview: String {
        guard let line = bodyLines.first else { return "" }
        return line.hasPrefix("• ") ? String(line.dropFirst(2)) : line
    }

    var isBlank: Bool {
        text.allSatisfy(\.isWhitespace)
    }

    /// Its paper in the Post-it layout, the same every time.
    var paperIndex: Int {
        Int(id.uuid.0) % NotePaper.count
    }
}

/// The colors of the Post-it layout.
nonisolated enum NotePaper {
    static let count = 4
}

/// The notes, as JSON in PNotch's Application Support folder.
nonisolated struct NotesStore: Sendable {
    let fileURL: URL

    static let live = NotesStore(
        fileURL: URL.applicationSupportDirectory
            .appending(path: Bundle.main.bundleIdentifier ?? "com.pnotch.PNotch", directoryHint: .isDirectory)
            .appending(path: "notes.json", directoryHint: .notDirectory)
    )

    func load() -> [Note] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Note].self, from: data)) ?? []
    }

    func save(_ notes: [Note]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(notes).write(to: fileURL, options: .atomic)
    }
}
