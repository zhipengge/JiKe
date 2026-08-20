import Foundation

/// 对齐 Guake `globals.py` 的 `QUICK_OPEN_MATCHERS`：(标题, 快速匹配, 提取 path/line)。
struct GuakeQuickOpenMatcher: Equatable {
    var title: String
    var quick: String
    var extractor: String
}

enum QuickOpenTargetSource: Equatable {
    case pythonTraceback
    case pytest
    case gccError
    case gccLine
    case generic
}

struct QuickOpenTarget: Equatable {
    var path: String
    var line: Int?
    var column: Int?
    var source: QuickOpenTargetSource
}

enum QuickOpenParser {
    /// 原样来自 Guake `guake/globals.py`。
    static let guakeMatchers: [GuakeQuickOpenMatcher] = [
        GuakeQuickOpenMatcher(
            title: "Python traceback",
            quick: #"^\s*File\s\".*\",\sline\s[0-9]+"#,
            extractor: #"^\s*File\s\"(.*)\",\sline\s([0-9]+)"#
        ),
        GuakeQuickOpenMatcher(
            title: "Python pytest report",
            quick: #"^\s.*\:\:[a-zA-Z0-9\_]+\s"#,
            extractor: #"^\s*(.*\:\:[a-zA-Z0-9\_]+)\s"#
        ),
        GuakeQuickOpenMatcher(
            title: "line starts by 'ERROR in Filename:line' pattern (GCC/make). File path should exists.",
            quick: #"[a-zA-Z0-9\/\_\-\.\]+\.?[a-zA-Z0-9]+\:[0-9]+"#,
            extractor: #"\s.\S[^\s\s].(.*)\:([0-9]+)"#
        ),
        GuakeQuickOpenMatcher(
            title: "line starts by 'Filename:line' pattern (GCC/make). File path should exists.",
            quick: #"^\s*[a-zA-Z0-9\/\_\-\.\ ]+\.?[a-zA-Z0-9]+\:[0-9]+"#,
            extractor: #"^\s*(.*)\:([0-9]+)"#
        ),
    ]

    /// Guake 模板：`gedit %(file_path)s`，占位符 `%(file_path)s` / `%(line_number)s`。
    static func expandCommand(_ template: String, target: QuickOpenTarget) -> String {
        template
            .replacingOccurrences(of: "%(file_path)s", with: target.path)
            .replacingOccurrences(of: "%(line_number)s", with: target.line.map(String.init) ?? "")
    }

    static func parse(_ text: String) -> [QuickOpenTarget] {
        var seen = Set<String>()
        var results: [QuickOpenTarget] = []
        for line in text.split(whereSeparator: \.isNewline) {
            if let target = parseLine(String(line)) {
                let key = "\(target.path)#\(target.line ?? -1)#\(target.column ?? -1)"
                if seen.insert(key).inserted {
                    results.append(target)
                }
            }
        }
        return results
    }

    static func firstMatch(_ text: String) -> QuickOpenTarget? {
        parse(text).first
    }

    static func parseLine(_ line: String) -> QuickOpenTarget? {
        if let python = extract(line, matcher: guakeMatchers[0], source: .pythonTraceback) {
            return python
        }
        if let pytest = extract(line, matcher: guakeMatchers[1], source: .pytest) {
            return pytest
        }
        if let gcc = extract(line, matcher: guakeMatchers[3], source: .gccLine) {
            return gcc
        }
        if let gccError = extract(line, matcher: guakeMatchers[2], source: .gccError) {
            return gccError
        }
        if let generic = genericLocation(line) {
            return generic
        }
        return nil
    }

    private static func extract(_ line: String, matcher: GuakeQuickOpenMatcher, source: QuickOpenTargetSource) -> QuickOpenTarget? {
        guard line.range(of: matcher.quick, options: .regularExpression) != nil else { return nil }
        guard let regex = try? NSRegularExpression(pattern: matcher.extractor) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: range), match.numberOfRanges >= 2,
              let pathRange = Range(match.range(at: 1), in: line) else { return nil }
        let path = String(line[pathRange])
        var lineNumber: Int?
        if match.numberOfRanges >= 3, let lineRange = Range(match.range(at: 2), in: line) {
            lineNumber = Int(line[lineRange])
        }
        return QuickOpenTarget(path: path, line: lineNumber, column: nil, source: source)
    }

    private static func genericLocation(_ line: String) -> QuickOpenTarget? {
        guard let regex = try? NSRegularExpression(pattern: #"((?:\.\./|\./|~|/)?[\w./+\-@]+\.\w+):(\d+)(?::(\d+))?"#) else {
            return nil
        }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let pathRange = Range(match.range(at: 1), in: line),
              let lineRange = Range(match.range(at: 2), in: line) else { return nil }
        var column: Int?
        if match.numberOfRanges >= 4, let columnRange = Range(match.range(at: 3), in: line) {
            column = Int(line[columnRange])
        }
        return QuickOpenTarget(
            path: String(line[pathRange]),
            line: Int(line[lineRange]),
            column: column,
            source: .generic
        )
    }
}