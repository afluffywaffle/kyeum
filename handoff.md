# Handoff — 2026-06-28 (session 2)

## Next session prompt

```
We're continuing work on Kyeum — a macOS 14+ menu bar utility at /Users/jayromacorda/Develop/Kyeum/. Read handoff.md and CLAUDE.md before doing anything.

The app is in a shippable state. Check if there are any remaining polish items or bugs before notarizing.
```

---

## What was done this session

### Bug fixes
- **FXRecentFolders bookmark resolution**: confirmed working via RunCodeSnippet. `shared-preference.read-only` entitlement for `com.apple.finder` is functional.
- **Canned search / package filter**: `looksLikeFolder()` now filters `.cannedSearch` and other known bundle extensions by path extension — no filesystem access needed (avoids TCC prompts).
- **Display names**: `FileManager.default.displayName(atPath:)` used everywhere as fallback, giving "iCloud Drive" instead of "com~apple~CloudDocs".
- **iCloud permission dialog**: `.withoutUI` added to `URL(resolvingBookmarkData:)` to suppress TCC prompts during menu build.
- **Home folder filter bug (sandbox)**: `FileManager.default.homeDirectoryForCurrentUser` returns the sandbox container path in a sandboxed app, not the real home. Fixed everywhere by using `NSHomeDirectoryForUser(NSUserName())` via `RecentFoldersProvider.realHome`.
- **Home directory itself in recents**: added `path != homePath` guard to `isUserFacing` to exclude the home root.
- **Duplicate favorites**: pin/unpin/isPinned all now compare via `url.resolvingSymlinksInPath().path` — handles `/Users` → `/private/Users` symlink mismatch between bookmark-resolved and file-path URLs. `load()` deduplicates stored pins on launch.
- **Limit to home folder now applies to favorites too**: same `isUserFacing` filter applied in `buildMenu` before displaying pinned items.
- **First-click menu stutter**: `menuWillOpen` was using `Task { @MainActor in }` (async) causing NSMenu to start rendering stale item objects. Fixed with `MainActor.assumeIsolated` (synchronous). Menu also pre-populated in `setupStatusItem()`.

### New features
- **Star-based favorites**: submenus removed; each folder item now has a `☆`/`★` button in a custom `FolderItemView`. Clicking the star pins/unpins without dismissing the menu. Clicking the folder name opens it and closes the menu.
- **Favorites limit (1–4)**: replaces old 9-pin limit. New `maxFavorites` UserDefaults key.
- **Handedness setting**: `pinRightHand` toggle switches pin shortcuts between ⌘1–4 (left) and ⌘8-9-0-− (right).
- **Show pathnames toggle**: compact vs detail mode. In compact mode, paths hidden; tooltip always shows full path on hover.
- **Path truncation**: menu paths truncated to ~38 chars (middle-truncation) to keep menu narrow.
- **Path tooltips**: `NSMenuItem.toolTip` + `NSView.toolTip` both set to full `~/…` path so hovering any item shows the untruncated path.
- **Global hotkey**: switched from `NSEvent.addGlobalMonitorForEvents` to Carbon `RegisterEventHotKey`. No Accessibility permission needed. Event is consumed (no character typed in active app).
- **Settings redesign**: 2-column layout (Recents | Favorites side-by-side), steppers replaced with `Slider + TextField` combos, no scrollbar.
- **Manual pin by path**: text field + Add button in Settings Favorites section. Accepts `~/` paths, validates directory, shows inline error.
- **App icon**: purple/violet gradient, custom-drawn CGPath footprint (ceum = step/footstep). Generator script at `/tmp/gen_icon2.swift`.

## Architecture additions

| Key | Default | Notes |
|-----|---------|-------|
| `maxFavorites` | 4 | 1–4; ceiling for pin count |
| `showPathnames` | true | compact vs detail menu mode |
| `pinRightHand` | false | ⌘1-4 vs ⌘8-9-0-− for favorites |

`RecentFoldersProvider.realHome` — static property, use this everywhere instead of `FileManager.default.homeDirectoryForCurrentUser` in a sandboxed context.

## What still needs doing

1. **Visual testing of star toggle while menu is open** — `rebuildMenu()` fires when pins change, replacing all views in-place. Visually smooth but worth confirming on the actual app.
2. **Notarization** — ready for direct distribution. Entitlements in place: `app-sandbox`, `user-selected.read-write`, `home-relative-path.read-write`, `shared-preference.read-only` for Finder.
3. **Settings window height** — window is hardcoded at 380px. If favorites list grows (many pins), it may need to grow dynamically.
4. **`build` directory in recents** — iCloud project build folders (e.g. `~/Library/Mobile Documents/.../build`) pass the filter since they're under Mobile Documents. Could add a "build" directory heuristic if the user finds it noisy.
5. **App icon refinement** — footprint design is functional; can be tweaked in `/tmp/gen_icon2.swift` (just edit and re-run with `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift /tmp/gen_icon2.swift`).
