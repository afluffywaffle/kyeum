import Foundation

final class RecentFoldersProvider {
    func fetch(count: Int, limitToHomeFolder: Bool = false) -> [FolderItem] {
        var items: [FolderItem] = []
        var seen = Set<URL>()
        let home = Self.realHome

        func add(_ item: FolderItem) {
            guard items.count < count,
                  !seen.contains(item.url),
                  looksLikeFolder(item.url) else { return }
            if limitToHomeFolder && !isUserFacing(item.url, home: home) { return }
            seen.insert(item.url)
            items.append(item)
        }

        for item in fxRecentFolders() { add(item) }
        for item in recentMoveDestinations() { add(item) }
        for item in navRecentPlaces() { add(item) }

        return items
    }

    // Finder sidebar recent folders (bookmark data + display name)
    private func fxRecentFolders() -> [FolderItem] {
        guard let entries = finderPlistValue(forKey: "FXRecentFolders") as? [[String: Any]] else {
            return []
        }
        return entries.compactMap { entry -> FolderItem? in
            guard let bookmarkData = entry["file-bookmark"] as? Data else { return nil }
            let name = entry["name"] as? String
            var isStale = false
            // .withoutUI prevents any TCC prompt during bookmark resolution
            guard let url = try? URL(resolvingBookmarkData: bookmarkData,
                                     options: [.withoutUI],
                                     relativeTo: nil,
                                     bookmarkDataIsStale: &isStale) else { return nil }
            return FolderItem(url: url, name: name)
        }
    }

    // Recent move/copy destinations (file:// URL strings)
    private func recentMoveDestinations() -> [FolderItem] {
        guard let paths = finderPlistValue(forKey: "RecentMoveAndCopyDestinations") as? [String] else {
            return []
        }
        return paths.compactMap { str -> FolderItem? in
            guard let url = URL(string: str) else { return nil }
            return FolderItem(url: url.standardized)
        }
    }

    // Open/save panel recent places (string paths)
    private func navRecentPlaces() -> [FolderItem] {
        guard let paths = finderPlistValue(forKey: "NSNavRecentPlaces") as? [String] else {
            return []
        }
        return paths.map { FolderItem(url: URL(filePath: $0)) }
    }

    // Try UserDefaults suite first, then read the plist file directly
    private func finderPlistValue(forKey key: String) -> Any? {
        if let value = UserDefaults(suiteName: "com.apple.finder")?.object(forKey: key) {
            return value
        }
        return cachedFinderPlist?[key]
    }

    private var cachedFinderPlist: [String: Any]? {
        let plistURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.finder.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return plist
    }

    // Avoids any filesystem access (no TCC prompt during menu build).
    // Filters known bundle/package extensions and paths inside .app bundles.
    private func looksLikeFolder(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let bundleExts: Set<String> = [
            "app", "bundle", "framework", "plugin", "kext",
            "cannedsearch", "savedsearch", "workflow", "action", "prefpane"
        ]
        if bundleExts.contains(ext) { return false }
        if url.path.contains(".app/Contents") { return false }
        return true
    }

    // Paths inside ~/Library/ (app containers, caches, etc.) are excluded unless they
    // are under ~/Library/Mobile Documents/ which is the iCloud Drive mount point.
    // FileManager.homeDirectoryForCurrentUser returns the sandbox container in a
    // sandboxed app, not the real user home. NSHomeDirectoryForUser gives the real path.
    static var realHome: URL {
        URL(filePath: NSHomeDirectoryForUser(NSUserName()) ?? NSHomeDirectory())
    }

    private func isUserFacing(_ url: URL, home: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().path
        let homePath = home.resolvingSymlinksInPath().path
        guard path.hasPrefix(homePath), path != homePath else { return false }
        let relative = String(path.dropFirst(homePath.count))
        return !relative.hasPrefix("/Library/") || relative.hasPrefix("/Library/Mobile Documents/")
    }
}
