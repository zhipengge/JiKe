import Foundation

/// 把访达文件 / 拖放路径变成可直接粘贴进 shell 的文本。
enum MacPasteInsertion {
    static func text(filePaths: [String], fallback: String?) -> String {
        if !filePaths.isEmpty {
            return filePaths.map(ShellQuote.single).joined(separator: " ")
        }
        return fallback ?? ""
    }
}
