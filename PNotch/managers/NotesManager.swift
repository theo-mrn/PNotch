import Foundation
import Observation

/// The notes, the last edited first. Written to disk once typing pauses; a note left blank goes away.
@Observable
final class NotesManager {
    private(set) var notes: [Note]
    /// The note open in the list and Post-it layouts.
    private(set) var selectedID: Note.ID?

    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let store: NotesStore
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var needsSaving = false

    /// How long typing pauses before the notes are written.
    static let saveDelay: Duration = .milliseconds(800)

    init(now: @escaping () -> Date = { .now }, store: NotesStore = .live) {
        self.now = now
        self.store = store
        notes = store.load()
            .filter { !$0.isBlank }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    var selectedNote: Note? {
        notes.first { $0.id == selectedID }
    }

    func text(of id: Note.ID) -> String {
        notes.first { $0.id == id }?.text ?? ""
    }

    // MARK: Single sheet

    /// The single sheet is the last note edited.
    var sheetText: String {
        notes.first?.text ?? ""
    }

    func setSheetText(_ text: String) {
        if let first = notes.first {
            update(first.id, text: text)
        } else if !text.isEmpty {
            let note = Note(text: text, createdAt: now(), modifiedAt: now())
            notes.insert(note, at: 0)
            scheduleSave()
        }
    }

    // MARK: Changes

    /// Writes into a note, which moves to the top.
    func update(_ id: Note.ID, text: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }), notes[index].text != text else { return }
        var note = notes.remove(at: index)
        note.text = text
        note.modifiedAt = now()
        notes.insert(note, at: 0)
        scheduleSave()
    }

    /// A blank note at the top, open.
    @discardableResult
    func create() -> Note {
        discardBlankNotes()
        let note = Note(text: "", createdAt: now(), modifiedAt: now())
        notes.insert(note, at: 0)
        selectedID = note.id
        return note
    }

    func select(_ id: Note.ID?) {
        guard id != selectedID else { return }
        selectedID = id
        discardBlankNotes(keeping: id)
    }

    func delete(_ id: Note.ID) {
        notes.removeAll { $0.id == id }
        if selectedID == id {
            selectedID = nil
        }
        scheduleSave()
    }

    /// Notes left blank go, except the one being written.
    func discardBlankNotes(keeping kept: Note.ID? = nil) {
        let count = notes.count
        notes.removeAll { $0.isBlank && $0.id != kept }
        if notes.count != count {
            if let selectedID, !notes.contains(where: { $0.id == selectedID }) {
                self.selectedID = nil
            }
            scheduleSave()
        }
    }

    /// Writes the notes now, if they changed.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        guard needsSaving else { return }
        needsSaving = false
        try? store.save(notes.filter { !$0.isBlank })
    }

    // MARK: Private

    private func scheduleSave() {
        needsSaving = true
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }
}
