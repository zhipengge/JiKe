import AppKit
import SwiftUI

final class DropDownPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func becomeKey() {
        super.becomeKey()
        Task { @MainActor in
            TerminalSessionCache.shared.focus(AppState.shared.selectedTab?.focusedSessionID)
        }
    }
}

@MainActor
final class DropDownWindowController: NSObject, NSWindowDelegate {
    static let shared = DropDownWindowController()

    private var panel: DropDownPanel?
    private var hosting: NSHostingView<AnyView>?
    private var resizing = false
    /// 滑出过程中会短暂失焦，不能因此立刻收起。
    private var isPresenting = false

    /// 窗口是否真的在某块屏幕上（不是停在屏幕外或 orderOut）。
    var isOnScreen: Bool {
        guard let panel, panel.isVisible else { return false }
        return NSScreen.screens.contains { $0.frame.intersects(panel.frame) }
    }

    func configure() {
        if panel != nil { return }
        let panel = DropDownPanel(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        // isFloatingPanel 会把 becomesKeyOnlyIfNeeded 设成 true，不点一下就变不成 key window，光标进不了 PTY。
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = Self.windowLevel(stayOnTop: AppState.shared.config.stayOnTop)
        // canJoinAllSpaces 与 moveToActiveSpace 不能一起用，否则窗口会跑丢。
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.acceptsMouseMovedEvents = true
        panel.title = SharedConstants.displayName
        panel.identifier = NSUserInterfaceItemIdentifier("JiKeDropDown")

        let root = DropDownContentView()
            .environmentObject(AppState.shared)
        let hosting = NSHostingView(rootView: AnyView(root))
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = CGColor.clear
        panel.contentView = hosting

        self.panel = panel
        self.hosting = hosting
        panel.setFrame(hiddenFrame(), display: false)
    }

    func show() {
        configure()
        guard let panel else { return }
        isPresenting = true
        applyLevel()
        let hidden = hiddenFrame()
        let shown = visibleFrame()
        if !panel.isVisible || !isOnScreen {
            panel.setFrame(hidden, display: false)
        }
        // 不要用 popUpMenu 层级：状态栏菜单会把它当菜单关掉。
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        AppState.shared.isDropDownVisible = true
        HotkeyManager.shared.setSystemHotkeysSuppressed(true)

        let duration = AppState.shared.config.animationDuration
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(shown, display: true)
        } completionHandler: {
            Task { @MainActor in
                self.isPresenting = false
                AppState.shared.isDropDownVisible = true
                self.focusTerminal()
            }
        }
    }

    func focusTerminal() {
        guard let panel, panel.isVisible else { return }
        if !panel.isKeyWindow {
            panel.makeKeyAndOrderFront(nil)
        }
        TerminalSessionCache.shared.focus(AppState.shared.selectedTab?.focusedSessionID)
    }

    func hide() {
        isPresenting = false
        HotkeyManager.shared.setSystemHotkeysSuppressed(false)
        guard let panel, panel.isVisible else {
            AppState.shared.isDropDownVisible = false
            return
        }
        let hidden = hiddenFrame()
        let duration = AppState.shared.config.animationDuration
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(hidden, display: true)
        } completionHandler: {
            panel.orderOut(nil)
            Task { @MainActor in
                AppState.shared.isDropDownVisible = false
            }
        }
    }

    func applyLevel() {
        panel?.level = Self.windowLevel(stayOnTop: AppState.shared.config.stayOnTop)
    }

    /// 状态栏菜单层级（25）。更高的 popUpMenu 会被菜单栏点击直接关掉，终端就「点了不显示」。
    static func windowLevel(stayOnTop: Bool) -> NSWindow.Level {
        stayOnTop ? .statusBar : .normal
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !isPresenting else { return }
        guard AppState.shared.config.hideOnLoseFocus else { return }
        DispatchQueue.main.async {
            if self.isPresenting || Prefs.settingsOpen { return }
            if StatusItemController.shared.isMenuVisible { return }
            let keyID = NSApp.keyWindow?.identifier?.rawValue
            if keyID == SettingsWindowController.identifier || keyID == "com.apple.SwiftUI.Settings" {
                return
            }
            if keyID == "JiKeDropDown" { return }
            self.hide()
        }
    }

    func updateFrameForConfig() {
        guard let panel, AppState.shared.isDropDownVisible || isOnScreen else { return }
        panel.setFrame(visibleFrame(), display: true)
    }

    func beginResize(at locationInWindow: CGPoint) {
        resizing = true
    }

    func resize(to locationInScreen: CGPoint) {
        guard resizing, let screen = targetScreen() else { return }
        let work = screen.visibleFrame
        let newHeight = max(80, work.maxY - locationInScreen.y)
        let percent = WindowGeometry.clampedHeightPercent(Double(newHeight / work.height * 100))
        var config = AppState.shared.config
        config.windowHeightPercent = percent
        AppState.shared.config = config
        updateFrameForConfig()
    }

    func endResize() {
        resizing = false
    }

    private func targetScreen() -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        let mouse = NSEvent.mouseLocation
        let mouseIndex = screens.firstIndex { NSMouseInRect(mouse, $0.frame, false) } ?? 0
        let primaryIndex = screens.firstIndex(of: NSScreen.main ?? screens[0]) ?? 0
        let resolved = MonitorPreference.resolvedIndex(
            preference: AppState.shared.config.monitor,
            mouseScreenIndex: mouseIndex,
            primaryIndex: primaryIndex,
            count: screens.count
        )
        return screens[resolved]
    }

    private func visibleFrame() -> CGRect {
        frame(visible: true)
    }

    private func hiddenFrame() -> CGRect {
        frame(visible: false)
    }

    private func frame(visible: Bool) -> CGRect {
        let screen = targetScreen()?.visibleFrame ?? CGRect(x: 0, y: 0, width: 800, height: 600)
        let config = AppState.shared.config
        let full = AppState.shared.isFullscreen
        return WindowGeometry.frame(
            screen: screen,
            heightPercent: full ? 100 : config.windowHeightPercent,
            widthPercent: full ? 100 : config.windowWidthPercent,
            horizontalAlignment: full ? .center : config.horizontalAlignment,
            verticalAlignment: config.verticalAlignment,
            displacementX: full ? 0 : config.displacementX,
            displacementY: full ? 0 : config.displacementY,
            visible: visible
        )
    }
}
