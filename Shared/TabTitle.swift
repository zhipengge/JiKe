import Foundation

enum TabTitle {
    static let fallback = "终端"

    static func resolved(
        custom: String?,
        yamlTitle: String?,
        process: String?,
        workingDirectory: String?,
        display: TabNameDisplay = .lastSegment,
        useTerminalTitle: Bool = true
    ) -> String {
        if let custom = trimmed(custom) { return custom }
        if let yamlTitle = trimmed(yamlTitle) { return yamlTitle }
        if useTerminalTitle, let process = trimmed(process), !isBoringProcess(process) {
            return process
        }
        if let workingDirectory = trimmed(workingDirectory) {
            return displayPath(workingDirectory, mode: display)
        }
        return fallback
    }

    static func displayPath(_ path: String, mode: TabNameDisplay) -> String {
        let url = URL(fileURLWithPath: path)
        switch mode {
        case .fullPath:
            return path
        case .lastSegment:
            return url.lastPathComponent
        case .abbreviated:
            let parts = url.pathComponents.filter { $0 != "/" }
            guard parts.count > 2 else { return path }
            let abbrev = parts.dropLast().map { String($0.prefix(1)) }
            return (abbrev + [parts.last!]).joined(separator: "/")
        }
    }

    static func isBoringProcess(_ name: String) -> Bool {
        let last = URL(fileURLWithPath: name).lastPathComponent
        return ["zsh", "bash", "sh", "fish", "pwsh", "login", "-zsh", "-bash"].contains(last)
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum DirectoryConfig {
    /// Guake 读 `.guake.yml`；即刻同时接受 `.jike.yml`。
    static let fileNames = [".guake.yml", SharedConstants.directoryConfigFileName]

    static func title(from yaml: String) -> String? {
        for rawLine in yaml.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            guard line.lowercased().hasPrefix("title:") else { continue }
            var value = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }
}