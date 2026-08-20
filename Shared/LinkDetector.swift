import Foundation

/// 对齐 Guake `globals.py` 的 `ENGINES`。
enum SearchEngine: Int, Codable, CaseIterable, Equatable, Identifiable {
    case google = 0
    case duckduckgo = 1
    case bing = 2
    case yandex = 3
    case neeva = 4
    case custom = 99

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .google: return "Google"
        case .duckduckgo: return "DuckDuckGo"
        case .bing: return "Bing"
        case .yandex: return "Yandex"
        case .neeva: return "Neeva"
        case .custom: return "自定义"
        }
    }

    /// Guake 原字符串，不含 scheme，搜索时补 `https://`。
    var guakeHostPath: String {
        switch self {
        case .google: return "www.google.com/search?safe=off&q="
        case .duckduckgo: return "www.duckduckgo.com/"
        case .bing: return "www.bing.com/search?q="
        case .yandex: return "www.yandex.com/search?text="
        case .neeva: return "neeva.com/search?q="
        case .custom: return ""
        }
    }

    func searchURL(query: String, customURL: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        switch self {
        case .custom:
            let base = customURL.isEmpty ? SearchEngine.google.guakeHostPath : customURL
            return URL(string: Self.withScheme(base) + encoded)
        case .duckduckgo:
            return URL(string: "https://www.duckduckgo.com/?q=\(encoded)")
        default:
            return URL(string: "https://" + guakeHostPath + encoded)
        }
    }

    private static func withScheme(_ value: String) -> String {
        if value.hasPrefix("http://") || value.hasPrefix("https://") { return value }
        return "https://" + value
    }
}

enum LinkDetector {
    /// 对齐 Guake `TERMINAL_MATCH_TAGS` 里的 http/https/ftp。
    private static let pattern = #"(?:https?|ftp|ftps|file|webcal)://[^\s<>"')\]]+"#

    static func urls(in text: String) -> [URL] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let slice = Range(match.range, in: text) else { return nil }
            var raw = String(text[slice])
            while let last = raw.last, ".,;:!?)]}>'\"".contains(last) {
                raw.removeLast()
            }
            return URL(string: raw)
        }
    }

    static func firstURL(in text: String) -> URL? {
        urls(in: text).first
    }
}