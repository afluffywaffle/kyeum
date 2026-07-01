# CLAUDE.md — Kyeum

Read this file at the start of every session.

---

## What Kyeum is

A lightweight macOS 14+ menu bar utility that surfaces recently visited Finder folders
for instant keyboard-driven access.

- **Name:** Kyeum — phonetic romanization of Scottish Gaelic *ceum* ("step, footstep, pace")
- **Bundle ID:** `com.afluffypancake.kyeum`
- **Distribution:** Direct (Notarization), not App Store — see sandbox note below

---

## Architecture

### Entry point

`KyeumApp.swift` — `@main` SwiftUI App with `@NSApplicationDelegateAdaptor`.
`AppDelegate` initializes the three singletons: `MenuBarManager`, `PinnedFoldersStore`,
`GlobalHotkeyManager`. The SwiftUI `Settings` scene is empty (no default windows).
`NSApp.setActivationPolicy(.accessory)` hides the app from the Dock and ⌘-Tab.

### File map

| File | Responsibility |
|------|---------------|
| `KyeumApp.swift` | @main, AppDelegate, singleton wiring |
| `MenuBarManager.swift` | NSStatusItem, NSMenu lifecycle, settings window |
| `RecentFoldersProvider.swift` | Reads NSNavRecentPlaces, deduplicates |
| `PinnedFoldersStore.swift` | Pin/unpin CRUD, UserDefaults persistence |
| `GlobalHotkeyManager.swift` | NSEvent global monitor, user-configurable key+mods |
| `FolderItem.swift` | Value type: url, displayName, truncatedPath |
| `ContentView.swift` | SwiftUI folder list (embedded in popover or standalone window) |
| `FolderRowView.swift` | Individual row: badge, name, path, hover pin button |
| `SettingsView.swift` | Count stepper, launch at login, hotkey recorder |

---

## Key decisions

### NSMenu over MenuBarExtra/NSPopover

`NSMenu` with `NSMenuItem.keyEquivalent` gives native number-key shortcuts, arrow
navigation, and immediate dismiss — all for free. `MenuBarExtra` (.window style) was
considered but has no public API to programmatically open from a global hotkey.

### NSMenuItem keyboard shortcuts

Each folder `NSMenuItem` has `.keyEquivalent` set directly:
- Recent folders: `"1"`–`"9"` with `.keyEquivalentModifierMask = []`
- Pinned folders: `"1"`–`"9"` with `.keyEquivalentModifierMask = .command`

No manual event monitoring needed inside the menu.

### NSNavRecentPlaces sandbox approach

`RecentFoldersProvider` tries `UserDefaults(suiteName: "com.apple.finder")` first,
then falls back to reading `~/Library/Preferences/com.apple.finder.plist` directly.

The entitlement required:
```xml
<key>com.apple.security.temporary-exception.shared-preference.read-only</key>
<array><string>com.apple.finder</string></array>
```

This entitlement is allowed in notarized direct-distribution apps but is rejected
by App Store review. Do not add App Store distribution without an alternative approach.

### Global hotkey

`NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` — monitor-only, no TCC prompt.
Compares `event.charactersIgnoringModifiers` + `event.modifierFlags` against stored prefs.
Default: ⌥F. Stored in `UserDefaults.standard` under keys `hotkeyKey` + `hotkeyModifiers`.

### Pinned folders

Stored as `[String]` (URL paths) in `UserDefaults.standard["pinnedFolders"]`.
Max 9 pins so `⌘1`–`⌘9` maps cleanly. `NSWorkspace.shared.open(url)` handles
opening without security-scoped bookmarks for standard user paths.

### Launch at login

`SMAppService.mainApp.register()` / `.unregister()` — no helper app, no LaunchAgent plist.
Errors silently revert the toggle.

---

## Building

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild \
  -project Kyeum.xcodeproj -scheme Kyeum -configuration Debug -sdk macosx build
```

After every change: build and confirm `BUILD SUCCEEDED`. Then run the app and:
1. Verify menu bar icon appears, no Dock icon
2. Navigate Finder to several folders, open menu — recents appear
3. Press a number key — correct folder opens in Finder
4. Right-click an item → Pin; verify it moves to Pinned section, ⌘1 opens it
5. ⌥F (or configured hotkey) opens the menu from any app

---

## UserDefaults keys (app domain)

| Key | Type | Default | Notes |
|-----|------|---------|-------|
| `recentCount` | Int | 9 | 1–9 |
| `launchAtLogin` | Bool | false | mirrors SMAppService status |
| `hotkeyKey` | String | `"f"` | single character, lowercased |
| `hotkeyModifiers` | Int | `.option.rawValue` | raw NSEvent.ModifierFlags |
| `pinnedFolders` | [String] | [] | URL paths |
