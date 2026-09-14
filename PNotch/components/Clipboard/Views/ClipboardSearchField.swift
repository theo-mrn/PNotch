import SwiftUI

/// Large borderless search field topping the clipboard list, filtering it as you type.
struct ClipboardSearchField: View {
    @Environment(PNotchViewModel.self) private var vm
    @Environment(ClipboardStateViewModel.self) private var clipboard
    @FocusState private var isFocused: Bool
    @State private var isHovered = false

    var body: some View {
        @Bindable var clipboard = clipboard

        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Palette.ink.opacity(isFocused ? 0.85 : 0.5))

            TextField("Search clipboard…", text: $clipboard.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Palette.ink)
                .focused($isFocused)

            trailingAccessory
        }
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            vm.requestKeyboardFocus()
            isFocused = true
        }
        .onHover { isHovered = $0 }
        .onChange(of: clipboard.searchFocusRequest) {
            isFocused = true
        }
        .task {
            // Opened with the keyboard or a click: the window became key before this field existed.
            await Task.yield()
            if vm.isKeyboardFocused() {
                isFocused = true
            }
        }
        .animation(Motion.hover, value: isFocused)
        .animation(Motion.hover, value: isHovered)
        .animation(Motion.hover, value: clipboard.isSearching)
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        if clipboard.isSearching {
            HStack(spacing: 6) {
                Text(resultCount)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(Palette.inkTertiary)
                    .contentTransition(.numericText())

                Button {
                    clipboard.clearSearch()
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.inkSecondary)
                        .contentShape(Circle())
                }
                .buttonStyle(.pressable)
                .help("Clear search (esc)")
            }
            .transition(.opacity)
        }
    }

    private var resultCount: LocalizedStringKey {
        let count = clipboard.visibleItems.count
        return count == 0 ? "No results" : "^[\(count) result](inflect: true)"
    }
}
