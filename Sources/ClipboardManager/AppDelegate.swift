import AppKit
import SwiftUI

// MARK: - NSPanel subclass used as the floating clipboard overlay

final class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    // Core objects
    let store   = ClipboardStore()
    var monitor: ClipboardMonitor!
    var panel:   ClipboardPanel?

    // macOS menu-bar status item
    private var statusItem: NSStatusItem?

    // The app that was active before the panel was shown; restored on hide.
    private var previousApp: NSRunningApplication?

    // MARK: - Application lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a "background" app — no Dock icon, no main window.
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPanel()

        monitor = ClipboardMonitor(store: store)
        monitor.start()

        HotkeyManager.shared.onActivate = { [weak self] in
            self?.togglePanel()
        }
        HotkeyManager.shared.register()

        checkAccessibilityPermission()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        HotkeyManager.shared.unregister()
    }

    // MARK: - Status-bar icon

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clipboard Manager")
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked)
            button.target = self
            button.toolTip = "Clipboard Manager\n⌘⇧: to toggle"
        }
    }

    @objc private func statusItemClicked() {
        togglePanel()
    }

    // MARK: - Floating panel

    private func setupPanel() {
        let style: NSWindow.StyleMask = [
            .titled,
            .fullSizeContentView,
            .nonactivatingPanel
        ]

        let newPanel = ClipboardPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
            styleMask: style,
            backing: .buffered,
            defer: false
        )

        newPanel.titlebarAppearsTransparent = true
        newPanel.titleVisibility = .hidden
        newPanel.isMovableByWindowBackground = true
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = true
        newPanel.standardWindowButton(.closeButton)?.isHidden = true
        newPanel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newPanel.standardWindowButton(.zoomButton)?.isHidden = true

        // Embed the SwiftUI view
        let hostingView = NSHostingView(
            rootView: ClipboardHistoryView(store: store) { [weak self] in
                self?.hidePanel()
            }
        )
        hostingView.frame = newPanel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        newPanel.contentView = hostingView

        panel = newPanel
    }

    // MARK: - Toggle / show / hide

    func togglePanel() {
        if panel?.isVisible == true {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        previousApp = NSWorkspace.shared.frontmostApplication
        guard let panel else { return }

        positionPanel()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hidePanel() {
        panel?.orderOut(nil)
        previousApp?.activate(options: .activateIgnoringOtherApps)
        previousApp = nil
    }

    /// Position the panel in the upper-centre of the screen that contains the
    /// mouse cursor, mirroring Windows clipboard behaviour.
    private func positionPanel() {
        guard let panel else { return }

        let screen = NSScreen.screens.first(where: {
            $0.frame.contains(NSEvent.mouseLocation)
        }) ?? NSScreen.main ?? NSScreen.screens[0]

        let screenFrame = screen.visibleFrame
        let panelSize   = panel.frame.size

        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.maxY - panelSize.height - 40   // 40 pt below menu bar

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Accessibility check

    private func checkAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            showAccessibilityAlert()
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText =
            "ClipboardManager needs Accessibility access to simulate ⌘V and paste " +
            "the selected item into the active app.\n\n" +
            "Please enable it in System Settings → Privacy & Security → Accessibility, " +
            "then relaunch the app."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            )
        }
    }
}

// MARK: - NSWindowDelegate (close panel when it loses focus)

extension AppDelegate: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        hidePanel()
    }
}
