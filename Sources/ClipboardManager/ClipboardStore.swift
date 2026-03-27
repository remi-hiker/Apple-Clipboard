import Foundation
import AppKit

/// Central store holding the clipboard history and driving UI updates.
final class ClipboardStore: ObservableObject {

    // Maximum number of unpinned entries kept (mirrors Windows clipboard).
    static let maxHistory = 25

    @Published private(set) var items: [ClipboardItem] = []

    // MARK: - Mutating helpers

    /// Add a new item to the top of history (after deduplication).
    func add(_ item: ClipboardItem) {
        // Remove any existing entry with the same textual content so we don't
        // get duplicates when the same text is copied twice.
        if case .text(let incoming) = item.content {
            items.removeAll { existing in
                if case .text(let t) = existing.content, t == incoming, !existing.isPinned {
                    return true
                }
                return false
            }
        }

        items.insert(item, at: 0)
        trimHistory()
        objectWillChange.send()
    }

    /// Write item contents back to the system clipboard.
    /// The caller is responsible for restoring app focus and triggering simulatePaste().
    func paste(item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()

        switch item.content {
        case .text(let text):
            if let attr = item.attributedString {
                pb.writeObjects([attr])
            } else {
                pb.setString(text, forType: .string)
            }
        case .image(let img):
            pb.writeObjects([img])
        case .fileURLs(let urls):
            pb.writeObjects(urls as [NSURL])
        case .unknown:
            break
        }
    }

    // MARK: - Pin / unpin

    func togglePin(item: ClipboardItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].isPinned.toggle()
            // Move pinned items to the front of their respective groups so they
            // always appear at the top of the list.
            sortItems()
            objectWillChange.send()
        }
    }

    // MARK: - Deletion

    func delete(item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        objectWillChange.send()
    }

    /// Remove all unpinned items (mirrors "Clear all" in Windows clipboard).
    func clearAll() {
        items.removeAll { !$0.isPinned }
        objectWillChange.send()
    }

    // MARK: - Private

    private func trimHistory() {
        var unpinnedCount = 0
        items = items.filter { item in
            if item.isPinned { return true }
            unpinnedCount += 1
            return unpinnedCount <= Self.maxHistory
        }
    }

    private func sortItems() {
        // Pinned items stay at the top, in their original insertion order.
        let pinned   = items.filter { $0.isPinned }
        let unpinned = items.filter { !$0.isPinned }
        items = pinned + unpinned
    }

    // MARK: - CGEvent paste simulation

    static func simulatePaste() {
        // ⌘V: keyDown then keyUp.
        // .combinedSessionState source ensures the event reflects the real
        // modifier state; .cgSessionEventTap is the correct delivery point
        // for keyboard events targeting the frontmost application.
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 9  // kVK_ANSI_V = 0x09

        if let down = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true) {
            down.flags = .maskCommand
            down.post(tap: .cgSessionEventTap)
        }
        if let up = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false) {
            up.flags = .maskCommand
            up.post(tap: .cgSessionEventTap)
        }
    }
}
