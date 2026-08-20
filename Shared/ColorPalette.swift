import Foundation

struct TerminalPalette: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var foreground: String
    var background: String
    var cursor: String
    var ansi: [String]

    var isValid: Bool {
        ansi.count == 16
            && [foreground, background, cursor].allSatisfy(Self.isHexColor)
            && ansi.allSatisfy(Self.isHexColor)
    }

    static func isHexColor(_ value: String) -> Bool {
        let raw = value.hasPrefix("#") ? String(value.dropFirst()) : value
        guard raw.count == 6, let _ = Int(raw, radix: 16) else { return false }
        return true
    }

    static func rgb(_ hex: String) -> (Double, Double, Double) {
        let raw = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard raw.count == 6, let value = Int(raw, radix: 16) else { return (0, 0, 0) }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        return (r, g, b)
    }
}

/// Guake `prefs.py` `update_demo_palette`：palette.split(":") 后 `[16]` 是前景、`[17]` 是背景。
enum GuakePaletteFormat {
    static func gtkChannelToHex8(_ token: String) -> String? {
        var raw = token.trimmingCharacters(in: .whitespaces)
        if raw.hasPrefix("#") { raw.removeFirst() }
        if raw.count == 12 {
            let r = String(raw.prefix(2))
            let g = String(raw.dropFirst(4).prefix(2))
            let b = String(raw.dropFirst(8).prefix(2))
            return (r + g + b).uppercased()
        }
        if raw.count == 6 { return raw.uppercased() }
        return nil
    }

    static func parse(gtkPalette: String, name: String = "Custom") -> TerminalPalette? {
        let parts = gtkPalette.split(separator: ":").map(String.init)
        guard parts.count >= 16 else { return nil }
        let ansi = parts.prefix(16).compactMap { gtkChannelToHex8($0).map { "#\($0)" } }
        guard ansi.count == 16 else { return nil }
        let fg = parts.count > 16 ? gtkChannelToHex8(parts[16]).map { "#\($0)" } : "#EEEEEC"
        let bg = parts.count > 17 ? gtkChannelToHex8(parts[17]).map { "#\($0)" } : "#000000"
        guard let fg, let bg else { return nil }
        return TerminalPalette(
            id: name == "Custom" ? "custom" : slug(name),
            name: name,
            foreground: fg,
            background: bg,
            cursor: fg,
            ansi: Array(ansi)
        )
    }

    static func slug(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

enum PaletteCatalog {
    static let all: [TerminalPalette] = GuakePalettesData.records.map { record in
        TerminalPalette(
            id: record.id,
            name: record.name,
            foreground: record.foreground,
            background: record.background,
            cursor: record.foreground,
            ansi: record.ansi
        )
    }

    static var ids: [String] { all.map(\.id) }

    static func palette(id: String) -> TerminalPalette {
        if let match = all.first(where: { $0.id == id || $0.name.caseInsensitiveCompare(id) == .orderedSame }) {
            return match
        }
        return all.first(where: { $0.name == "Tango" }) ?? all[0]
    }
}