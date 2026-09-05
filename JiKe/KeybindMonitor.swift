import AppKit
import Carbon

@MainActor
final class KeybindMonitor {
    static let shared = KeybindMonitor()
    /// 设置页正在录制快捷键时，不要抢走按键。
    static var isCapturing = false
    private var monitor: Any?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if self.handle(event) {
                return nil
            }
            return event
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        if Self.isCapturing { return false }
        let flags = UInt(event.modifierFlags.rawValue)
        let key = event.keyCode

        if isMaximizeKey(keyCode: key, nsModifiers: flags) {
            AppState.shared.maximizeFromGlobalHotkey()
            return true
        }
        if isShowHideKey(keyCode: key, nsModifiers: flags) {
            AppState.shared.toggleDropDown()
            return true
        }

        for extra in GuakeKeybindings.macOSExtras where extra.id == "open-settings" {
            if GuakeKeybindings.match(keyCode: key, nsModifiers: flags, against: extra.gtk) {
                return perform(extra.id)
            }
        }

        guard AppState.shared.isDropDownVisible else { return false }
        let bindings = AppState.shared.config.keybindings

        func hit(_ name: String) -> Bool {
            guard let gtk = bindings[name] ?? GuakeKeybindings.localDefaults[name] else { return false }
            return GuakeKeybindings.match(keyCode: key, nsModifiers: flags, against: gtk)
        }

        for spec in GuakeKeybindings.catalog where hit(spec.id) {
            return perform(spec.id)
        }
        for extra in GuakeKeybindings.macOSExtras {
            if GuakeKeybindings.match(keyCode: key, nsModifiers: flags, against: extra.gtk) {
                return perform(extra.id)
            }
        }

        if key == UInt16(kVK_Escape), AppState.shared.findVisible {
            AppState.shared.findVisible = false
            return true
        }
        return false
    }

    private func isMaximizeKey(keyCode: UInt16, nsModifiers: UInt) -> Bool {
        guard keyCode == UInt16(kVK_F11) else { return false }
        let mods = nsModifiers & GtkAccelerator.nsMatchingMask
        return mods == 0 || mods == GtkAccelerator.nsCommand
    }

    /// 配置的呼出键，以及 Cmd+F12（有人按这个而不是 Fn+F12）。
    private func isShowHideKey(keyCode: UInt16, nsModifiers: UInt) -> Bool {
        let configured = AppState.shared.config.hotkey
        if GuakeKeybindings.match(keyCode: keyCode, nsModifiers: nsModifiers, against: configured.gtk) {
            return true
        }
        return GuakeKeybindings.match(
            keyCode: keyCode,
            nsModifiers: nsModifiers,
            against: HotkeyManager.toggleAlias.gtk
        )
    }

    @discardableResult
    func perform(_ id: String) -> Bool {
        let state = AppState.shared
        switch id {
        case "search-terminal":
            state.findVisible.toggle()
        case "quit":
            state.requestQuit()
        case "new-tab":
            state.newTab(home: false)
        case "new-tab-home":
            state.newTab(home: true)
        case "new-tab-cwd":
            state.newTab(home: false)
        case "close-tab":
            state.closeTab(id: state.selectedTabID ?? UUID())
        case "search-on-web":
            state.searchOnWeb()
        case "open-link-under-terminal-cursor":
            let text = state.selectedTab.flatMap { TerminalSessionCache.shared.selectedText($0.focusedSessionID) } ?? ""
            if let url = LinkDetector.firstURL(in: text) { NSWorkspace.shared.open(url) }
        case "move-tab-left":
            state.moveTab(offset: -1)
        case "move-tab-right":
            state.moveTab(offset: 1)
        case "previous-tab", "previous-tab-alt":
            state.selectTab(offset: -1)
        case "next-tab", "next-tab-alt":
            state.selectTab(offset: 1)
        case "switch-tab1", "switch-tab2", "switch-tab3", "switch-tab4", "switch-tab5",
             "switch-tab6", "switch-tab7", "switch-tab8", "switch-tab9", "switch-tab10":
            if let number = Int(id.replacingOccurrences(of: "switch-tab", with: "")) {
                state.selectTab(number: number)
            }
        case "switch-tab-last":
            if let last = state.tabs.last { state.selectedTabID = last.id }
        case "rename-current-tab":
            RenameTabPrompt.present()
        case "zoom-in", "zoom-in-alt":
            state.changeFont(delta: 1)
        case "zoom-out":
            state.changeFont(delta: -1)
        case "increase-height":
            state.changeHeight(delta: 2)
        case "decrease-height":
            state.changeHeight(delta: -2)
        case "increase-transparency":
            state.changeTransparency(delta: -2)
        case "decrease-transparency":
            state.changeTransparency(delta: 2)
        case "toggle-transparency":
            state.toggleTransparency()
        case "toggle-fullscreen":
            state.toggleFullscreen()
        case "toggle-hide-on-lose-focus":
            state.config.hideOnLoseFocus.toggle()
        case "split-tab-vertical":
            state.splitFocused(.vertical)
        case "split-tab-horizontal":
            state.splitFocused(.horizontal)
        case "close-terminal":
            state.closeCurrentPane()
        case "focus-terminal-up", "focus-terminal-left":
            state.moveFocus(.previous)
        case "focus-terminal-down", "focus-terminal-right":
            state.moveFocus(.next)
        case "clipboard-copy":
            TerminalSessionCache.shared.copyFocused()
        case "clipboard-paste":
            TerminalSessionCache.shared.pasteFocused()
        case "select-all":
            TerminalSessionCache.shared.selectAllFocused()
        case "reset-terminal":
            if let id = state.selectedTab?.focusedSessionID {
                TerminalSessionCache.shared.reset(id)
            }
        case "reveal-in-finder":
            state.revealCWDInFinder()
        case "open-settings":
            SettingsWindowOpener.open()
        default:
            return false
        }
        return true
    }
}
