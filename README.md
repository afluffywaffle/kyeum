# Kyeum

> *ceum* — Scottish Gaelic for "step, footstep, pace"

A lightweight macOS 14+ menu bar utility that surfaces your recently visited Finder folders for instant keyboard-driven access.

---

## What it does

Every time you navigate to a folder in Finder, Kyeum remembers it. Open the menu from the menu bar (or with a global hotkey) and jump straight back — no Finder window hunting, no Spotlight query. Number keys open recent folders; ⌘-number keys open your starred favorites.

## Features

- **Recent folders** pulled directly from Finder navigation history (`FXRecentFolders`)
- **Star any folder** as a Favorite — click ☆ on any item in the menu; it pins without closing the menu
- **Keyboard shortcuts** — press `1`–`9` to open recent folders, `⌘1`–`⌘4` for favorites
- **Global hotkey** — open the menu from any app (default `⌥F`; fully configurable)
- **Left/right-hand shortcuts** — switch favorite shortcuts between `⌘1–4` and `⌘8–9–0–⌘−`
- **Compact or detail mode** — show folder paths below names, or keep the menu narrow
- **Path tooltips** — hover any item to see the full untruncated path
- **Limit to home folder** — filter out system and application-internal paths
- **Manual pin by path** — type any `~/` path in Settings to pin a folder that isn't in your recents
- No Dock icon, no menu bar clutter beyond a single clock symbol

## Screenshots

<!-- Add screenshots here -->

## Requirements

- macOS 14 (Sonoma) or later
- No Accessibility permission required

## Installation

Kyeum is distributed as a direct-download app (not on the Mac App Store).

### Build from source

1. Clone the repo:
   ```bash
   git clone https://github.com/afluffywaffle/kyeum.git
   cd kyeum
   ```
2. Open `Kyeum.xcodeproj` in Xcode 15 or later
3. Set the scheme's build configuration to **Release** (Edit Scheme → Run → Build Configuration)
4. **⌘B** to build
5. In the Project navigator, right-click **Kyeum.app** under Products → **Show in Finder**
6. Drag `Kyeum.app` to `/Applications`

### First launch

Kyeum is not notarized, so Gatekeeper will block it on first run. To open it:

1. Right-click `Kyeum.app` in Finder → **Open**
2. Click **Open** in the warning dialog

You only need to do this once. After that it launches normally.

To remove the quarantine flag instead:
```bash
xattr -dr com.apple.quarantine /Applications/Kyeum.app
```

## Usage

### Menu

| Action | How |
|--------|-----|
| Open menu | Click the clock icon in the menu bar |
| Open menu (anywhere) | Press the global hotkey (default `⌥F`) |
| Open a recent folder | Press its number key (`1`–`9`) or click it |
| Open a favorite | Press `⌘1`–`⌘4` or click it |
| Star / unstar a folder | Click `☆` / `★` on the right side of any item |

### Settings

Open via the menu → **Settings…** (`⌘,`)

| Setting | Description |
|---------|-------------|
| **Show** (slider) | Number of recent folders to display (1–9) |
| **Limit to home folder** | Hides folders outside `~/`, except iCloud Drive |
| **Show pathnames** | Toggle between detail (with path) and compact (name only) mode |
| **Max favorites** | Maximum number of starred favorites (1–4) |
| **Right-hand shortcuts** | Switches favorite shortcuts to `⌘8 ⌘9 ⌘0 ⌘−` |
| **Launch at login** | Start Kyeum automatically when you log in |
| **Open Kyeum** hotkey | Record a new global hotkey |
| **Add path…** | Manually pin any folder by typing its path (`~/` supported) |

## Architecture

See [CLAUDE.md](CLAUDE.md) for a full architecture reference, key decisions, and build instructions used during development.

| File | Responsibility |
|------|---------------|
| `KyeumApp.swift` | `@main`, `AppDelegate`, singleton wiring |
| `MenuBarManager.swift` | `NSStatusItem`, `NSMenu` lifecycle, custom `FolderItemView` |
| `RecentFoldersProvider.swift` | Reads `FXRecentFolders` bookmarks, `RecentMoveAndCopyDestinations`, deduplicates |
| `PinnedFoldersStore.swift` | Favorites CRUD, `UserDefaults` persistence |
| `GlobalHotkeyManager.swift` | Carbon `RegisterEventHotKey`, user-configurable key + modifiers |
| `FolderItem.swift` | Value type: `url`, `name`, `truncatedPath` |
| `SettingsView.swift` | SwiftUI settings window |

## Notes

- Uses `FXRecentFolders` (Finder navigation history), not `NSNavRecentPlaces` (open/save panel). The latter is typically empty on machines that use iCloud-aware open dialogs.
- The `shared-preference.read-only` entitlement for `com.apple.finder` is required to read Finder's preferences from the sandbox. This entitlement is approved for notarized direct-distribution apps but is **not** allowed on the Mac App Store.
- The global hotkey uses Carbon's `RegisterEventHotKey` rather than `NSEvent.addGlobalMonitorForEvents` — this means no Accessibility permission is needed, and the keystroke is consumed (no character is typed in the focused app).

## License

MIT — see [LICENSE](LICENSE)
