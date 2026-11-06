import Defaults
import SwiftUI

/// The Notes module, in the layout chosen in Settings › Modules.
struct NotesView: View {
    @Environment(NotesManager.self) private var notes
    @Default(.notesLayout) private var layout

    var body: some View {
        VStack(spacing: 0) {
            NotchHeaderView()

            Group {
                switch layout {
                case .sheet: NotesSheetView()
                case .list: NotesListView()
                case .stickies: NotesStickiesView()
                }
            }
            .frame(height: NotesMetrics.bodyHeight)
            .pageEntrance()
        }
        .onDisappear {
            notes.discardBlankNotes()
            notes.flush()
        }
    }
}

// MARK: - Look

extension Note {
    /// Its paper in the Post-it layout.
    var paperColor: Color {
        NoteStyle.papers[paperIndex]
    }
}

enum NoteStyle {
    static let papers = [Palette.accent, Palette.muted, Color(hex: 0x8E8E93), Palette.ink]

    /// When a note was last written: « 14:02 » today, « Hier », « 12 nov. ».
    static func date(_ date: Date, at now: Date = .now) -> String {
        switch ReminderDueFormatter.day(of: date, at: now) {
        case .today: date.formatted(date: .omitted, time: .shortened)
        case .yesterday: String(localized: "Yesterday")
        default: date.formatted(.dateTime.day().month(.abbreviated))
        }
    }

    /// A note's title, or what a new one is called until it has one.
    static func title(of note: Note) -> String {
        note.title.isEmpty ? String(localized: "New note") : note.title
    }
}

/// No note yet: what the module is for, and a way to start.
struct NotesEmptyState: View {
    @Environment(NotesManager.self) private var notes
    @Environment(PNotchViewModel.self) private var vm
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "note.text")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Palette.accent)
                .frame(width: 44, height: 44)
                .background(Palette.accent.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("No notes yet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("Somewhere to jot things down, kept until you need them.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Palette.inkTertiary)
            }

            Spacer(minLength: 12)

            Button {
                vm.requestKeyboardFocus()
                notes.create()
            } label: {
                Label("New note", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Palette.accent, in: Capsule())
                    .brightness(isHovered ? 0.05 : 0)
                    .contentShape(Capsule())
            }
            .buttonStyle(.pressable)
            .onHover { isHovered = $0 }
        }
        .padding(.horizontal, NotesMetrics.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// « + Nouvelle note ».
struct NewNoteButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("New note")
                    .font(.system(size: 13, weight: .semibold))
            }
            // Like « New reminder »: the page's own way to add, in the accent.
            .foregroundStyle(Palette.accent.opacity(isHovered ? 1 : 0.85))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.leading, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .onHover { isHovered = $0 }
        .animation(Motion.hover, value: isHovered)
    }
}

// MARK: - A single sheet

/// One sheet across the notch: open, write. It's the last note written.
struct NotesSheetView: View {
    @Environment(NotesManager.self) private var notes

    var body: some View {
        ZStack(alignment: .topLeading) {
            NoteTextView(
                text: Binding(get: { notes.sheetText }, set: { notes.setSheetText($0) }),
                fontSize: 14,
                lineSpacing: 4,
                insertionColor: Palette.accent
            )
            if notes.sheetText.isEmpty {
                Text("Write anything here. It stays until you erase it.")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.inkFaint)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, NotesMetrics.horizontalPadding + 2)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }
}

// MARK: - Several notes

/// The notes on the left, the open one on the right, like a small Notes app.
struct NotesListView: View {
    @Environment(NotesManager.self) private var notes
    @Environment(PNotchViewModel.self) private var vm

    var body: some View {
        let selected = notes.selectedNote ?? notes.notes.first

        if notes.notes.isEmpty {
            NotesEmptyState()
        } else {
            list(selected: selected)
        }
    }

    private func list(selected: Note?) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                ScrollView(.vertical) {
                    VStack(spacing: 2) {
                        ForEach(notes.notes) { note in
                            NoteRow(note: note, isSelected: note.id == selected?.id) {
                                notes.select(note.id)
                            }
                            .bloom(2 + (notes.notes.firstIndex { $0.id == note.id } ?? 0))
                        }
                    }
                }
                .scrollIndicators(.never)
                .mask {
                    VStack(spacing: 0) {
                        Color.black
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 8)
                    }
                }

                NewNoteButton {
                    vm.requestKeyboardFocus()
                    notes.create()
                }
                .frame(height: 26)
            }
            .frame(width: 186)

            Rectangle()
                .fill(Palette.surface)
                .frame(width: 1)
                .padding(.horizontal, 18)

            Group {
                if let selected {
                    NoteTextView(
                        text: Binding(get: { notes.text(of: selected.id) }, set: { notes.update(selected.id, text: $0) }),
                        fontSize: 13.5,
                        insertionColor: Palette.accent,
                        focusesOnAppear: selected.isBlank
                    )
                    .id(selected.id)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.leading, 16)
        .padding(.trailing, NotesMetrics.horizontalPadding)
        .padding(.top, Space.s)
        .padding(.bottom, Space.m)
        .animation(Motion.hover, value: selected?.id)
    }
}

private struct NoteRow: View {
    let note: Note
    let isSelected: Bool
    let action: () -> Void

    @Environment(NotesManager.self) private var notes
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(NoteStyle.title(of: note))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Palette.ink.opacity(note.title.isEmpty ? 0.5 : 0.92))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(NoteStyle.date(note.modifiedAt))
                        .foregroundStyle(Palette.inkTertiary)
                        .fixedSize()
                    Text(note.preview)
                        .foregroundStyle(Palette.inkTertiary)
                        .lineLimit(1)
                }
                .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Palette.ink.opacity(isSelected ? 0.11 : isHovered ? 0.05 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .onHover { isHovered = $0 }
        .animation(Motion.hover, value: isHovered)
        .contextMenu {
            Button("Delete", role: .destructive) { notes.delete(note.id) }
        }
    }
}

// MARK: - Post-it

/// Small paper notes side by side; one opens to write in it.
struct NotesStickiesView: View {
    @Environment(NotesManager.self) private var notes
    @Environment(PNotchViewModel.self) private var vm
    @State private var openID: Note.ID?
    @Namespace private var paper

    var body: some View {
        Group {
            if let openID, let note = notes.notes.first(where: { $0.id == openID }) {
                OpenSticky(note: note, namespace: paper) {
                    close()
                }
                .padding(.horizontal, NotesMetrics.horizontalPadding)
            } else {
                shelf
            }
        }
        .padding(.top, 2)
        .padding(.bottom, 14)
        .animation(Motion.standard, value: openID)
    }

    private var shelf: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(notes.notes) { note in
                    StickyCard(note: note, namespace: paper) {
                        open(note.id)
                    }
                    .bloom(2 + (notes.notes.firstIndex { $0.id == note.id } ?? 0), from: 0.8)
                }
                NewStickyCard {
                    vm.requestKeyboardFocus()
                    open(notes.create().id)
                }
                if notes.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No notes yet")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        Text("Somewhere to jot things down, kept until you need them.")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                    .padding(.leading, 8)
                }
            }
            .padding(.horizontal, NotesMetrics.horizontalPadding)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.never)
        .frame(maxHeight: .infinity)
        .mask {
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: 16)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: 24)
            }
        }
    }

    private func open(_ id: Note.ID) {
        notes.select(id)
        openID = id
    }

    private func close() {
        openID = nil
        notes.select(nil)
    }
}

private enum StickyMetrics {
    static let size = CGSize(width: 136, height: 118)
    static let cornerRadius: CGFloat = 16
    /// A slight tilt, the same for a note every time.
    static let tilts: [Double] = [-1.6, 1.2, -0.6, 1.6]
}

private struct StickyCard: View {
    let note: Note
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: StickyMetrics.cornerRadius, style: .continuous)

        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Text(NoteStyle.title(of: note))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(note.bodyLines.joined(separator: "\n"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Text(NoteStyle.date(note.modifiedAt))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(note.paperColor.opacity(0.85))
            }
            .padding(12)
            .frame(width: StickyMetrics.size.width, height: StickyMetrics.size.height, alignment: .topLeading)
            .background {
                shape
                    .fill(note.paperColor.opacity(isHovered ? 0.18 : 0.13))
                    .matchedGeometryEffect(id: note.id, in: namespace)
            }
            .overlay(shape.strokeBorder(note.paperColor.opacity(0.22), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.pressable)
        .rotationEffect(.degrees(isHovered ? 0 : StickyMetrics.tilts[note.paperIndex]))
        .scaleEffect(isHovered ? 1.03 : 1)
        .onHover { isHovered = $0 }
        .animation(Motion.snappy, value: isHovered)
    }
}

/// A note opened from the shelf, its paper spread across the notch.
private struct OpenSticky: View {
    let note: Note
    let namespace: Namespace.ID
    let close: () -> Void

    @Environment(NotesManager.self) private var notes

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Button(action: close) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Notes")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(note.paperColor)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .help("Back to the notes")

                Spacer()

                Button {
                    notes.delete(note.id)
                    close()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.inkTertiary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .help("Delete")
            }

            NoteTextView(
                text: Binding(get: { notes.text(of: note.id) }, set: { notes.update(note.id, text: $0) }),
                fontSize: 13.5,
                insertionColor: note.paperColor,
                focusesOnAppear: note.isBlank
            )
            .id(note.id)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            shape
                .fill(note.paperColor.opacity(0.11))
                .matchedGeometryEffect(id: note.id, in: namespace)
        }
        .overlay(shape.strokeBorder(note.paperColor.opacity(0.22), lineWidth: 1))
    }
}

/// The last card: a new note.
private struct NewStickyCard: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: StickyMetrics.cornerRadius, style: .continuous)

        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink.opacity(isHovered ? 1 : 0.8))
                    .frame(width: 36, height: 36)
                    .background(Palette.ink.opacity(isHovered ? 0.16 : 0.1), in: Circle())
                Text("New note")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.inkSecondary)
            }
            .frame(width: StickyMetrics.size.width, height: StickyMetrics.size.height)
            .background(shape.strokeBorder(Palette.ink.opacity(isHovered ? 0.2 : 0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            .contentShape(shape)
        }
        .buttonStyle(.pressable)
        .onHover { isHovered = $0 }
        .animation(Motion.hover, value: isHovered)
    }
}
