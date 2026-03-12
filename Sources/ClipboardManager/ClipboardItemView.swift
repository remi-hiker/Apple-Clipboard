import SwiftUI
import AppKit

/// A single row/card in the clipboard history list.
struct ClipboardItemView: View {
    let item: ClipboardItem
    @ObservedObject var store: ClipboardStore

    /// Called when the user clicks the item (paste & dismiss).
    var onPaste: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        Button(action: {
            store.paste(item: item)
            onPaste?()
        }) {
            HStack(alignment: .top, spacing: 10) {
                // Left: icon or thumbnail
                itemThumbnail
                    .frame(width: 40, height: 40)
                    .cornerRadius(6)

                // Middle: content preview + timestamp
                VStack(alignment: .leading, spacing: 2) {
                    previewText
                        .lineLimit(2)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)

                    Text(item.relativeTime)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right: action buttons (visible on hover)
                if isHovered {
                    actionButtons
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered
                          ? Color.accentColor.opacity(0.15)
                          : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button(item.isPinned ? "Unpin" : "Pin") {
                store.togglePin(item: item)
            }
            Divider()
            Button("Delete", role: .destructive) {
                store.delete(item: item)
            }
        }
        .padding(.horizontal, 6)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var itemThumbnail: some View {
        switch item.content {
        case .text:
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.1))
                Image(systemName: "doc.text")
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)
            }

        case .image(let img):
            Image(nsImage: img)
                .resizable()
                .scaledToFill()
                .clipped()

        case .fileURLs(let urls):
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.orange.opacity(0.1))
                if urls.count == 1,
                   let icon = NSWorkspace.shared.icon(forFile: urls[0].path) as NSImage? {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "folder")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                }
            }

        case .unknown:
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.1))
                Image(systemName: "questionmark")
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var previewText: some View {
        let text = item.previewText
        if text.isEmpty {
            Text("(empty)")
                .italic()
                .foregroundColor(.secondary)
        } else {
            Text(text)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 6) {
            // Pin / unpin
            Button(action: { store.togglePin(item: item) }) {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12))
                    .foregroundColor(item.isPinned ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(item.isPinned ? "Unpin" : "Pin to keep")

            // Delete
            Button(action: { store.delete(item: item) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove from history")
        }
    }
}
