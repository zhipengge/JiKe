import AppKit

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    static let shared = StatusItemController()
    private var item: NSStatusItem?

    var isMenuVisible: Bool {
        item?.menu?.supermenu != nil || item?.button?.isHighlighted == true
    }

    func refresh() {
        if AppState.shared.config.showMenuBarIcon {
            if item == nil {
                let created = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                created.button?.image = menuImage()
                created.button?.imagePosition = .imageOnly
                created.button?.toolTip = "即刻 — \(AppState.shared.config.hotkey.displayName) 呼出终端"
                item = created
            }
            item?.menu = buildMenu()
        } else if let item {
            NSStatusBar.system.removeStatusItem(item)
            self.item = nil
        }
    }

    private func menuImage() -> NSImage {
        let image = NSImage(named: "AppLogo") ?? NSImage(systemSymbolName: "terminal", accessibilityDescription: "即刻")
        image?.isTemplate = false
        image?.size = NSSize(width: 18, height: 18)
        return image ?? NSImage()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        let toggle = NSMenuItem(
            title: DropDownWindowController.shared.isOnScreen ? "隐藏终端" : "显示终端",
            action: #selector(Handlers.toggle),
            keyEquivalent: ""
        )
        toggle.target = Handlers.shared
        menu.addItem(toggle)

        let newTab = NSMenuItem(title: "新建标签", action: #selector(Handlers.newTab), keyEquivalent: "d")
        newTab.target = Handlers.shared
        menu.addItem(newTab)

        let closeTab = NSMenuItem(title: "关闭标签", action: #selector(Handlers.closeTab), keyEquivalent: "w")
        closeTab.target = Handlers.shared
        menu.addItem(closeTab)

        let fullscreen = NSMenuItem(title: "最大化 / 全屏", action: #selector(Handlers.fullscreen), keyEquivalent: "f")
        fullscreen.keyEquivalentModifierMask = [.control, .command]
        fullscreen.target = Handlers.shared
        menu.addItem(fullscreen)

        let finder = NSMenuItem(title: "在访达中打开当前目录", action: #selector(Handlers.revealInFinder), keyEquivalent: "e")
        finder.keyEquivalentModifierMask = [.command, .shift]
        finder.target = Handlers.shared
        menu.addItem(finder)

        menu.addItem(.separator())
        let settings = NSMenuItem(title: "设置…", action: #selector(Handlers.settings), keyEquivalent: ",")
        settings.target = Handlers.shared
        menu.addItem(settings)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出即刻", action: #selector(Handlers.quit), keyEquivalent: "q")
        quit.target = Handlers.shared
        menu.addItem(quit)
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.item(at: 0)?.title = DropDownWindowController.shared.isOnScreen ? "隐藏终端" : "显示终端"
    }

    final class Handlers: NSObject {
        static let shared = Handlers()

        @objc func toggle() {
            Task { @MainActor in
                if DropDownWindowController.shared.isOnScreen {
                    AppState.shared.hideDropDown()
                } else {
                    AppState.shared.showDropDown()
                }
            }
        }

        @objc func newTab() {
            Task { @MainActor in
                AppState.shared.newTab(home: false)
                AppState.shared.showDropDown()
            }
        }

        @objc func closeTab() {
            Task { @MainActor in
                if let id = AppState.shared.selectedTabID {
                    AppState.shared.closeTab(id: id)
                }
            }
        }

        @objc func fullscreen() {
            Task { @MainActor in
                AppState.shared.showDropDown()
                AppState.shared.toggleFullscreen()
            }
        }

        @objc func settings() {
            Task { @MainActor in
                SettingsWindowOpener.open()
            }
        }

        @objc func revealInFinder() {
            Task { @MainActor in
                AppState.shared.revealCWDInFinder()
            }
        }

        @objc func quit() {
            Task { @MainActor in
                AppState.shared.persistSession()
                NSApp.terminate(nil)
            }
        }
    }
}
