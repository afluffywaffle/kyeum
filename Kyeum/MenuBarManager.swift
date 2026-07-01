import AppKit
import SwiftUI
import Combine

@MainActor
final class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem!
    private let provider = RecentFoldersProvider()
    let pinsStore: PinnedFoldersStore
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    private static let leftHandKeys:  [String] = ["1","2","3","4"]
    private static let rightHandKeys: [String] = ["8","9","0","-"]

    init(pinsStore: PinnedFoldersStore) {
        self.pinsStore = pinsStore
        super.init()
        setupStatusItem()
        pinsStore.$pins
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Kyeum")
            button.image?.isTemplate = true
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        buildMenu(into: menu)
    }

    func toggleMenu() {
        statusItem.button?.performClick(nil)
    }

    private func rebuildMenu() {
        guard let menu = statusItem.menu else { return }
        buildMenu(into: menu)
    }

    private func buildMenu(into menu: NSMenu) {
        menu.removeAllItems()

        let recentCount  = max(1, min(9, UserDefaults.standard.integer(forKey: "recentCount").nonZero ?? 9))
        let maxFavs      = max(1, min(4, UserDefaults.standard.integer(forKey: "maxFavorites").nonZero ?? 4))
        let limitHome    = UserDefaults.standard.bool(forKey: "limitToHomeFolder")
        let showPaths    = UserDefaults.standard.object(forKey: "showPathnames") as? Bool ?? true
        let rightHand    = UserDefaults.standard.bool(forKey: "pinRightHand")
        let pinKeys      = rightHand ? MenuBarManager.rightHandKeys : MenuBarManager.leftHandKeys

        let home    = RecentFoldersProvider.realHome
        let recents = provider.fetch(count: recentCount, limitToHomeFolder: limitHome)
        let pins    = Array(
            pinsStore.pins
                .filter { !limitHome || isUserFacing($0, home: home) }
                .prefix(maxFavs)
        )

        // Favorites
        if !pins.isEmpty {
            menu.addItem(sectionHeader("Favorites"))
            for (i, url) in pins.enumerated() {
                let key = pinKeys[i]
                menu.addItem(folderItem(url: url, badge: "⌘\(key)", isPinned: true,
                                       keyEq: key, mods: .command, showPaths: showPaths))
            }
            menu.addItem(.separator())
        }

        // Recents
        menu.addItem(sectionHeader("Recent"))
        let filteredRecents = recents.filter { !pinsStore.isPinned($0.url) }

        if filteredRecents.isEmpty {
            let empty = NSMenuItem(title: "No recent folders", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for (i, item) in filteredRecents.enumerated() {
                menu.addItem(folderItem(url: item.url, name: item.name, badge: "\(i + 1)",
                                       isPinned: false, keyEq: "\(i + 1)", mods: [],
                                       showPaths: showPaths))
            }
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit Kyeum", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)
    }

    private func sectionHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(
            string: title.uppercased(),
            attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        return item
    }

    private func folderItem(url: URL, name: String? = nil, badge: String, isPinned: Bool,
                            keyEq: String, mods: NSEvent.ModifierFlags,
                            showPaths: Bool) -> NSMenuItem {
        let item = NSMenuItem()
        // action + keyEquivalent: keyboard shortcuts still work even with a custom view
        item.action = #selector(openFolder(_:))
        item.target = self
        item.representedObject = url
        item.keyEquivalent = keyEq
        item.keyEquivalentModifierMask = mods

        let displayName = name ?? FileManager.default.displayName(atPath: url.path)
        let rawPath = url.path.replacingOccurrences(of: RecentFoldersProvider.realHome.path, with: "~")

        let view = FolderItemView(
            badge: badge,
            name: displayName,
            path: showPaths ? truncatedPath(rawPath) : nil,
            isFavorite: isPinned
        )
        view.assignedKey = keyEq
        view.assignedModifiers = mods
        view.openHandler = { [weak self] in
            NSWorkspace.shared.open(url)
            self?.statusItem.menu?.cancelTracking()
        }
        view.starHandler = { [weak self] in
            guard let self else { return }
            if isPinned { pinsStore.unpin(url) } else { pinsStore.pin(url) }
        }
        // Show the full path as a native tooltip on hover (covers truncated paths and compact mode)
        view.toolTip = rawPath
        item.toolTip  = rawPath
        item.view = view
        return item
    }

    private func isUserFacing(_ url: URL, home: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().path
        let homePath = home.resolvingSymlinksInPath().path
        guard path.hasPrefix(homePath), path != homePath else { return false }
        let relative = String(path.dropFirst(homePath.count))
        return !relative.hasPrefix("/Library/") || relative.hasPrefix("/Library/Mobile Documents/")
    }

    private func truncatedPath(_ path: String, maxLen: Int = 38) -> String {
        guard path.count > maxLen else { return path }
        let half = (maxLen - 1) / 2
        return String(path.prefix(half)) + "…" + String(path.suffix(half))
    }

    @objc private func openFolder(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func openSettings() {
        if let win = settingsWindow, win.isVisible {
            win.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Kyeum Settings"
        win.center()
        win.contentView = NSHostingView(rootView: SettingsView(pinsStore: pinsStore))
        win.isReleasedWhenClosed = false
        settingsWindow = win
        win.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension MenuBarManager: NSMenuDelegate {
    nonisolated func menuWillOpen(_ menu: NSMenu) {
        MainActor.assumeIsolated { buildMenu(into: menu) }
    }
}

// MARK: - Custom folder menu item view

private final class FolderItemView: NSView {
    private let badgeLabel = NSTextField(labelWithString: "")
    private let nameLabel  = NSTextField(labelWithString: "")
    private let pathLabel  = NSTextField(labelWithString: "")
    private let starBtn    = NSButton()
    private var isFavorite: Bool

    var openHandler: (() -> Void)?
    var starHandler: (() -> Void)?
    var assignedKey: String = ""
    var assignedModifiers: NSEvent.ModifierFlags = []

    // NSMenu does not paint a selection background behind custom-view items,
    // so we own the full highlight rendering here.
    private var isHighlighted = false {
        didSet {
            needsDisplay = true
            if isHighlighted {
                nameLabel.textColor  = .selectedMenuItemTextColor
                badgeLabel.textColor = .selectedMenuItemTextColor.withAlphaComponent(0.75)
                pathLabel.textColor  = .selectedMenuItemTextColor.withAlphaComponent(0.6)
                starBtn.contentTintColor = .selectedMenuItemTextColor.withAlphaComponent(0.85)
            } else {
                nameLabel.textColor  = .labelColor
                badgeLabel.textColor = .secondaryLabelColor
                pathLabel.textColor  = .tertiaryLabelColor
                starBtn.contentTintColor = isFavorite ? .systemYellow : .tertiaryLabelColor
            }
        }
    }

    init(badge: String, name: String, path: String?, isFavorite: Bool) {
        self.isFavorite = isFavorite
        let h: CGFloat = path != nil ? 40 : 26
        super.init(frame: NSRect(x: 0, y: 0, width: 240, height: h))

        // Badge
        badgeLabel.stringValue = badge
        badgeLabel.font = .menuFont(ofSize: 11)
        badgeLabel.textColor = .secondaryLabelColor

        // Name
        nameLabel.stringValue = name
        nameLabel.font = .menuFont(ofSize: 13)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail

        // Path
        pathLabel.stringValue = path ?? ""
        pathLabel.font = .menuFont(ofSize: 10)
        pathLabel.textColor = .tertiaryLabelColor
        pathLabel.isHidden = (path == nil)

        // Star
        starBtn.image = NSImage(systemSymbolName: isFavorite ? "star.fill" : "star",
                                accessibilityDescription: isFavorite ? "Remove from favorites" : "Add to favorites")
        starBtn.contentTintColor = isFavorite ? .systemYellow : .tertiaryLabelColor
        starBtn.isBordered = false
        starBtn.imageScaling = .scaleProportionallyDown
        starBtn.imagePosition = .imageOnly
        starBtn.target = self
        starBtn.action = #selector(handleStar)

        for v in [badgeLabel, nameLabel, pathLabel, starBtn] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }

        NSLayoutConstraint.activate([
            badgeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            badgeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            badgeLabel.widthAnchor.constraint(equalToConstant: 34),

            starBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            starBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            starBtn.widthAnchor.constraint(equalToConstant: 18),
            starBtn.heightAnchor.constraint(equalToConstant: 18),

            nameLabel.leadingAnchor.constraint(equalTo: badgeLabel.trailingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: starBtn.leadingAnchor, constant: -6),
        ])

        if path != nil {
            NSLayoutConstraint.activate([
                nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),
                pathLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
                pathLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
                pathLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            ])
        } else {
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        }

        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil
        ))
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func handleStar() {
        isFavorite.toggle()
        starBtn.image = NSImage(systemSymbolName: isFavorite ? "star.fill" : "star",
                                accessibilityDescription: nil)
        starBtn.contentTintColor = isFavorite ? .systemYellow : .tertiaryLabelColor
        starHandler?()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard !assignedKey.isEmpty,
              let chars = event.charactersIgnoringModifiers?.lowercased(),
              chars == assignedKey,
              event.modifierFlags.intersection([.command, .option, .shift, .control]) == assignedModifiers
        else { return false }
        openHandler?()
        return true
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if starBtn.frame.contains(p) {
            starBtn.performClick(nil)
            // Don't call super — keeps the menu open
        } else {
            openHandler?()
            // openHandler calls cancelTracking; don't call super to avoid double-dismiss
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHighlighted {
            NSColor.selectedMenuItemColor.setFill()
            bounds.fill()
        }
        super.draw(dirtyRect)
    }

    override func mouseEntered(with event: NSEvent) { isHighlighted = true }
    override func mouseExited(with event: NSEvent)  { isHighlighted = false }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
