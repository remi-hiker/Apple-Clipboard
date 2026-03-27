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

    // Onboarding window (shown once on first launch)
    private var onboardingWindow: NSWindow?

    private static let onboardingKey = "onboardingComplete"

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

        if !UserDefaults.standard.bool(forKey: Self.onboardingKey) {
            showOnboarding()
        }
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
                self?.pasteAndHide()
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

    /// Called when the user selects a clipboard item: hides the panel, restores
    /// focus to the previous app, then simulates ⌘V once focus has transferred.
    private func pasteAndHide() {
        panel?.orderOut(nil)
        let app = previousApp
        previousApp = nil
        app?.activate(options: .activateIgnoringOtherApps)
        // Delay is relative to the activate call so ⌘V lands after focus transfers.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            ClipboardStore.simulatePaste()
        }
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

    // MARK: - Onboarding

    private func showOnboarding() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()

        let rootView = OnboardingView { [weak self, weak window] in
            UserDefaults.standard.set(true, forKey: Self.onboardingKey)
            window?.close()
            self?.onboardingWindow = nil
        }
        window.contentView = NSHostingView(rootView: rootView)
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - NSWindowDelegate (close panel when it loses focus)

extension AppDelegate: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        hidePanel()
    }
}
