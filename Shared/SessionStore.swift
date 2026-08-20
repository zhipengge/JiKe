import Foundation

struct SessionSnapshot: Codable, Equatable {
    var tabs: [TabSnapshot]
    var selectedTabID: UUID?

    static var empty: SessionSnapshot { SessionSnapshot(tabs: [], selectedTabID: nil) }
}

struct TabSnapshot: Codable, Equatable, Identifiable {
    var id: UUID
    var customTitle: String?
    var workingDirectory: String?
    var split: SplitNode
    var focusedSessionID: UUID?

    init(
        id: UUID = UUID(),
        customTitle: String? = nil,
        workingDirectory: String? = nil,
        split: SplitNode = .singleLeaf(),
        focusedSessionID: UUID? = nil
    ) {
        self.id = id
        self.customTitle = customTitle
        self.workingDirectory = workingDirectory
        self.split = split
        self.focusedSessionID = focusedSessionID ?? split.leafIDs.first
    }
}

enum SessionStore {
    static func load(defaults: UserDefaults = .standard) -> SessionSnapshot {
        guard let data = defaults.data(forKey: SharedConstants.sessionKey) else {
            return .empty
        }
        return (try? JSONDecoder().decode(SessionSnapshot.self, from: data)) ?? .empty
    }

    static func save(_ snapshot: SessionSnapshot, defaults: UserDefaults = .standard) {
        if snapshot.tabs.isEmpty {
            defaults.removeObject(forKey: SharedConstants.sessionKey)
            return
        }
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: SharedConstants.sessionKey)
        }
    }
}