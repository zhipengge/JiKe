import AppKit
import Combine
import Foundation

@MainActor
final class TabModel: ObservableObject, Identifiable {
    let id: UUID
    @Published var customTitle: String?
    @Published var yamlTitle: String?
    @Published var processTitle: String?
    @Published var workingDirectory: String?
    @Published var split: SplitNode
    @Published var focusedSessionID: UUID

    init(snapshot: TabSnapshot) {
        id = snapshot.id
        customTitle = snapshot.customTitle
        workingDirectory = snapshot.workingDirectory
        split = snapshot.split
        focusedSessionID = snapshot.focusedSessionID ?? snapshot.split.leafIDs.first ?? snapshot.split.id
    }

    init(workingDirectory: String?) {
        let leaf = UUID()
        id = UUID()
        customTitle = nil
        yamlTitle = nil
        processTitle = nil
        self.workingDirectory = workingDirectory
        split = .leaf(id: leaf)
        focusedSessionID = leaf
    }

    var displayTitle: String {
        TabTitle.resolved(
            custom: customTitle,
            yamlTitle: yamlTitle,
            process: processTitle,
            workingDirectory: workingDirectory,
            display: AppState.shared.config.tabNameDisplay,
            useTerminalTitle: AppState.shared.config.useTerminalTitle
        )
    }

    func snapshot() -> TabSnapshot {
        TabSnapshot(
            id: id,
            customTitle: customTitle,
            workingDirectory: workingDirectory,
            split: split,
            focusedSessionID: focusedSessionID
        )
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var config: AppConfig {
        didSet {
            ConfigStore.save(config)
            applyConfigSideEffects()
        }
    }
    @Published var tabs: [TabModel]
    @Published var selectedTabID: UUID?
    @Published var isDropDownVisible = false
    @Published var findQuery = ""
    @Published var findVisible = false

    @Published var isFullscreen = false
    private var lastFullscreenChangeAt: TimeInterval = 0
    private var lastToggleAt: TimeInterval = 0

    let sessions = TerminalSessionCache.shared

    private init() {
        let loaded = ConfigStore.load()
        config = loaded
        if loaded.restoreTabs {
            let snapshot = SessionStore.load()
            if snapshot.tabs.isEmpty {
                let tab = TabModel(workingDirectory: NSHomeDirectory())
                tabs = [tab]
                selectedTabID = tab.id
            } else {
                tabs = snapshot.tabs.map(TabModel.init(snapshot:))
                selectedTabID = snapshot.selectedTabID ?? tabs.first?.id
            }
        } else {
            let tab = TabModel(workingDirectory: NSHomeDirectory())
            tabs = [tab]
            selectedTabID = tab.id
        }
    }

    var selectedTab: TabModel? {
        tabs.first(where: { $0.id == selectedTabID }) ?? tabs.first
    }

    func applyPalette(_ id: String) {
        if config.paletteID != id {
            var next = config
            next.paletteID = id
            config = next
        }
        sessions.forceApplyAppearance(config: config)
    }

    func applyConfigSideEffects() {
        HotkeyManager.shared.register(config.hotkey)
        StatusItemController.shared.refresh()
        LoginItemManager.sync(enabled: config.launchAtLogin)
        Prefs.applyActivationPolicy()
        DropDownWindowController.shared.applyLevel()
        DropDownWindowController.shared.updateFrameForConfig()
        sessions.applyAppearance(config: config)
    }

    func persistSession() {
        guard config.restoreTabs, config.saveTabsWhenChanged else {
            if !config.restoreTabs {
                SessionStore.save(.empty)
            }
            return
        }
        let snapshot = SessionSnapshot(tabs: tabs.map { $0.snapshot() }, selectedTabID: selectedTabID)
        SessionStore.save(snapshot)
    }

    func apply(_ command: JiKeCommand) {
        switch command {
        case .toggle:
            toggleDropDown()
        case .show:
            showDropDown()
        case .hide:
            hideDropDown()
        case .fullscreen(let on):
            isFullscreen = on
            showDropDown()
            DropDownWindowController.shared.updateFrameForConfig()
        case .preferences:
            SettingsWindowOpener.open()
        case .about:
            SettingsWindowOpener.open()
        case .newTab(let path):
            newTab(home: false, path: path)
            showDropDown()
        case .newTabHome:
            newTab(home: true)
            showDropDown()
        case .selectTabIndex(let index):
            if tabs.indices.contains(index) {
                selectedTabID = tabs[index].id
            }
            showDropDown()
        case .selectTab(let id):
            if tabs.contains(where: { $0.id == id }) {
                selectedTabID = id
            }
            showDropDown()
        case .execute(let commandLine):
            showDropDown()
            sendToFocused("\(commandLine)\n")
        case .splitHorizontal(let percent):
            splitFocused(.horizontal, ratio: Double(percent) / 100)
            showDropDown()
        case .splitVertical(let percent):
            splitFocused(.vertical, ratio: Double(percent) / 100)
            showDropDown()
        case .renameTab(let title):
            renameSelectedTab(title == "-" ? "" : title)
        case .changePalette(let name):
            guard !name.isEmpty else { break }
            applyPalette(GuakePaletteFormat.slug(name))
        case .quit:
            requestQuit()
        case .unknown:
            break
        }
    }

    func toggleDropDown() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastToggleAt < 0.2 { return }
        lastToggleAt = now
        if DropDownWindowController.shared.isOnScreen {
            hideDropDown()
        } else {
            showDropDown()
        }
    }

    func showDropDown() {
        isDropDownVisible = true
        DropDownWindowController.shared.show()
    }

    func hideDropDown() {
        isDropDownVisible = false
        DropDownWindowController.shared.hide()
    }

    func newTab(home: Bool, path: String? = nil) {
        let cwd: String?
        if let path, !path.isEmpty {
            cwd = (path as NSString).expandingTildeInPath
        } else if home {
            cwd = NSHomeDirectory()
        } else if config.openNewTabInCWD {
            cwd = currentWorkingDirectory() ?? NSHomeDirectory()
        } else {
            cwd = NSHomeDirectory()
        }
        let tab = TabModel(workingDirectory: cwd)
        tabs.append(tab)
        selectedTabID = tab.id
        persistSession()
    }

    func closeSession(_ sessionID: UUID, prompt: Bool = false) {
        guard let tab = tabs.first(where: { $0.split.leafIDs.contains(sessionID) }) else { return }
        if let next = tab.split.closing(leafID: sessionID) {
            sessions.terminate(sessionID)
            tab.split = next
            if tab.focusedSessionID == sessionID {
                tab.focusedSessionID = next.leafIDs.first ?? next.id
            }
            persistSession()
            return
        }
        closeTab(id: tab.id, prompt: prompt)
    }

    func closeCurrentPane() {
        guard let tab = selectedTab else { return }
        closeSession(tab.focusedSessionID, prompt: true)
    }

    func closeTab(id: UUID, prompt: Bool = true) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        if prompt, config.promptOnCloseTab == .always {
            let alert = NSAlert()
            alert.messageText = "关闭这个标签？"
            alert.informativeText = "标签里的终端进程会被结束。"
            alert.addButton(withTitle: "关闭")
            alert.addButton(withTitle: "取消")
            if alert.runModal() != .alertFirstButtonReturn { return }
        }
        let tab = tabs[index]
        for leaf in tab.split.leafIDs {
            sessions.terminate(leaf)
        }
        tabs.remove(at: index)
        if tabs.isEmpty {
            let replacement = TabModel(workingDirectory: defaultWorkingDirectory(for: config))
            tabs = [replacement]
            selectedTabID = replacement.id
        } else {
            let nextIndex = min(index, tabs.count - 1)
            selectedTabID = tabs[nextIndex].id
        }
        persistSession()
    }

    func splitFocused(_ direction: SplitDirection, ratio: Double = 0.5) {
        guard let tab = selectedTab else { return }
        let newID = UUID()
        tab.split = tab.split.splitting(leafID: tab.focusedSessionID, direction: direction, newID: newID, ratio: ratio)
        tab.focusedSessionID = newID
        persistSession()
    }

    func moveTab(offset: Int) {
        guard let index = tabs.firstIndex(where: { $0.id == selectedTabID }) else { return }
        let next = index + offset
        guard tabs.indices.contains(next) else { return }
        tabs.swapAt(index, next)
        persistSession()
    }

    func changeTransparency(delta: Int) {
        var next = config
        next.transparency = WindowGeometry.clampedTransparency(next.transparency + delta)
        config = next
        DropDownWindowController.shared.updateFrameForConfig()
    }

    func toggleTransparency() {
        var next = config
        next.transparency = next.transparency > 50 ? 20 : 90
        config = next
    }

    func changeHeight(delta: Double) {
        var next = config
        next.windowHeightPercent = WindowGeometry.clampedHeightPercent(next.windowHeightPercent + delta)
        config = next
        DropDownWindowController.shared.updateFrameForConfig()
    }

    func toggleFullscreen() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastFullscreenChangeAt < 0.2 { return }
        lastFullscreenChangeAt = now
        isFullscreen.toggle()
        DropDownWindowController.shared.updateFrameForConfig()
    }

    /// Fn+F11：终端没收起时先滑出再最大化；已显示则切换最大化。
    func maximizeFromGlobalHotkey() {
        if !DropDownWindowController.shared.isOnScreen {
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastFullscreenChangeAt < 0.2 { return }
            lastFullscreenChangeAt = now
            isFullscreen = true
            showDropDown()
            DropDownWindowController.shared.updateFrameForConfig()
            return
        }
        toggleFullscreen()
    }

    func searchOnWeb() {
        let selected = selectedTab.flatMap { sessions.selectedText($0.focusedSessionID) } ?? ""
        guard !selected.isEmpty,
              let url = config.searchEngine.searchURL(query: selected, customURL: config.customSearchEngineURL) else { return }
        NSWorkspace.shared.open(url)
    }

    func requestQuit() {
        if config.promptOnQuit {
            let alert = NSAlert()
            alert.messageText = "退出即刻？"
            alert.informativeText = "所有标签里的终端进程都会结束。"
            alert.addButton(withTitle: "退出")
            alert.addButton(withTitle: "取消")
            if alert.runModal() != .alertFirstButtonReturn { return }
        }
        persistSession()
        NSApp.terminate(nil)
    }

    func selectTab(offset: Int) {
        guard !tabs.isEmpty else { return }
        let current = tabs.firstIndex(where: { $0.id == selectedTabID }) ?? 0
        let next = (current + offset + tabs.count * 8) % tabs.count
        selectedTabID = tabs[next].id
    }

    func selectTab(number: Int) {
        guard number >= 1, number <= tabs.count else { return }
        selectedTabID = tabs[number - 1].id
    }

    func moveFocus(_ move: PaneMove) {
        guard let tab = selectedTab, let next = tab.split.neighbor(of: tab.focusedSessionID, moving: move) else { return }
        tab.focusedSessionID = next
        sessions.focus(next)
    }

    func changeFont(delta: Double) {
        var next = config
        next.fontSize = WindowGeometry.clampedFontSize(next.fontSize + delta)
        config = next
    }

    func renameSelectedTab(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        selectedTab?.customTitle = trimmed.isEmpty ? nil : trimmed
        persistSession()
        objectWillChange.send()
    }

    func sendToFocused(_ text: String) {
        guard let tab = selectedTab else { return }
        sessions.send(tab.focusedSessionID, text: text)
    }

    func saveFocusedOutput() -> String {
        guard let tab = selectedTab else { return "" }
        return sessions.exportText(tab.focusedSessionID)
    }

    func runCustomCommand(_ command: CustomCommand) {
        showDropDown()
        sendToFocused(command.command.hasSuffix("\n") ? command.command : command.command + "\n")
    }

    func restoreDefaults() {
        config = ConfigStore.restoredDefaults()
    }

    func currentWorkingDirectory() -> String? {
        selectedTab?.workingDirectory
    }

    func revealCWDInFinder() {
        let path = currentWorkingDirectory() ?? NSHomeDirectory()
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func defaultWorkingDirectory(for config: AppConfig) -> String {
        if config.openNewTabInCWD {
            return selectedTab?.workingDirectory ?? NSHomeDirectory()
        }
        return NSHomeDirectory()
    }

    func updateDirectory(_ path: String?, for sessionID: UUID) {
        guard let tab = tabs.first(where: { $0.split.leafIDs.contains(sessionID) }) else { return }
        tab.workingDirectory = path
        if let path {
            tab.yamlTitle = Self.readDirectoryTitle(at: path)
        }
        persistSession()
        objectWillChange.send()
    }

    func updateProcessTitle(_ title: String, for sessionID: UUID) {
        guard let tab = tabs.first(where: { $0.split.leafIDs.contains(sessionID) }) else { return }
        tab.processTitle = title
        objectWillChange.send()
    }

    static func readDirectoryTitle(at path: String) -> String? {
        guard AppState.shared.config.loadDirectoryConfig else { return nil }
        let dir = URL(fileURLWithPath: path)
        for name in DirectoryConfig.fileNames {
            let file = dir.appendingPathComponent(name)
            if let data = try? Data(contentsOf: file), let text = String(data: data, encoding: .utf8) {
                if let title = DirectoryConfig.title(from: text) { return title }
            }
        }
        return nil
    }
}