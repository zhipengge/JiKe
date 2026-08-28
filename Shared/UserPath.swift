import Foundation

/// 从访达 / 登录项启动时，App 继承的 PATH 只有 `/usr/bin:/bin:/usr/sbin:/sbin`。
/// Homebrew、MacPorts、`~/bin` 都不会在里面；系统「终端」靠登录 Shell 读 `~/.zprofile` 才补上。
/// 即刻在 spawn 前按 path_helper 规则拼一份可用 PATH，这样即使用户关掉登录 Shell，也能直接跑 `brew` / `git`。
enum UserPath {
    static let extraDirectories = [
        "/opt/homebrew/bin",
        "/opt/homebrew/sbin",
        "/usr/local/bin",
        "/usr/local/sbin",
        "/opt/local/bin",
        "/opt/local/sbin",
    ]

    static func resolved(
        current: String?,
        home: String = NSHomeDirectory(),
        extraDirectories: [String] = extraDirectories,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) },
        contentsOf: (String) -> String? = { try? String(contentsOfFile: $0, encoding: .utf8) },
        directoryListing: (String) -> [String] = {
            ((try? FileManager.default.contentsOfDirectory(atPath: $0)) ?? []).sorted()
        }
    ) -> String {
        var ordered: [String] = []
        var seen = Set<String>()

        func add(_ raw: String) {
            let path = (raw as NSString)
                .expandingTildeInPath
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty, !path.hasPrefix("#") else { return }
            if seen.insert(path).inserted {
                ordered.append(path)
            }
        }

        for directory in extraDirectories where fileExists(directory) {
            add(directory)
        }
        for directory in ["\(home)/.local/bin", "\(home)/bin", "\(home)/.cargo/bin"] where fileExists(directory) {
            add(directory)
        }

        for line in lines(in: contentsOf("/etc/paths")) {
            add(line)
        }
        for name in directoryListing("/etc/paths.d") where !name.hasPrefix(".") {
            for line in lines(in: contentsOf("/etc/paths.d/\(name)")) {
                add(line)
            }
        }

        if let current {
            for part in current.split(separator: ":", omittingEmptySubsequences: true) {
                add(String(part))
            }
        }

        return ordered.joined(separator: ":")
    }

    private static func lines(in text: String?) -> [String] {
        guard let text else { return [] }
        return text.split(whereSeparator: \.isNewline).map(String.init)
    }
}
