import Foundation

enum ShellQuote {
    static func single(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

enum ShellLaunch {
    static func arguments(shellPath: String, login: Bool, workingDirectory: String?) -> (executable: String, args: [String], execName: String) {
        let name = URL(fileURLWithPath: shellPath).lastPathComponent
        let execName = login ? "-\(name)" : name
        guard let workingDirectory, !workingDirectory.isEmpty else {
            return (shellPath, login ? ["-l"] : [], execName)
        }
        let quoted = ShellQuote.single(workingDirectory)
        let command = "cd \(quoted) && exec \(ShellQuote.single(shellPath))\(login ? " -l" : "")"
        return (shellPath, ["-c", command], execName)
    }
}