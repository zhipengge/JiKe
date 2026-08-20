import Foundation

enum JiKeCommand: Equatable {
    case toggle
    case show
    case hide
    case fullscreen(Bool)
    case preferences
    case about
    case newTab(path: String?)
    case newTabHome
    case selectTabIndex(Int)
    case selectTab(UUID)
    case execute(String)
    case splitHorizontal(percent: Int)
    case splitVertical(percent: Int)
    case renameTab(String)
    case changePalette(String)
    case quit
    case unknown(String)

    /// 解析 `jike://`，语义对齐 Guake `main.py` 的命令行开关。
    static func parse(url: URL) -> JiKeCommand {
        guard url.scheme?.lowercased() == SharedConstants.urlScheme else {
            return .unknown(url.absoluteString)
        }
        let host = (url.host ?? "").lowercased()
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let token = host.isEmpty ? path : host
        let q = query(url)

        switch token {
        case "", "toggle", "toggle-visibility":
            return .toggle
        case "show":
            return .show
        case "hide":
            return .hide
        case "fullscreen":
            return .fullscreen(true)
        case "unfullscreen":
            return .fullscreen(false)
        case "preferences", "prefs":
            return .preferences
        case "about":
            return .about
        case "new-tab", "newtab":
            return .newTab(path: q["path"] ?? q["new-tab"])
        case "new-tab-home", "newtabhome":
            return .newTabHome
        case "select-tab":
            if let index = q["index"].flatMap(Int.init) { return .selectTabIndex(index) }
            if let id = q["id"].flatMap(UUID.init) { return .selectTab(id) }
            return .unknown(url.absoluteString)
        case "tab":
            if let id = q["id"].flatMap(UUID.init) { return .selectTab(id) }
            return .unknown(url.absoluteString)
        case "execute", "exec", "execute-command":
            if let command = q["cmd"] ?? q["command"], !command.isEmpty {
                return .execute(command)
            }
            return .unknown(url.absoluteString)
        case "split-horizontal", "splith":
            return .splitHorizontal(percent: Int(q["percent"] ?? "50") ?? 50)
        case "split-vertical", "splitv":
            return .splitVertical(percent: Int(q["percent"] ?? "50") ?? 50)
        case "rename-tab", "rename-current-tab":
            return .renameTab(q["title"] ?? q["name"] ?? "")
        case "change-palette":
            return .changePalette(q["name"] ?? "")
        case "quit":
            return .quit
        default:
            return .unknown(token)
        }
    }

    private static func query(_ url: URL) -> [String: String] {
        var result: [String: String] = [:]
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.forEach { item in
            if let value = item.value { result[item.name] = value }
        }
        return result
    }
}