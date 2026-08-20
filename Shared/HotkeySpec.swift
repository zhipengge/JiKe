import Foundation

/// 全局快捷键。默认对应 Mac 笔记本上的 Fn+F12（系统把 Fn+F12 发成 F12 键）。
struct HotkeySpec: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static let f12 = HotkeySpec(keyCode: 0x6F, carbonModifiers: 0)

    var isDefaultToggle: Bool {
        self == .f12
    }

    /// 给设置页 / 状态栏用的可读名称。
    var displayName: String {
        let key = Self.keyName(keyCode)
        let mods = Self.modifierNames(carbonModifiers)
        if mods.isEmpty {
            if keyCode == 0x6F { return "Fn+F12" }
            return key
        }
        return (mods + [key]).joined(separator: "+")
    }

    static func keyName(_ keyCode: UInt32) -> String {
        if let name = functionKeyNames[keyCode] { return name }
        return "Key\(keyCode)"
    }

    static func modifierNames(_ carbonModifiers: UInt32) -> [String] {
        var names: [String] = []
        if carbonModifiers & 4096 != 0 { names.append("Ctrl") }
        if carbonModifiers & 2048 != 0 { names.append("Opt") }
        if carbonModifiers & 512 != 0 { names.append("Shift") }
        if carbonModifiers & 256 != 0 { names.append("Cmd") }
        return names
    }

    private static let functionKeyNames: [UInt32: String] = [
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
        0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
        0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
    ]
}