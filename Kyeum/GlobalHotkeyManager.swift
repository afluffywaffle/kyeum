import AppKit
import Carbon.HIToolbox

final class GlobalHotkeyManager {
    var onTrigger: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var defaultsObserver: NSObjectProtocol?

    var keyChar: String {
        get { UserDefaults.standard.string(forKey: "hotkeyKey") ?? "f" }
        set { UserDefaults.standard.set(newValue, forKey: "hotkeyKey"); restart() }
    }

    var modifiers: NSEvent.ModifierFlags {
        get {
            let raw = UserDefaults.standard.integer(forKey: "hotkeyModifiers")
            return raw == 0 ? .option : NSEvent.ModifierFlags(rawValue: UInt(raw))
        }
        set {
            UserDefaults.standard.set(Int(newValue.rawValue), forKey: "hotkeyModifiers")
            restart()
        }
    }

    func start() {
        installCarbonHandler()
        registerHotKey()
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            self?.restart()
        }
    }

    func stop() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    deinit {
        stop()
        if let observer = defaultsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
        }
    }

    // Installed once; handles all future RegisterEventHotKey registrations.
    private func installCarbonHandler() {
        guard eventHandlerRef == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let ud = userData else { return noErr }
                let mgr = Unmanaged<GlobalHotkeyManager>.fromOpaque(ud).takeUnretainedValue()
                DispatchQueue.main.async { mgr.onTrigger?() }
                return noErr
            },
            1, &spec, ptr, &eventHandlerRef
        )
    }

    private func registerHotKey() {
        stop()
        guard let keyCode = keyCodeForChar(keyChar) else { return }
        // "KYEM" as a big-endian FourCharCode
        var hkID = EventHotKeyID(signature: 0x4B59_454D, id: 1)
        RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers(modifiers),
            hkID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private func restart() { stop(); registerHotKey() }

    private func carbonModifiers(_ mods: NSEvent.ModifierFlags) -> UInt32 {
        var r: UInt32 = 0
        if mods.contains(.command) { r |= UInt32(cmdKey) }
        if mods.contains(.option)  { r |= UInt32(optionKey) }
        if mods.contains(.shift)   { r |= UInt32(shiftKey) }
        if mods.contains(.control) { r |= UInt32(controlKey) }
        return r
    }

    private func keyCodeForChar(_ char: String) -> Int? {
        let map: [String: Int] = [
            "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
            "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
            "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
            "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
            "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
            "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
            "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
            "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
            "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
            "8": kVK_ANSI_8, "9": kVK_ANSI_9,
            "-": kVK_ANSI_Minus, "=": kVK_ANSI_Equal, "[": kVK_ANSI_LeftBracket,
            "]": kVK_ANSI_RightBracket, "\\": kVK_ANSI_Backslash,
            ";": kVK_ANSI_Semicolon, "'": kVK_ANSI_Quote,
            ",": kVK_ANSI_Comma, ".": kVK_ANSI_Period, "/": kVK_ANSI_Slash,
        ]
        return map[char.lowercased()]
    }
}
