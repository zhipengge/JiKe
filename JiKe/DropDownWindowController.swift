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
        panel.level = AppState.shared.config.stayOnTop ? .statusBar : .normal
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
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
        applyLevel()
        let hidden = hiddenFrame()
        let shown = visibleFrame()
        if !panel.isVisible {
            panel.setFrame(hidden, display: true)
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        focusTerminal()
        let duration = AppState.shared.config.animationDuration
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(shown, display: true)
        } completionHandler: {
            Task { @MainActor in
                AppState.shared.isDropDownVisible = true
                DropDownWindowController.shared.focusTerminal()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    DropDownWindowController.shared.focusTerminal()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    DropDownWindowController.shared.focusTerminal()
                }
            }
        }
    }

    func focusTerminal() {
        guard let panel else { return }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        TerminalSessionCache.shared.focus(AppState.shared.selectedTab?.focusedSessionID)
    }

    func hide() {
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
        panel?.level = AppState.shared.config.stayOnTop ? .statusBar : .normal
    }

    func windowDidResignKey(_ notification: Notification) {
        guard AppState.shared.config.hideOnLoseFocus else { return }
        DispatchQueue.main.async {
            if Prefs.settingsOpen { return }
            let keyID = NSApp.keyWindow?.identifier?.rawValue
            if keyID == SettingsWindowController.identifier || keyID == "com.apple.SwiftUI.Settings" {
                return
            }
            self.hide()
        }
    }

    func updateFrameForConfig() {
        guard let panel, AppState.shared.isDropDownVisible else { return }
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