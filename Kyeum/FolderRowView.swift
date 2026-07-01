import SwiftUI

struct FolderRowView: View {
    let item: FolderItem
    let badge: String
    let isPinned: Bool
    var onOpen: () -> Void
    var onTogglePin: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Text(badge)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(1)
                Text(item.truncatedPath)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered {
                Button(action: onTogglePin) {
                    Image(systemName: isPinned ? "pin.slash" : "pin")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onOpen)
    }
}
