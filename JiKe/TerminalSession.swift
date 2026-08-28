import AppKit
import Darwin
import Foundation
import SwiftTerm
import UniformTypeIdentifiers

@MainActor
final class TerminalSessionCache {
    static let shared = TerminalSessionCache()

    private var views: [UUID: EmbeddedTerminalView] = [:]

    func view(for sessionID: UUID, tabID: UUID, workingDirectory: String?) -> EmbeddedTerminalView {
        if let existing = views[sessionID] {
            return existing
        }
        let view = EmbeddedTerminalView(sessionID: sessionID, tabID: tabID, workingDirectory: workingDirectory)
        views[sessionID] = view
        return view
    }

    func terminate(_ sessionID: UUID) {
        views[sessionID]?.terminateProcess()
        views[sessionID]?.removeFromSuperview()
        views.removeValue(forKey: sessionID)
    }

    func focus(_ sessionID: UUID?) {
        guard let sessionID, let view = views[sessionID] else { return }
        if let window = view.window {
            window.makeKeyAndOrderFront(nil)
            _ = window.makeFirstResponder(view)
        }
        _ = view.becomeFirstResponder()
    }

    func copyFocused() {
        guard let id = AppState.shared.selectedTab?.focusedSessionID else { return }
        let text = selectedText(id)
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func pasteFocused() {
        guard let id = AppState.shared.selectedTab?.focusedSessionID else { return }
        views[id]?.pasteFromMacPasteboard()
    }

    func selectAllFocused() {
        guard let id = AppState.shared.selectedTab?.focusedSessionID else { return }
        views[id]?.selectAll(nil)
    }

    func send(_ sessionID: UUID, text: String) {
        views[sessionID]?.send(txt: text)
    }

    func exportText(_ sessionID: UUID) -> String {
        views[sessionID]?.exportBufferText() ?? ""
    }

    func applyAppearance(config: AppConfig) {
        for view in views.values {
            view.applyAppearance(config: config, force: false)
        }
    }

    func forceApplyAppearance(config: AppConfig) {
        for view in views.values {
            view.applyAppearance(config: config, force: true)
        }
    }

    func selectedText(_ sessionID: UUID) -> String {
        views[sessionID]?.selectedText() ?? ""
    }

    func reset(_ sessionID: UUID) {
        views[sessionID]?.resetTerminal()
    }
}

final class EmbeddedTerminalView: TerminalView, TerminalViewDelegate, LocalProcessDelegate {
    let sessionID: UUID
    let tabID: UUID
    private var workingDirectory: String?
    private var process: LocalProcess!
    private var restarting = false
    private var mouseMonitor: Any?
    private var appliedAppearance: AppearanceSnapshot?

    init(sessionID: UUID, tabID: UUID, workingDirectory: String?) {
        self.sessionID = sessionID
        self.tabID = tabID
        self.workingDirectory = workingDirectory
        super.init(frame: .zero)
        terminalDelegate = self
        process = LocalProcess(delegate: self)
        autoresizingMask = [.width, .height]
        applyAppearance(config: AppState.shared.config)
        installMouseMonitor()
        registerForDraggedTypes([.fileURL])
        startShell()
    }

    deinit {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startShell() {
        let config = AppState.shared.config
        let shell = config.shellPath.isEmpty
            ? (ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh")
            : config.shellPath
        let launch = ShellLaunch.arguments(
            shellPath: shell,
            login: config.loginShell,
            workingDirectory: workingDirectory
        )
        var environment = ProcessInfo.processInfo.environment
        environment[SharedConstants.tabUUIDEnvironmentKey] = tabID.uuidString
        environment[SharedConstants.tabUUIDAliasKey] = tabID.uuidString
        environment["TERM"] = "xterm-256color"
        environment["TERM_PROGRAM"] = "jike"
        environment["COLORTERM"] = "truecolor"
        environment = TerminalProcessEnvironment.applying(
            to: environment,
            localeIdentifier: Locale.current.identifier,
            processLANG: ProcessInfo.processInfo.environment["LANG"]
        )
        environment["PATH"] = UserPath.resolved(current: environment["PATH"])
        let envList = environment.map { "\($0.key)=\($0.value)" }
        restarting = true
        process.startProcess(executable: launch.executable, args: launch.args, environment: envList, execName: launch.execName)
    }

    func terminateProcess() {
        restarting = false
        if process.running {
            process.terminate()
        }
    }

    override var isOpaque: Bool { false }

    func applyAppearance(config: AppConfig, force: Bool = false) {
        let snapshot = AppearanceSnapshot(config)
        if !force, appliedAppearance == snapshot { return }

        let fontChanged = appliedAppearance.map {
            $0.fontName != snapshot.fontName || abs($0.fontSize - snapshot.fontSize) > 0.05
        } ?? true
        appliedAppearance = snapshot

        if fontChanged {
            font = TerminalFont.resolve(name: config.fontName, size: CGFloat(config.fontSize))
        }

        let palette = config.palette
        let alpha = WindowGeometry.backgroundAlpha(config.transparency)
        let bg = Self.nsColor(palette.background, alpha: alpha)
        let fg = Self.nsColor(palette.foreground, alpha: 1)
        // 必须先改 native 前景/背景，再 installColors：后者会清属性缓存并立刻重绘，
        // 若顺序反了，缓存里仍是旧颜色，看起来就像配色没生效。
        nativeBackgroundColor = bg
        nativeForegroundColor = fg
        caretColor = fg
        layer?.isOpaque = false
        layer?.backgroundColor = bg.cgColor

        let colors = palette.ansi.map { hex -> SwiftTerm.Color in
            let rgb = TerminalPalette.rgb(hex)
            return SwiftTerm.Color(
                red: UInt16(rgb.0 * 65535),
                green: UInt16(rgb.1 * 65535),
                blue: UInt16(rgb.2 * 65535)
            )
        }
        if colors.count == 16 {
            installColors(colors)
        }
        nativeBackgroundColor = bg
        nativeForegroundColor = fg
        layer?.backgroundColor = bg.cgColor

        optionAsMetaKey = config.optionAsMeta
        switch config.cursorShape {
        case .block: getTerminal().setCursorStyle(.steadyBlock)
        case .ibeam: getTerminal().setCursorStyle(.steadyBar)
        case .underline: getTerminal().setCursorStyle(.steadyUnderline)
        }
        getTerminal().updateFullScreen()
        needsDisplay = true
    }

    func resetTerminal() {
        getTerminal().resetToInitialState()
        needsDisplay = true
    }

    func exportBufferText() -> String {
        let data = getTerminal().getBufferAsData()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .newlines) ?? ""
    }

    func selectedText() -> String {
        getSelection() ?? ""
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func pasteFromMacPasteboard() {
        let pasteboard = NSPasteboard.general
        if let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] {
            let paths = urls.filter(\.isFileURL).map(\.path)
            if !paths.isEmpty {
                send(txt: MacPasteInsertion.text(filePaths: paths, fallback: nil))
                return
            }
        }
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            send(txt: text)
        }
    }

    func insertDroppedPaths(_ paths: [String]) {
        send(txt: MacPasteInsertion.text(filePaths: paths, fallback: nil) + " ")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        canAcceptFiles(sender) ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        canAcceptFiles(sender) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        let paths = urls.filter(\.isFileURL).map(\.path)
        guard !paths.isEmpty else { return false }
        send(txt: MacPasteInsertion.text(filePaths: paths, fallback: nil) + " ")
        window?.makeFirstResponder(self)
        return true
    }

    private func canAcceptFiles(_ sender: NSDraggingInfo) -> Bool {
        sender.draggingPasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
    }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        guard process.running else { return }
        var size = getWindowSize()
        _ = PseudoTerminalHelpers.setWinSize(masterPtyDescriptor: process.childfd, windowSize: &size)
    }

    func setTerminalTitle(source: TerminalView, title: String) {
        Task { @MainActor in
            AppState.shared.updateProcessTitle(title, for: sessionID)
        }
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        let path = directory.flatMap { url -> String? in
            if url.hasPrefix("file://"), let parsed = URL(string: url) {
                return parsed.path
            }
            return url
        }
        workingDirectory = path
        Task { @MainActor in
            AppState.shared.updateDirectory(path, for: sessionID)
        }
    }

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        process.send(data: data)
    }

    func scrolled(source: TerminalView, position: Double) {}

    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        if let url = URL(string: link) {
            NSWorkspace.shared.open(url)
        }
    }

    func bell(source: TerminalView) {
        let hidden = !AppState.shared.isDropDownVisible || window?.isKeyWindow != true
        if AppState.shared.config.playBell {
            NSSound.beep()
            if hidden {
                NSApp.requestUserAttention(.informationalRequest)
            }
        }
    }

    func clipboardCopy(source: TerminalView, content: Data) {
        if let text = String(data: content, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}

    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}

    func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        guard restarting else { return }
        restarting = false
        let id = sessionID
        Task { @MainActor in
            AppState.shared.closeSession(id)
        }
    }

    func dataReceived(slice: ArraySlice<UInt8>) {
        feed(byteArray: slice)
    }

    func getWindowSize() -> winsize {
        let frame = self.frame
        let term = getTerminal()
        return winsize(
            ws_row: UInt16(term.rows),
            ws_col: UInt16(term.cols),
            ws_xpixel: UInt16(frame.width),
            ws_ypixel: UInt16(frame.height)
        )
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        TerminalContextMenu.build(sessionID: sessionID, selected: selectedText())
    }

    /// SwiftTerm 把 `mouseDown` 标成 `public override` 而不是 `open`，外部模块无法再 override。
    /// 用本地事件监视补上 Command-点击快速打开、点选聚焦、选中即复制。
    private func installMouseMonitor() {
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            guard let self else { return event }
            return self.handleMouse(event)
        }
    }

    private func handleMouse(_ event: NSEvent) -> NSEvent? {
        guard event.window === window else { return event }
        let location = convert(event.locationInWindow, from: nil)
        guard bounds.contains(location) else { return event }

        if event.type == .leftMouseDown {
            Task { @MainActor in
                if let tab = AppState.shared.tabs.first(where: { $0.split.leafIDs.contains(self.sessionID) }) {
                    tab.focusedSessionID = self.sessionID
                }
            }
            if event.modifierFlags.contains(.command) {
                let text = selectedText()
                if QuickOpenActions.open(text: text) {
                    return nil
                }
                if let url = LinkDetector.firstURL(in: text) {
                    NSWorkspace.shared.open(url)
                    return nil
                }
            }
        }

        if event.type == .leftMouseUp, AppState.shared.config.copyOnSelect {
            DispatchQueue.main.async { [weak self] in
                guard let selected = self?.getSelection(), !selected.isEmpty else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(selected, forType: .string)
            }
        }
        return event
    }

    private static func nsColor(_ hex: String, alpha: Double) -> NSColor {
        let rgb = TerminalPalette.rgb(hex)
        return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: CGFloat(alpha))
    }
}

@MainActor
enum QuickOpenActions {
    @discardableResult
    static func open(text: String) -> Bool {
        guard AppState.shared.config.quickOpenEnabled else { return false }
        guard let target = QuickOpenParser.firstMatch(text) else { return false }
        let expanded = NSString(string: target.path).expandingTildeInPath
        let patched = QuickOpenTarget(path: expanded, line: target.line, column: target.column, source: target.source)
        let template = AppState.shared.config.quickOpenCommandLine
        let command = QuickOpenParser.expandCommand(template, target: patched)
        if AppState.shared.config.quickOpenInCurrentTerminal {
            AppState.shared.sendToFocused(command.hasSuffix("\n") ? command : command + "\n")
            return true
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        try? process.run()
        return true
    }
}

@MainActor
enum TerminalContextMenu {
    static func build(sessionID: UUID, selected: String) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(.separator())
        add(menu, title: "垂直分屏") {
            AppState.shared.splitFocused(.vertical)
        }
        add(menu, title: "水平分屏") {
            AppState.shared.splitFocused(.horizontal)
        }
        add(menu, title: "关闭当前分屏") {
            AppState.shared.closeCurrentPane()
        }
        menu.addItem(.separator())
        add(menu, title: "新建标签") {
            AppState.shared.newTab(home: false)
        }
        add(menu, title: "重命名标签…") {
            RenameTabPrompt.present()
        }
        menu.addItem(.separator())
        if let url = LinkDetector.firstURL(in: selected) {
            add(menu, title: "打开链接") {
                NSWorkspace.shared.open(url)
            }
        }
        if AppState.shared.config.quickOpenEnabled, QuickOpenParser.firstMatch(selected) != nil {
            add(menu, title: "快速打开") {
                QuickOpenActions.open(text: selected)
            }
        }
        if !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            add(menu, title: "在网页搜索") {
                if let url = AppState.shared.config.searchEngine.searchURL(
                    query: selected,
                    customURL: AppState.shared.config.customSearchEngineURL
                ) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        menu.addItem(.separator())
        add(menu, title: "在访达中打开当前目录") {
            AppState.shared.revealCWDInFinder()
        }
        add(menu, title: "保存输出…") {
            SaveOutputPrompt.present(text: TerminalSessionCache.shared.exportText(sessionID))
        }
        let commands = AppState.shared.config.customCommands
        if !commands.isEmpty {
            menu.addItem(.separator())
            for command in commands {
                add(menu, title: command.name) {
                    AppState.shared.runCustomCommand(command)
                }
            }
        }
        let file = AppState.shared.config.customCommandFile.trimmingCharacters(in: .whitespaces)
        if !file.isEmpty {
            let expanded = (file as NSString).expandingTildeInPath
            if let json = try? String(contentsOfFile: expanded, encoding: .utf8) {
                let leaves = GuakeCustomCommandsFile.leaves(json: json)
                if !leaves.isEmpty {
                    menu.addItem(.separator())
                    for leaf in leaves {
                        add(menu, title: leaf.name) {
                            AppState.shared.runCustomCommand(CustomCommand(name: leaf.name, command: leaf.command))
                        }
                    }
                }
            }
        }
        return menu
    }

    private static func add(_ menu: NSMenu, title: String, handler: @escaping () -> Void) {
        let item = NSMenuItem(title: title, action: #selector(MenuTrampoline.run(_:)), keyEquivalent: "")
        let trampoline = MenuTrampoline(handler: handler)
        item.target = trampoline
        objc_setAssociatedObject(item, &MenuTrampoline.assoc, trampoline, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        menu.addItem(item)
    }
}

final class MenuTrampoline: NSObject {
    static var assoc: UInt8 = 0
    let handler: () -> Void
    init(handler: @escaping () -> Void) { self.handler = handler }
    @objc func run(_ sender: Any?) {
        Task { @MainActor in
            handler()
        }
    }
}

@MainActor
enum RenameTabPrompt {
    static func present() {
        let alert = NSAlert()
        alert.messageText = "重命名标签"
        alert.informativeText = "留空则恢复自动标题（当前目录 / 进程名 / .jike.yml）。"
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        let field = NSTextField(string: AppState.shared.selectedTab?.customTitle ?? "")
        field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        alert.accessoryView = field
        if alert.runModal() == .alertFirstButtonReturn {
            AppState.shared.renameSelectedTab(field.stringValue)
        }
    }
}

@MainActor
enum SaveOutputPrompt {
    static func present(text: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "jike-output.txt"
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}