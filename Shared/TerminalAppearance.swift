import Foundation

/// 设置页里的显示名 → 实际 PostScript 名。`NSFont(name: "SF Mono")` 会失败。
enum TerminalFontNames {
    static let presets: [(display: String, postScript: String)] = [
        ("Menlo", "Menlo-Regular"),
        ("SF Mono", "SFMono-Regular"),
        ("Monaco", "Monaco"),
        ("Courier", "Courier"),
        ("Andale Mono", "AndaleMono"),
    ]

    static var displayNames: [String] { presets.map(\.display) }

    static func candidates(for displayName: String) -> [String] {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ["Menlo-Regular", "Menlo"] }
        var names = [trimmed]
        if let mapped = presets.first(where: { $0.display.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            names.append(mapped.postScript)
        }
        names.append("\(trimmed)-Regular")
        names.append(trimmed.replacingOccurrences(of: " ", with: ""))
        names.append(contentsOf: ["Menlo-Regular", "Menlo"])
        var seen = Set<String>()
        return names.filter { seen.insert($0.lowercased()).inserted }
    }
}

/// 注入 UTF-8 locale，避免中文目录 / git 状态显示成乱码。
enum TerminalProcessEnvironment {
    static func posixUTF8Locale(from identifier: String) -> String {
        let normalized = identifier.replacingOccurrences(of: "-", with: "_")
        let lower = normalized.lowercased()
        if lower.hasPrefix("zh") {
            if lower.contains("tw") { return "zh_TW.UTF-8" }
            if lower.contains("hk") { return "zh_HK.UTF-8" }
            return "zh_CN.UTF-8"
        }
        let parts = normalized.split(separator: "_").map(String.init)
        if let lang = parts.first, let region = parts.last, parts.count >= 2, region.count == 2 {
            return "\(lang)_\(region.uppercased()).UTF-8"
        }
        return "en_US.UTF-8"
    }

    static func isUTF8(_ value: String?) -> Bool {
        guard let value else { return false }
        let upper = value.uppercased()
        return upper.contains("UTF-8") || upper.contains("UTF8")
    }

    static func applying(
        to environment: [String: String],
        localeIdentifier: String,
        processLANG: String?
    ) -> [String: String] {
        var env = environment
        let fallback = posixUTF8Locale(from: localeIdentifier)
        if !isUTF8(env["LANG"]) {
            env["LANG"] = isUTF8(processLANG) ? processLANG! : fallback
        }
        if !isUTF8(env["LC_CTYPE"]) {
            env["LC_CTYPE"] = env["LANG"]
        }
        env["PYTHONIOENCODING"] = "utf-8"
        return env
    }
}

/// 传给 SwiftUI `NSViewRepresentable`，外观一变就会走 `updateNSView`。
struct AppearanceSnapshot: Equatable {
    var paletteID: String
    var transparency: Int
    var fontName: String
    var fontSize: Double
    var cursorShape: CursorShape
    var optionAsMeta: Bool
    var scrollbackLines: Int
    var infiniteScrollback: Bool

    init(_ config: AppConfig) {
        paletteID = config.paletteID
        transparency = config.transparency
        fontName = config.fontName
        fontSize = config.fontSize
        cursorShape = config.cursorShape
        optionAsMeta = config.optionAsMeta
        scrollbackLines = config.scrollbackLines
        infiniteScrollback = config.infiniteScrollback
    }
}
