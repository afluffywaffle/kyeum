import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var pinsStore: PinnedFoldersStore
    @AppStorage("recentCount")       private var recentCount     = 9
    @AppStorage("maxFavorites")      private var maxFavorites    = 4
    @AppStorage("limitToHomeFolder") private var limitHome       = true
    @AppStorage("showPathnames")     private var showPathnames   = true
    @AppStorage("pinRightHand")      private var pinRightHand    = false
    @AppStorage("launchAtLogin")     private var launchAtLogin   = false

    @State private var isRecordingHotkey = false
    @State private var newPinPath = ""
    @State private var pinError   = false

    private var pinKeys: [String] {
        pinRightHand ? ["⌘8","⌘9","⌘0","⌘−"] : ["⌘1","⌘2","⌘3","⌘4"]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Row 1: Recents | Favorites ──────────────────────────────
            HStack(alignment: .top, spacing: 0) {
                // Recents column
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Recents")
                    CountSlider(label: "Show", value: $recentCount, range: 1...9)
                    Toggle("Limit to home folder", isOn: $limitHome)
                    Toggle("Show pathnames", isOn: $showPathnames)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)

                Divider()

                // Favorites column
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Favorites")
                    CountSlider(label: "Max", value: $maxFavorites, range: 1...4)
                    Toggle("Right-hand  (⌘8  ⌘9  ⌘0  ⌘−)", isOn: $pinRightHand)
                        .fixedSize()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }

            Divider()

            // ── Row 2: Favorites list ────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                if pinsStore.pins.isEmpty {
                    Text("No favorites yet — hover over a folder in the menu and click ☆")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(pinsStore.pins.prefix(maxFavorites).enumerated()), id: \.element) { i, url in
                        HStack(spacing: 6) {
                            Text(pinKeys[i])
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .leading)
                            Image(systemName: "star.fill")
                                .imageScale(.small)
                                .foregroundStyle(.yellow)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(FileManager.default.displayName(atPath: url.path))
                                    .font(.callout)
                                Text(url.path.replacingOccurrences(
                                    of: RecentFoldersProvider.realHome.path, with: "~"))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Button("Remove") { pinsStore.unpin(url) }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .font(.callout)
                        }
                    }
                }

                HStack(spacing: 6) {
                    TextField("Add path…", text: $newPinPath)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addPin() }
                    Button("Add") { addPin() }
                        .disabled(newPinPath.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if pinError {
                    Text(pinsStore.pins.count >= maxFavorites
                         ? "Maximum \(maxFavorites) favorites"
                         : "Path not found or not a folder")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(14)

            Divider()

            // ── Row 3: Startup + Hotkey ──────────────────────────────────
            HStack(spacing: 20) {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() }
                            else       { try SMAppService.mainApp.unregister() }
                        } catch { launchAtLogin = !enabled }
                    }
                Spacer()
                HStack(spacing: 6) {
                    Text("Open Kyeum")
                        .foregroundStyle(.secondary)
                    Button(isRecordingHotkey ? "Press a key…" : hotkeyDisplayString()) {
                        isRecordingHotkey = true
                    }
                    .buttonStyle(.bordered)
                    .background(
                        KeyCaptureView(isActive: $isRecordingHotkey) { key, mods in
                            UserDefaults.standard.set(key, forKey: "hotkeyKey")
                            UserDefaults.standard.set(Int(mods.rawValue), forKey: "hotkeyModifiers")
                        }
                    )
                }
            }
            .padding(14)
        }
        .frame(width: 480)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func addPin() {
        let path = newPinPath.trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return }
        let expanded = path.hasPrefix("~")
            ? FileManager.default.homeDirectoryForCurrentUser.path + path.dropFirst()
            : path
        if pinsStore.pin(path: expanded) {
            newPinPath = ""
            pinError = false
        } else {
            pinError = true
        }
    }

    private func hotkeyDisplayString() -> String {
        let raw = UserDefaults.standard.integer(forKey: "hotkeyModifiers")
        let mods = raw == 0
            ? NSEvent.ModifierFlags.option
            : NSEvent.ModifierFlags(rawValue: UInt(raw))
        let key = UserDefaults.standard.string(forKey: "hotkeyKey") ?? "f"
        var r = ""
        if mods.contains(.control) { r += "⌃" }
        if mods.contains(.option)  { r += "⌥" }
        if mods.contains(.shift)   { r += "⇧" }
        if mods.contains(.command) { r += "⌘" }
        r += key.uppercased()
        return r
    }
}

// MARK: - Reusable aligned slider + text field

private struct CountSlider: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    @State private var fieldText = ""

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .frame(minWidth: 36, alignment: .leading)
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0.rounded()) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
            TextField("", text: $fieldText)
                .frame(width: 32)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .onAppear { fieldText = "\(value)" }
                .onChange(of: value) { _, v in fieldText = "\(v)" }
                .onSubmit { commit() }
                .onExitCommand { fieldText = "\(value)" }
        }
    }

    private func commit() {
        guard let n = Int(fieldText), range.contains(n) else { fieldText = "\(value)"; return }
        value = n
    }
}

// MARK: - Key capture view

private struct KeyCaptureView: NSViewRepresentable {
    @Binding var isActive: Bool
    var onCapture: (String, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> CaptureView { CaptureView(isActive: $isActive, onCapture: onCapture) }
    func updateNSView(_ v: CaptureView, context: Context) {
        if isActive { v.window?.makeFirstResponder(v) }
    }

    final class CaptureView: NSView {
        private var isActiveBinding: Binding<Bool>
        var onCapture: (String, NSEvent.ModifierFlags) -> Void
        init(isActive: Binding<Bool>, onCapture: @escaping (String, NSEvent.ModifierFlags) -> Void) {
            self.isActiveBinding = isActive; self.onCapture = onCapture
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            guard isActiveBinding.wrappedValue,
                  let chars = event.charactersIgnoringModifiers?.lowercased(),
                  !chars.isEmpty else { super.keyDown(with: event); return }
            onCapture(chars, event.modifierFlags.intersection([.command,.option,.control,.shift]))
            isActiveBinding.wrappedValue = false
        }
    }
}
