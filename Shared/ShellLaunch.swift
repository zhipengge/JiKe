import Foundation

enum ShellQuote {
    static func single(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

enum ShellLaunch {
    /// `-i` 强制交互式，才会读 `~/.zshrc`；`-l` 才会读 `~/.zprofile`（Homebrew 官方安装写在这里）。
    static func interactiveFlags(login: Bool) -> [String] {
        login ? ["-l", "-i"] : ["-i"]
    }

    static func arguments(shellPath: String, login: Bool, workingDirectory: String?) -> (executable: String, args: [String], execName: String) {
        let name = URL(fileURLWithPath: shellPath).lastPathComponent
        let execName = login ? "-\(name)" : name
        let launchFlags = interactiveFlags(login: login)
        guard let workingDirectory, !workingDirectory.isEmpty else {
            return (shellPath, launchFlags, execName)
        }
        let quoted = ShellQuote.single(workingDirectory)
        let flagSuffix = launchFlags.map { " \(ShellQuote.single($0))" }.joined()
        let command = "cd \(quoted) && exec \(ShellQuote.single(shellPath))\(flagSuffix)"
        return (shellPath, ["-c", command], execName)
    }
}