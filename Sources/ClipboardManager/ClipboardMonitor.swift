import Foundation
import AppKit

/// Polls `NSPasteboard` on a background timer and pushes new entries to the
/// shared `ClipboardStore` whenever the change-count increments.
final class ClipboardMonitor {

    private let store: ClipboardStore
    private var changeCount: Int
    private var timer: Timer?

    /// How often (seconds) to poll the system clipboard.
    private let pollInterval: TimeInterval = 0.5

    init(store: ClipboardStore) {
        self.store = store
        self.changeCount = NSPasteboard.general.changeCount
    }

    // MARK: - Lifecycle

    func start() {
        timer = Timer.scheduledTimer(
            withTimeInterval: pollInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkClipboard()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Polling

    private func checkClipboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != changeCount else { return }
        changeCount = pb.changeCount

        guard let item = readCurrentItem(from: pb) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.store.add(item)
        }
    }

    // MARK: - Reading pasteboard contents

    private func readCurrentItem(from pb: NSPasteboard) -> ClipboardItem? {
        // 1. Try rich text (attributed string)
        if let rtfData = pb.data(forType: .rtf),
           let attrStr = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
            return ClipboardItem(
                content: .text(attrStr.string),
                attributedString: attrStr
            )
        }

        // 2. Plain text
        if let text = pb.string(forType: .string), !text.isEmpty {
            return ClipboardItem(content: .text(text))
        }

        // 3. Image (TIFF or PNG)
        if let tiffData = pb.data(forType: .tiff),
           let image = NSImage(data: tiffData) {
            return ClipboardItem(content: .image(image))
        }
        if let pngData = pb.data(forType: .png),
           let image = NSImage(data: pngData) {
            return ClipboardItem(content: .image(image))
        }

        // 4. File URLs
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty {
            return ClipboardItem(content: .fileURLs(urls))
        }

        return nil
    }
}
