import Foundation
import AppKit

// MARK: - Content type stored per clipboard entry

enum ClipboardContent {
    case text(String)
    case image(NSImage)
    case fileURLs([URL])
    case unknown
}

// MARK: - Serialisable representation used for persistence

struct ClipboardItem: Identifiable {
    let id: UUID
    let timestamp: Date
    var isPinned: Bool
    let content: ClipboardContent

    // Rich text (RTF) stored separately so we can restore exact formatting
    let attributedString: NSAttributedString?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        isPinned: Bool = false,
        content: ClipboardContent,
        attributedString: NSAttributedString? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.isPinned = isPinned
        self.content = content
        self.attributedString = attributedString
    }

    // MARK: Helpers

    /// Short text used in list previews.
    var previewText: String {
        switch content {
        case .text(let s):
            return s.trimmingCharacters(in: .whitespacesAndNewlines)
        case .image:
            return "Image"
        case .fileURLs(let urls):
            if urls.count == 1 {
                return urls[0].lastPathComponent
            }
            return "\(urls.count) files"
        case .unknown:
            return "Unknown content"
        }
    }

    var isText: Bool {
        if case .text = content { return true }
        return false
    }

    var isImage: Bool {
        if case .image = content { return true }
        return false
    }

    var nsImage: NSImage? {
        if case .image(let img) = content { return img }
        return nil
    }

    /// Human-readable relative time stamp ("Just now", "5 min ago", …)
    var relativeTime: String {
        let interval = -timestamp.timeIntervalSinceNow
        switch interval {
        case ..<5:      return "Just now"
        case ..<60:     return "\(Int(interval))s ago"
        case ..<3600:   return "\(Int(interval / 60))m ago"
        case ..<86400:  return "\(Int(interval / 3600))h ago"
        default:        return "\(Int(interval / 86400))d ago"
        }
    }
}
