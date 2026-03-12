import SwiftUI
import AppKit

/// The main floating clipboard history panel — the macOS equivalent of the
/// Windows ⊞+V overlay.
struct ClipboardHistoryView: View {
    @ObservedObject var store: ClipboardStore

    /// Dismiss callback wired up by the window controller.
    var onDismiss: (() -> Void)?

    @State private var searchText = ""
    @State private var showClearConfirm = false
    @FocusState private var searchFocused: Bool

    // MARK: - Derived lists

    private var allFiltered: [ClipboardItem] {
        guard !searchText.isEmpty else { return store.items }
        return store.items.filter { item in
            switch item.content {
            case .text(let t):
                return t.localizedCaseInsensitiveContains(searchText)
            case .fileURLs(let urls):
                return urls.contains {
                    $0.lastPathComponent.localizedCaseInsensitiveContains(searchText)
                }
            default:
                return false
            }
        }
    }

    private var pinnedItems:   [ClipboardItem] { allFiltered.filter { $0.isPinned } }
    private var unpinnedItems: [ClipboardItem] { allFiltered.filter { !$0.isPinned } }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            Divider()
            itemList
            Divider()
            footer
        }
        .frame(width: 380, height: 520)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
            .ignoresSafeArea())
        .cornerRadius(12)
        // Dismiss on Escape
        .onKeyPress(.escape) {
            onDismiss?()
            return .handled
        }
        .onAppear { searchFocused = true }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("Clipboard", systemImage: "clipboard")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            if !store.items.filter({ !$0.isPinned }).isEmpty {
                Button("Clear all") {
                    showClearConfirm = true
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
                .confirmationDialog(
                    "Clear clipboard history?",
                    isPresented: $showClearConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Clear all", role: .destructive) { store.clearAll() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Pinned items will not be removed.")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 13))

            TextField("Search clipboard history", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(.textBackgroundColor).opacity(0.6))
        .cornerRadius(8)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Item list

    @ViewBuilder
    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 2, pinnedViews: [.sectionHeaders]) {

                // Pinned section
                if !pinnedItems.isEmpty {
                    Section {
                        ForEach(pinnedItems) { item in
                            ClipboardItemView(item: item, store: store, onPaste: onDismiss)
                        }
                    } header: {
                        sectionHeader(title: "Pinned", icon: "pin.fill")
                    }
                }

                // Recent section
                if !unpinnedItems.isEmpty {
                    Section {
                        ForEach(unpinnedItems) { item in
                            ClipboardItemView(item: item, store: store, onPaste: onDismiss)
                        }
                    } header: {
                        if !pinnedItems.isEmpty {
                            sectionHeader(title: "Recent", icon: "clock")
                        }
                    }
                }

                // Empty state
                if allFiltered.isEmpty {
                    emptyState
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: searchText.isEmpty ? "clipboard" : "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text(searchText.isEmpty
                 ? "Nothing copied yet"
                 : "No results for "\(searchText)"")
                .foregroundColor(.secondary)
                .font(.callout)
        }
        .frame(maxWidth: .infinity)
        .padding(50)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("⌘⇧: to toggle")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Spacer()
            Text("\(store.items.count) item\(store.items.count == 1 ? "" : "s")")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
