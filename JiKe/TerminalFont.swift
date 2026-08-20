import AppKit

enum TerminalFont {
    static func resolve(name: String, size: CGFloat) -> NSFont {
        for candidate in TerminalFontNames.candidates(for: name) {
            if let font = NSFont(name: candidate, size: size) {
                return withCJKFallback(font)
            }
        }
        if let members = NSFontManager.shared.availableMembers(ofFontFamily: name),
           let postScript = members.first?.first as? String,
           let font = NSFont(name: postScript, size: size) {
            return withCJKFallback(font)
        }
        return withCJKFallback(NSFont.monospacedSystemFont(ofSize: size, weight: .regular))
    }

    /// SwiftTerm 用单字体画字形；加上中文/Emoji 级联，避免方块乱码。
    static func withCJKFallback(_ font: NSFont) -> NSFont {
        let cascade = ["PingFang SC", "PingFang TC", "Hiragino Sans GB", "Songti SC", "Apple Color Emoji"]
            .map { NSFontDescriptor(fontAttributes: [.family: $0]) }
        let descriptor = font.fontDescriptor.addingAttributes([.cascadeList: cascade])
        return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
    }
}
