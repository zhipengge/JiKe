import Foundation

/// 对齐 Guake `customcommands.py` 的 JSON 结构。
struct GuakeCustomCommandNode: Codable, Equatable {
    var type: String?
    var description: String
    var cmd: [String]?
    var items: [GuakeCustomCommandNode]?

    var isMenu: Bool { type == "menu" }

    var joinedCommand: String {
        (cmd ?? []).joined(separator: " ")
    }

    func flattenedLeaves() -> [(name: String, command: String)] {
        if isMenu {
            return (items ?? []).flatMap { $0.flattenedLeaves() }
        }
        let command = joinedCommand.trimmingCharacters(in: .whitespaces)
        guard !description.isEmpty, !command.isEmpty else { return [] }
        return [(description, command)]
    }
}

enum GuakeCustomCommandsFile {
    static func parse(json: String) -> [GuakeCustomCommandNode] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([GuakeCustomCommandNode].self, from: data)) ?? []
    }

    static func leaves(json: String) -> [(name: String, command: String)] {
        parse(json: json).flatMap { $0.flattenedLeaves() }
    }
}