import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var pinsStore: PinnedFoldersStore
    let recents: [FolderItem]
    var onDismiss: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            if !pinsStore.pins.isEmpty {
                sectionHeader("Pinned")
                ForEach(Array(pinsStore.pins.enumerated()), id: \.element) { i, url in
                    let item = FolderItem(url: url)
                    FolderRowView(
                        item: item,
                        badge: "⌘\(i + 1)",
                        isPinned: true,
                        onOpen: { open(url); onDismiss() },
                        onTogglePin: { pinsStore.unpin(url) }
                    )
                }
                Divider().padding(.vertical, 4)
            }

            let filteredRecents = recents.filter { !pinsStore.isPinned($0.url) }
            sectionHeader("Recent")
            if filteredRecents.isEmpty {
                Text("No recent folders")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(filteredRecents.enumerated()), id: \.element) { i, item in
                    FolderRowView(
                        item: item,
                        badge: "\(i + 1)",
                        isPinned: false,
                        onOpen: { open(item.url); onDismiss() },
                        onTogglePin: { pinsStore.pin(item.url) }
                    )
                }
            }
        }
        .onKeyPress { handleKey($0) }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard let ch = press.characters.first, let digit = ch.wholeNumberValue, digit >= 1 else {
            return .ignored
        }
        if press.modifiers == [] {
            let filtered = recents.filter { !pinsStore.isPinned($0.url) }
            if digit <= filtered.count {
                open(filtered[digit - 1].url)
                onDismiss()
                return .handled
            }
        } else if press.modifiers == .command {
            if digit <= pinsStore.pins.count {
                open(pinsStore.pins[digit - 1])
                onDismiss()
                return .handled
            }
        }
        return .ignored
    }
}
