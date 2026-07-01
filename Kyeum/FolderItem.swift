import Foundation

struct FolderItem: Identifiable, Hashable {
    let url: URL
    // Finder-provided display name (e.g. "iCloud Drive"); falls back to last path component
    var name: String

    var id: URL { url }

    var displayName: String { name }

    var truncatedPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return url.path.replacingOccurrences(of: home, with: "~")
    }

    init(url: URL, name: String? = nil) {
        self.url = url
        self.name = name ?? FileManager.default.displayName(atPath: url.path)
    }
}
