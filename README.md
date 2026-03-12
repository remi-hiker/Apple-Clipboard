# Clipboard Manager for macOS

A macOS clipboard history manager that mirrors the Windows clipboard (⊞+V)
experience.  Press **⌘⇧:** (Cmd + Shift + Colon) anywhere to open a floating
panel showing your last 25 copied items, then click any entry to instantly
paste it.

## Features

| Feature | Details |
|---------|---------|
| **Global hotkey** | ⌘⇧: — toggle the history panel from any app |
| **History depth** | Up to 25 recent items (same as Windows) |
| **Content types** | Plain text, rich text (RTF), images, file URLs |
| **Pin items** | Keep important clips permanently at the top |
| **Search** | Filter history in real time |
| **One-click paste** | Selects item, writes it to clipboard, simulates ⌘V |
| **Right-click menu** | Pin / Unpin, Delete |
| **Clear all** | Removes unpinned items; pinned items stay |
| **Menu-bar icon** | Click the clipboard icon in the menu bar to toggle |
| **No Dock icon** | Runs as a background/accessory app |
| **Blurred background** | Native macOS vibrancy (light & dark mode) |

## Requirements

- macOS 13 Ventura or later
- Xcode Command Line Tools **or** a full Xcode installation
- Accessibility permission (prompted on first launch)

## Building

```bash
# 1. Clone the repo
git clone https://github.com/yourname/Apple-Clipboard.git
cd Apple-Clipboard

# 2. Build the .app bundle and ad-hoc sign it
make sign

# 3a. Run directly from the project folder
make run

# 3b. Or install to /Applications
make install
```

> **Tip:** run `make` (without arguments) to just build the bundle without
> signing or installing.

### Makefile targets

| Target | Description |
|--------|-------------|
| `make build` | Compile via Swift Package Manager (release) |
| `make app` | Assemble the `.app` bundle |
| `make sign` | Ad-hoc sign the bundle (required to run) |
| `make install` | Sign + copy to `/Applications` |
| `make run` | Sign + `open` the app immediately |
| `make clean` | Delete build artifacts |

## Granting Accessibility Access

The app simulates ⌘V via `CGEvent` to paste the selected item into whatever
app was previously active.  macOS requires **Accessibility** permission for
this.

1. On first launch you will be shown an alert with a direct link.
2. Or navigate to: **System Settings → Privacy & Security → Accessibility**
3. Toggle **Clipboard Manager** on.
4. Relaunch the app if needed.

## How it works

```
NSPasteboard  ──poll every 0.5 s──▶  ClipboardMonitor
                                           │
                                           ▼
                                     ClipboardStore   (ObservableObject)
                                           │
                          ┌────────────────┴──────────────────┐
                          ▼                                    ▼
                  ClipboardHistoryView                   HotkeyManager
                  (SwiftUI + NSPanel)                 (Carbon RegisterEventHotKey)
                          │
                   click item
                          │
                          ▼
                  NSPasteboard.write()
                  + CGEvent(⌘V)  ──▶  previously active app
```

## Project structure

```
Apple-Clipboard/
├── Package.swift                          Swift Package Manager manifest
├── Makefile                               Build, sign, install helpers
├── Resources/
│   ├── Info.plist                         App bundle metadata
│   └── ClipboardManager.entitlements      Required entitlements
└── Sources/ClipboardManager/
    ├── main.swift                         Entry point
    ├── AppDelegate.swift                  Window management, status-bar icon
    ├── ClipboardItem.swift                Data model
    ├── ClipboardStore.swift               History store (ObservableObject)
    ├── ClipboardMonitor.swift             NSPasteboard polling
    ├── HotkeyManager.swift                Carbon global hotkey (⌘⇧:)
    ├── VisualEffectView.swift             NSVisualEffectView SwiftUI wrapper
    ├── ClipboardHistoryView.swift         Main SwiftUI panel
    └── ClipboardItemView.swift            Individual item row
```

## Hotkey reference

| Keys | Action |
|------|--------|
| ⌘⇧: | Open / close clipboard history |
| Click item | Paste item and close panel |
| Esc | Close panel without pasting |
| Right-click item | Pin / Unpin, Delete |

## Privacy

All clipboard data stays **100 % local** on your machine.  Nothing is
transmitted over the network.  History is held in memory only and cleared
when the app quits.

## License

MIT — see [LICENSE](LICENSE).
