import SwiftUI

struct DropDownContentView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            if state.config.showTabBar && state.config.tabBarPosition == .top && !(state.config.hideTabBarIfOneTab && state.tabs.count == 1) {
                tabBar
            }
            if state.findVisible {
                findBar
            }
            paneArea
            resizeHandle
            if state.config.showTabBar && state.config.tabBarPosition == .bottom && !(state.config.hideTabBarIfOneTab && state.tabs.count == 1) {
                tabBar
            }
        }
        .background(background)
        .onAppear {
            KeybindMonitor.shared.start()
        }
    }

    private var background: some View {
        let rgb = TerminalPalette.rgb(state.config.palette.background)
        return Color(red: rgb.0, green: rgb.1, blue: rgb.2)
            .opacity(WindowGeometry.backgroundAlpha(state.config.transparency))
    }

    private var paneArea: some View {
        Group {
            if let tab = state.selectedTab {
                SplitHost(node: tab.split, tab: tab)
                    .id(tab.id)
            } else {
                Color.black
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Array(state.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabChip(
                            title: tab.displayTitle,
                            index: index,
                            selected: tab.id == state.selectedTabID
                        ) {
                            state.selectedTabID = tab.id
                            TerminalSessionCache.shared.focus(tab.focusedSessionID)
                        } onClose: {
                            state.closeTab(id: tab.id)
                        } onRename: {
                            RenameTabPrompt.present()
                        }
                    }
                }
                .padding(.horizontal, 6)
            }
            Color.clear
                .frame(minWidth: 12)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    state.newTab(home: false)
                }
            Button {
                state.newTab(home: false)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("新建标签")
            Button {
                SettingsWindowOpener.open()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("设置")
        }
        .frame(height: 28)
        .foregroundStyle(.white.opacity(0.9))
        .background(Color.black.opacity(0.35))
    }

    private var findBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
            TextField("在当前终端查找", text: $state.findQuery)
                .textFieldStyle(.plain)
            Text(findSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("完成") { state.findVisible = false }
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color.black.opacity(0.4))
        .foregroundStyle(.white)
    }

    private var findSummary: String {
        let text = state.saveFocusedOutput()
        let query = state.findQuery
        guard !query.isEmpty else { return "" }
        let count = text.components(separatedBy: query).count - 1
        return count > 0 ? "\(count) 处" : "无匹配"
    }

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 5)
            .overlay(
                Capsule()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: 48, height: 2)
            )
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        DropDownWindowController.shared.resize(to: NSPoint(x: value.location.x, y: NSEvent.mouseLocation.y))
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

struct TabChip: View {
    let title: String
    let index: Int
    let selected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onRename: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("\(index + 1)")
                .font(.system(size: 9, design: .monospaced))
                .opacity(0.6)
            Text(title)
                .lineLimit(1)
            if AppState.shared.config.showTabCloseButtons {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: 11))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(selected ? Color.white.opacity(0.18) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onTapGesture(perform: onSelect)
        .onTapGesture(count: 2, perform: onRename)
        .contextMenu {
            Button("重命名…", action: onRename)
            Button("关闭", action: onClose)
        }
    }
}

struct SplitHost: View {
    let node: SplitNode
    @ObservedObject var tab: TabModel
    @EnvironmentObject private var state: AppState

    var body: some View {
        switch node {
        case .leaf(let id):
            TerminalPaneView(
                sessionID: id,
                tabID: tab.id,
                workingDirectory: tab.workingDirectory,
                appearance: AppearanceSnapshot(state.config)
            )
        case .split(_, let direction, let first, let second, let ratio):
            SplitPair(direction: direction, ratio: ratio, first: first, second: second, tab: tab, node: node)
        }
    }
}

struct SplitPair: View {
    let direction: SplitDirection
    let ratio: Double
    let first: SplitNode
    let second: SplitNode
    @ObservedObject var tab: TabModel
    let node: SplitNode

    var body: some View {
        GeometryReader { geo in
            let isHorizontal = direction == .horizontal
            let total = isHorizontal ? geo.size.width : geo.size.height
            let firstSize = total * ratio
            ZStack(alignment: .topLeading) {
                SplitHost(node: first, tab: tab)
                    .frame(
                        width: isHorizontal ? firstSize : geo.size.width,
                        height: isHorizontal ? geo.size.height : firstSize
                    )
                    .offset(x: 0, y: 0)
                SplitHost(node: second, tab: tab)
                    .frame(
                        width: isHorizontal ? total - firstSize - 4 : geo.size.width,
                        height: isHorizontal ? geo.size.height : total - firstSize - 4
                    )
                    .offset(
                        x: isHorizontal ? firstSize + 4 : 0,
                        y: isHorizontal ? 0 : firstSize + 4
                    )
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(
                        width: isHorizontal ? 4 : geo.size.width,
                        height: isHorizontal ? geo.size.height : 4
                    )
                    .offset(
                        x: isHorizontal ? firstSize : 0,
                        y: isHorizontal ? 0 : firstSize
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let delta = isHorizontal ? value.translation.width : value.translation.height
                                let next = min(0.85, max(0.15, Double((firstSize + delta) / total)))
                                tab.split = replaceRatio(in: tab.split, nodeID: node.id, ratio: next)
                            }
                    )
            }
        }
    }

    private func replaceRatio(in root: SplitNode, nodeID: UUID, ratio: Double) -> SplitNode {
        switch root {
        case .leaf:
            return root
        case .split(let id, let direction, let first, let second, let current):
            if id == nodeID {
                return .split(id: id, direction: direction, first: first, second: second, ratio: ratio)
            }
            return .split(
                id: id,
                direction: direction,
                first: replaceRatio(in: first, nodeID: nodeID, ratio: ratio),
                second: replaceRatio(in: second, nodeID: nodeID, ratio: ratio),
                ratio: current
            )
        }
    }
}

struct TerminalPaneView: NSViewRepresentable {
    let sessionID: UUID
    let tabID: UUID
    let workingDirectory: String?
    var appearance: AppearanceSnapshot

    func makeNSView(context: Context) -> NSView {
        let container = FlippedContainer()
        container.registerForDraggedTypes([.fileURL])
        let term = TerminalSessionCache.shared.view(for: sessionID, tabID: tabID, workingDirectory: workingDirectory)
        term.translatesAutoresizingMaskIntoConstraints = true
        term.autoresizingMask = [.width, .height]
        (term as NSView).frame = container.bounds
        container.addSubview(term)
        term.applyAppearance(config: AppState.shared.config)
        DispatchQueue.main.async {
            if AppState.shared.selectedTab?.focusedSessionID == sessionID {
                TerminalSessionCache.shared.focus(sessionID)
            }
        }
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let term = nsView.subviews.first as? EmbeddedTerminalView {
            term.applyAppearance(config: AppState.shared.config, force: false)
            (term as NSView).frame = nsView.bounds
        }
    }
}

final class FlippedContainer: NSView {
    override var isFlipped: Bool { false }
    override var isOpaque: Bool { false }

    override func layout() {
        super.layout()
        subviews.forEach { $0.frame = bounds }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        canAccept(sender) ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        canAccept(sender) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        let paths = urls.filter(\.isFileURL).map(\.path)
        guard !paths.isEmpty, let term = subviews.first as? EmbeddedTerminalView else { return false }
        term.insertDroppedPaths(paths)
        window?.makeFirstResponder(term)
        return true
    }

    private func canAccept(_ sender: NSDraggingInfo) -> Bool {
        sender.draggingPasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
    }
}