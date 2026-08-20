import Foundation

enum SplitDirection: String, Codable, Equatable {
    case horizontal
    case vertical
}

/// 一个标签页内的分屏树。叶子是终端会话 UUID。
indirect enum SplitNode: Codable, Equatable, Identifiable {
    case leaf(id: UUID)
    case split(id: UUID, direction: SplitDirection, first: SplitNode, second: SplitNode, ratio: Double)

    var id: UUID {
        switch self {
        case .leaf(let id): return id
        case .split(let id, _, _, _, _): return id
        }
    }

    var leafIDs: [UUID] {
        switch self {
        case .leaf(let id):
            return [id]
        case .split(_, _, let first, let second, _):
            return first.leafIDs + second.leafIDs
        }
    }

    static func singleLeaf(_ id: UUID = UUID()) -> SplitNode {
        .leaf(id: id)
    }

    func splitting(leafID: UUID, direction: SplitDirection, newID: UUID = UUID(), ratio: Double = 0.5) -> SplitNode {
        switch self {
        case .leaf(let id):
            guard id == leafID else { return self }
            return .split(
                id: UUID(),
                direction: direction,
                first: .leaf(id: id),
                second: .leaf(id: newID),
                ratio: clampedRatio(ratio)
            )
        case .split(let id, let dir, let first, let second, let currentRatio):
            return .split(
                id: id,
                direction: dir,
                first: first.splitting(leafID: leafID, direction: direction, newID: newID, ratio: ratio),
                second: second.splitting(leafID: leafID, direction: direction, newID: newID, ratio: ratio),
                ratio: currentRatio
            )
        }
    }

    /// 关掉一个叶子。若整棵树空了返回 nil。
    func closing(leafID: UUID) -> SplitNode? {
        switch self {
        case .leaf(let id):
            return id == leafID ? nil : self
        case .split(_, _, let first, let second, _):
            let left = first.closing(leafID: leafID)
            let right = second.closing(leafID: leafID)
            switch (left, right) {
            case (nil, nil): return nil
            case (let remaining?, nil): return remaining
            case (nil, let remaining?): return remaining
            case (let left?, let right?):
                return .split(id: UUID(), direction: direction, first: left, second: right, ratio: ratio)
            }
        }
    }

    var direction: SplitDirection {
        switch self {
        case .leaf: return .horizontal
        case .split(_, let direction, _, _, _): return direction
        }
    }

    var ratio: Double {
        switch self {
        case .leaf: return 1
        case .split(_, _, _, _, let ratio): return ratio
        }
    }

    func settingRatio(_ newRatio: Double) -> SplitNode {
        switch self {
        case .leaf:
            return self
        case .split(let id, let direction, let first, let second, _):
            return .split(id: id, direction: direction, first: first, second: second, ratio: clampedRatio(newRatio))
        }
    }

    func neighbor(of leafID: UUID, moving: PaneMove) -> UUID? {
        let ids = leafIDs
        guard let index = ids.firstIndex(of: leafID) else { return nil }
        switch moving {
        case .previous:
            return index > 0 ? ids[index - 1] : ids.last
        case .next:
            return index + 1 < ids.count ? ids[index + 1] : ids.first
        }
    }

    private func clampedRatio(_ value: Double) -> Double {
        min(0.85, max(0.15, value))
    }
}

enum PaneMove: String, Equatable {
    case previous
    case next
}