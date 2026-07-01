import SwiftUI
import AppKit

@main
struct KyeumApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No windows — menu bar only. Empty Settings scene prevents default window.
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager: MenuBarManager?
    let pinsStore = PinnedFoldersStore()
    let hotkeyManager = GlobalHotkeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Suppress the default app menu bar (we have no window)
        NSApp.setActivationPolicy(.accessory)

        menuBarManager = MenuBarManager(pinsStore: pinsStore)

        hotkeyManager.onTrigger = { [weak self] in
            self?.menuBarManager?.toggleMenu()
        }
        hotkeyManager.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
