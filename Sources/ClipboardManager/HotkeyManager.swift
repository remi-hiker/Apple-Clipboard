import Carbon.HIToolbox
import Foundation

/// Registers the global hotkey ⌘⇧: (Cmd+Shift+Semicolon) using the Carbon
/// Event Manager and fires a callback whenever it is pressed.
///
/// Why Carbon?  NSEvent global monitors require the app to be frontmost for
/// modifier-key events; Carbon `RegisterEventHotKey` works app-wide.
final class HotkeyManager {

    static let shared = HotkeyManager()

    /// Called on the main thread when the hotkey is pressed.
    var onActivate: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    // MARK: - Registration

    func register() {
        // Install a Carbon event handler that fires on kEventHotKeyPressed.
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, inEvent, userData) -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(userData)
                    .takeUnretainedValue()
                DispatchQueue.main.async { mgr.onActivate?() }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        // ⌘⇧; — On US keyboards colon (:) is produced by Shift+Semicolon.
        // Registering Cmd+Shift+Semicolon therefore captures ⌘⇧:.
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = fourCharCode("CLPM")
        hotKeyID.id = 1

        RegisterEventHotKey(
            UInt32(kVK_ANSI_Semicolon),      // physical key: semicolon / colon
            UInt32(cmdKey | shiftKey),        // ⌘ + ⇧
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
    }

    // MARK: - Utility

    /// Convert a 4-character ASCII string to a `FourCharCode`.
    private func fourCharCode(_ s: String) -> FourCharCode {
        var code: FourCharCode = 0
        for byte in s.utf8.prefix(4) {
            code = (code << 8) | FourCharCode(byte)
        }
        return code
    }
}
