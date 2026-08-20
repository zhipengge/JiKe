import Foundation

/// 解析 Guake / GTK 加速键字符串，例如 `F12`、`<Control><Shift>t`、`<Super>minus`。
struct GtkAccelerator: Codable, Equatable {
    var gtk: String

    var isUnbound: Bool {
        gtk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || gtk == "disabled"
    }

    var keyCode: UInt32 { parsed.keyCode }
    var carbonModifiers: UInt32 { parsed.carbon }
    var nsModifierFlags: UInt { parsed.ns }
    var keyName: String { parsed.name }

    var displayName: String {
        if isUnbound { return "未绑定" }
        if gtk == "F12" { return "Fn+F12" }
        return parsed.label
    }

    /// 只比较 Shift / Ctrl / Opt / Cmd，忽略 Caps Lock，避免快捷键「按了没反应」。
    static let nsShift: UInt = 1 << 17
    static let nsControl: UInt = 1 << 18
    static let nsOption: UInt = 1 << 19
    static let nsCommand: UInt = 1 << 20
    static let nsMatchingMask: UInt = nsShift | nsControl | nsOption | nsCommand

    private var parsed: Parsed {
        Self.parse(gtk)
    }

    static func gtkToken(forKeyCode keyCode: UInt32) -> String? {
        keyCodeToGtk[keyCode]
    }

    /// 把一次按键还原成 Guake/GTK 加速键字符串。纯修饰键返回 nil。
    static func gtkString(keyCode: UInt16, nsModifiers: UInt) -> String? {
        guard let token = gtkToken(forKeyCode: UInt32(keyCode)) else { return nil }
        var prefix = ""
        if nsModifiers & nsControl != 0 { prefix += "<Control>" }
        if nsModifiers & nsOption != 0 { prefix += "<Alt>" }
        if nsModifiers & nsShift != 0 { prefix += "<Shift>" }
        if nsModifiers & nsCommand != 0 { prefix += "<Super>" }
        if prefix.isEmpty && token == "Escape" { return nil }
        return prefix + token
    }

    static func parse(_ gtk: String) -> Parsed {
        let raw = gtk.trimmingCharacters(in: .whitespacesAndNewlines)
        var carbon: UInt32 = 0
        var ns: UInt = 0
        var token = raw
        func eat(_ tag: String, carbonBit: UInt32, nsBit: UInt) {
            let wrapped = "<\(tag)>"
            if token.contains(wrapped) {
                token = token.replacingOccurrences(of: wrapped, with: "")
                carbon |= carbonBit
                ns |= nsBit
            }
        }
        eat("Primary", carbonBit: 256, nsBit: 1 << 20)
        eat("Super", carbonBit: 256, nsBit: 1 << 20)
        eat("Control", carbonBit: 4096, nsBit: 1 << 18)
        eat("Shift", carbonBit: 512, nsBit: 1 << 17)
        eat("Alt", carbonBit: 2048, nsBit: 1 << 19)
        token = token.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
        let mapping = keyMap[token] ?? keyMap[token.lowercased()]
        let code = mapping?.0 ?? 0
        let name = mapping?.1 ?? token
        var mods: [String] = []
        if ns & (1 << 18) != 0 { mods.append("Ctrl") }
        if ns & (1 << 19) != 0 { mods.append("Opt") }
        if ns & (1 << 17) != 0 { mods.append("Shift") }
        if ns & (1 << 20) != 0 { mods.append("Cmd") }
        let label = (mods + [name]).joined(separator: "+")
        return Parsed(keyCode: code, carbon: carbon, ns: ns, name: name, label: label)
    }

    struct Parsed: Equatable {
        var keyCode: UInt32
        var carbon: UInt32
        var ns: UInt
        var name: String
        var label: String
    }

    /// Mac 虚拟键码。名称对齐 Guake gschema 里用到的 GTK key。
    private static let keyMap: [String: (UInt32, String)] = [
        "F1": (0x7A, "F1"), "F2": (0x78, "F2"), "F3": (0x63, "F3"), "F4": (0x76, "F4"),
        "F5": (0x60, "F5"), "F6": (0x61, "F6"), "F7": (0x62, "F7"), "F8": (0x64, "F8"),
        "F9": (0x65, "F9"), "F10": (0x6D, "F10"), "F11": (0x67, "F11"), "F12": (0x6F, "F12"),
        "a": (0x00, "A"), "b": (0x0B, "B"), "c": (0x08, "C"), "d": (0x02, "D"), "e": (0x0E, "E"),
        "f": (0x03, "F"), "g": (0x05, "G"), "h": (0x04, "H"), "i": (0x22, "I"), "j": (0x26, "J"),
        "k": (0x28, "K"), "l": (0x25, "L"), "m": (0x2E, "M"), "n": (0x2D, "N"), "o": (0x1F, "O"),
        "p": (0x23, "P"), "q": (0x0C, "Q"), "r": (0x0F, "R"), "s": (0x01, "S"), "t": (0x11, "T"),
        "u": (0x20, "U"), "v": (0x09, "V"), "w": (0x0D, "W"), "x": (0x07, "X"), "y": (0x10, "Y"),
        "z": (0x06, "Z"),
        "plus": (0x18, "+"), "equal": (0x18, "="), "minus": (0x1B, "-"), "comma": (0x2B, ","),
        "Tab": (0x30, "Tab"), "Page_Up": (0x74, "PgUp"), "Page_Down": (0x79, "PgDn"),
        "Left": (0x7B, "Left"), "Right": (0x7C, "Right"), "Down": (0x7D, "Down"), "Up": (0x7E, "Up"),
        "Return": (0x24, "Return"), "Escape": (0x35, "Esc"), "space": (0x31, "Space"),
    ]

    private static let keyCodeToGtk: [UInt32: String] = {
        var map: [UInt32: String] = [:]
        for (token, pair) in keyMap {
            if map[pair.0] == nil || token.count == 1 {
                map[pair.0] = token
            }
        }
        map[0x18] = "equal"
        return map
    }()
}

struct KeybindingSpec: Equatable {
    var id: String
    var title: String
    var section: String
}

struct MacOSExtraBinding: Equatable {
    var id: String
    var gtk: String
    var title: String
}

/// 与 `org.guake.gschema.xml` 的 `keybindings` 默认值一一对应。
enum GuakeKeybindings {
    static let showHide = GtkAccelerator(gtk: "F12")
    static let showFocus = GtkAccelerator(gtk: "")

    static let localDefaults: [String: String] = [
        "search-terminal": "<Control><Shift>f",
        "quit": "<Control><Shift>q",
        "new-tab": "<Control><Shift>t",
        "new-tab-home": "<Control><Shift>h",
        "new-tab-cwd": "<Super>t",
        "close-tab": "<Control><Shift>w",
        "search-on-web": "<Control><Shift>l",
        "open-link-under-terminal-cursor": "<Control><Shift>o",
        "move-tab-left": "<Control><Shift>Page_Up",
        "move-tab-right": "<Control><Shift>Page_Down",
        "previous-tab": "<Control>Page_Up",
        "next-tab": "<Control>Page_Down",
        "previous-tab-alt": "<Control><Shift>Tab",
        "next-tab-alt": "<Control>Tab",
        "switch-tab1": "<Control>F1",
        "switch-tab2": "<Control>F2",
        "switch-tab3": "<Control>F3",
        "switch-tab4": "<Control>F4",
        "switch-tab5": "<Control>F5",
        "switch-tab6": "<Control>F6",
        "switch-tab7": "<Control>F7",
        "switch-tab8": "<Control>F8",
        "switch-tab9": "<Control>F9",
        "switch-tab10": "<Control>F10",
        "rename-current-tab": "<Control><Shift>R",
        "zoom-in": "<Control>plus",
        "zoom-in-alt": "<Control>equal",
        "zoom-out": "<Control>minus",
        "increase-height": "<Control>Down",
        "decrease-height": "<Control>Up",
        "increase-transparency": "<Control><Shift>b",
        "decrease-transparency": "<Control><Shift>n",
        "clipboard-copy": "<Control><Shift>c",
        "clipboard-paste": "<Control><Shift>v",
        "select-all": "<Control><Shift>a",
        "toggle-fullscreen": "F11",
        "toggle-hide-on-lose-focus": "<Control><Shift>F1",
        "reset-terminal": "",
        "toggle-transparency": "<Control><Alt>T",
        "switch-tab-last": "<Control>F12",
        "split-tab-vertical": "<Super><Shift>comma",
        "split-tab-horizontal": "<Super>minus",
        "close-terminal": "<Super>x",
        "focus-terminal-up": "<Super><Shift>Up",
        "focus-terminal-down": "<Super><Shift>Down",
        "focus-terminal-right": "<Super><Shift>Right",
        "focus-terminal-left": "<Super><Shift>Left",
        "move-terminal-split-up": "",
        "move-terminal-split-down": "",
        "move-terminal-split-left": "",
        "move-terminal-split-right": "",
    ]

    /// macOS 上 Guake 原键容易撞系统（F11 是显示桌面），这些额外键始终可用。
    static let macOSExtras: [MacOSExtraBinding] = [
        MacOSExtraBinding(id: "new-tab", gtk: "<Super>n", title: "新建标签"),
        MacOSExtraBinding(id: "close-tab", gtk: "<Super>w", title: "关闭标签"),
        MacOSExtraBinding(id: "toggle-fullscreen", gtk: "<Control><Super>f", title: "最大化 / 全屏"),
        MacOSExtraBinding(id: "toggle-fullscreen", gtk: "<Super>Return", title: "最大化 / 全屏"),
        MacOSExtraBinding(id: "clipboard-copy", gtk: "<Super>c", title: "拷贝选中文本"),
        MacOSExtraBinding(id: "clipboard-paste", gtk: "<Super>v", title: "粘贴（访达文件会变成路径）"),
        MacOSExtraBinding(id: "select-all", gtk: "<Super>a", title: "全选"),
        MacOSExtraBinding(id: "search-terminal", gtk: "<Super>f", title: "在终端中查找"),
        MacOSExtraBinding(id: "reveal-in-finder", gtk: "<Super><Shift>e", title: "在访达中打开当前目录"),
        MacOSExtraBinding(id: "open-settings", gtk: "<Super>comma", title: "打开设置"),
    ]

    static let catalog: [KeybindingSpec] = [
        KeybindingSpec(id: "new-tab", title: "新建标签", section: "标签"),
        KeybindingSpec(id: "new-tab-home", title: "在主目录新建标签", section: "标签"),
        KeybindingSpec(id: "new-tab-cwd", title: "在当前目录新建标签", section: "标签"),
        KeybindingSpec(id: "close-tab", title: "关闭标签", section: "标签"),
        KeybindingSpec(id: "rename-current-tab", title: "重命名标签", section: "标签"),
        KeybindingSpec(id: "previous-tab", title: "上一个标签", section: "标签"),
        KeybindingSpec(id: "next-tab", title: "下一个标签", section: "标签"),
        KeybindingSpec(id: "previous-tab-alt", title: "上一个标签（备选）", section: "标签"),
        KeybindingSpec(id: "next-tab-alt", title: "下一个标签（备选）", section: "标签"),
        KeybindingSpec(id: "move-tab-left", title: "标签左移", section: "标签"),
        KeybindingSpec(id: "move-tab-right", title: "标签右移", section: "标签"),
        KeybindingSpec(id: "switch-tab1", title: "切到标签 1", section: "标签"),
        KeybindingSpec(id: "switch-tab2", title: "切到标签 2", section: "标签"),
        KeybindingSpec(id: "switch-tab3", title: "切到标签 3", section: "标签"),
        KeybindingSpec(id: "switch-tab4", title: "切到标签 4", section: "标签"),
        KeybindingSpec(id: "switch-tab5", title: "切到标签 5", section: "标签"),
        KeybindingSpec(id: "switch-tab6", title: "切到标签 6", section: "标签"),
        KeybindingSpec(id: "switch-tab7", title: "切到标签 7", section: "标签"),
        KeybindingSpec(id: "switch-tab8", title: "切到标签 8", section: "标签"),
        KeybindingSpec(id: "switch-tab9", title: "切到标签 9", section: "标签"),
        KeybindingSpec(id: "switch-tab10", title: "切到标签 10", section: "标签"),
        KeybindingSpec(id: "switch-tab-last", title: "切到最后一个标签", section: "标签"),
        KeybindingSpec(id: "toggle-fullscreen", title: "最大化 / 全屏", section: "窗口"),
        KeybindingSpec(id: "increase-height", title: "增加窗口高度", section: "窗口"),
        KeybindingSpec(id: "decrease-height", title: "减少窗口高度", section: "窗口"),
        KeybindingSpec(id: "toggle-hide-on-lose-focus", title: "切换：失焦时隐藏", section: "窗口"),
        KeybindingSpec(id: "quit", title: "退出即刻", section: "窗口"),
        KeybindingSpec(id: "clipboard-copy", title: "拷贝", section: "终端"),
        KeybindingSpec(id: "clipboard-paste", title: "粘贴", section: "终端"),
        KeybindingSpec(id: "select-all", title: "全选", section: "终端"),
        KeybindingSpec(id: "search-terminal", title: "在终端中查找", section: "终端"),
        KeybindingSpec(id: "zoom-in", title: "放大字体", section: "终端"),
        KeybindingSpec(id: "zoom-in-alt", title: "放大字体（备选）", section: "终端"),
        KeybindingSpec(id: "zoom-out", title: "缩小字体", section: "终端"),
        KeybindingSpec(id: "reset-terminal", title: "复位终端", section: "终端"),
        KeybindingSpec(id: "search-on-web", title: "在网页搜索选中文本", section: "终端"),
        KeybindingSpec(id: "open-link-under-terminal-cursor", title: "打开选中链接", section: "终端"),
        KeybindingSpec(id: "increase-transparency", title: "降低不透明度", section: "终端"),
        KeybindingSpec(id: "decrease-transparency", title: "提高不透明度", section: "终端"),
        KeybindingSpec(id: "toggle-transparency", title: "切换透明度", section: "终端"),
        KeybindingSpec(id: "split-tab-vertical", title: "垂直分屏", section: "分屏"),
        KeybindingSpec(id: "split-tab-horizontal", title: "水平分屏", section: "分屏"),
        KeybindingSpec(id: "close-terminal", title: "关闭当前分屏", section: "分屏"),
        KeybindingSpec(id: "focus-terminal-up", title: "焦点向上", section: "分屏"),
        KeybindingSpec(id: "focus-terminal-down", title: "焦点向下", section: "分屏"),
        KeybindingSpec(id: "focus-terminal-left", title: "焦点向左", section: "分屏"),
        KeybindingSpec(id: "focus-terminal-right", title: "焦点向右", section: "分屏"),
    ]

    static let catalogSections = ["标签", "窗口", "终端", "分屏"]

    static func match(keyCode: UInt16, nsModifiers: UInt, against gtk: String) -> Bool {
        let accel = GtkAccelerator(gtk: gtk)
        if accel.isUnbound { return false }
        let flags = nsModifiers & GtkAccelerator.nsMatchingMask
        let expected = accel.nsModifierFlags & GtkAccelerator.nsMatchingMask
        return UInt32(keyCode) == accel.keyCode && flags == expected
    }
}