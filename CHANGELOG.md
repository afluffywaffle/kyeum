# Changelog

All notable changes to Kyeum will be documented here.

## [0.1.0] — 2026-06-28

### Added
- Menu bar utility with clock icon; no Dock icon
- Recent folders from Finder navigation history (`FXRecentFolders`)
- Number keys `1`–`9` open recent folders directly
- Star-based favorites — click ☆ in the menu to pin a folder without closing it
- Favorite keyboard shortcuts: `⌘1`–`⌘4` (left-hand) or `⌘8`–`⌘−` (right-hand)
- Global hotkey via Carbon `RegisterEventHotKey` (default `⌥F`) — no Accessibility permission needed, no character typed in focused app
- "Limit to home folder" filter — excludes `~/Library/` internals, keeps iCloud Drive
- Compact / detail view toggle for folder paths
- Path tooltip on hover for truncated or hidden paths
- Manual pin by path in Settings (`~/` paths accepted)
- Settings: Recent count slider, max favorites slider, handedness toggle, launch at login, hotkey recorder
- Sandbox with `shared-preference.read-only` entitlement for Finder prefs
- App icon: indigo–violet gradient with footprint (ceum = step)
