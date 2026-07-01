import Foundation
import Combine

private let kPinnedFolders = "pinnedFolders"

final class PinnedFoldersStore: ObservableObject {
    @Published private(set) var pins: [URL] = []

    init() { load() }

    func pin(_ url: URL) {
        let canonical = url.canonical
        guard !isPinned(canonical), pins.count < maxFavorites else { return }
        pins.insert(canonical, at: 0)
        save()
    }

    @discardableResult
    func pin(path: String) -> Bool {
        let url = URL(filePath: path.trimmingCharacters(in: .whitespaces)).canonical
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
              isDir.boolValue,
              !isPinned(url),
              pins.count < maxFavorites else { return false }
        pins.insert(url, at: 0)
        save()
        return true
    }

    func unpin(_ url: URL) {
        let path = url.canonical.path
        pins.removeAll { $0.canonical.path == path }
        save()
    }

    func isPinned(_ url: URL) -> Bool {
        let path = url.canonical.path
        return pins.contains { $0.canonical.path == path }
    }

    private var maxFavorites: Int {
        let v = UserDefaults.standard.integer(forKey: "maxFavorites")
        return v == 0 ? 4 : max(1, min(4, v))
    }

    private func load() {
        let paths = UserDefaults.standard.stringArray(forKey: kPinnedFolders) ?? []
        var seen = Set<String>()
        pins = paths.compactMap { path -> URL? in
            let url = URL(filePath: path).canonical
            return seen.insert(url.path).inserted ? url : nil
        }
        if pins.count != paths.count { save() }
    }

    private func save() {
        UserDefaults.standard.set(pins.map(\.path), forKey: kPinnedFolders)
    }
}

private extension URL {
    // Resolves /Users → /private/Users symlink so all comparisons use the real path.
    var canonical: URL { resolvingSymlinksInPath() }
}
