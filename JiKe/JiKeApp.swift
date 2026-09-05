import AppKit
import Carbon
import SwiftUI

@main
struct JiKeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(AppState.shared)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("设置…") {
                    SettingsWindowOpener.open()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu("标签") {
                Button("新建标签") {
                    AppState.shared.newTab(home: false)
                    AppState.shared.showDropDown()
                }
                .keyboardShortcut("d", modifiers: .command)
                Button("在主目录新建标签") {
                    AppState.shared.newTab(home: true)
                    AppState.shared.showDropDown()
                }
                .keyboardShortcut("h", modifiers: [.control, .shift])
                Button("关闭标签") {
                    if let id = AppState.shared.selectedTabID {
                        AppState.shared.closeTab(id: id)
                    }
                }
                .keyboardShortcut("w", modifiers: [.control, .shift])
                Button("重命名标签…") {
                    AppState.shared.showDropDown()
                    RenameTabPrompt.present()
                }
                .keyboardShortcut("r", modifiers: [.control, .shift])
                Divider()
                Button("上一个标签") {
                    AppState.shared.selectTab(offset: -1)
                }
                Button("下一个标签") {
                    AppState.shared.selectTab(offset: 1)
                }
            }
            CommandGroup(after: .windowArrangement) {
                Divider()
                Button("显示 / 隐藏终端") {
                    if DropDownWindowController.shared.isOnScreen {
                        AppState.shared.hideDropDown()
                    } else {
                        AppState.shared.showDropDown()
                    }
                }
                Button("最大化 / 全屏") {
                    AppState.shared.maximizeFromGlobalHotkey()
                }
                .keyboardShortcut("f", modifiers: [.control, .command])
                Button("最大化 / 全屏") {
                    AppState.shared.maximizeFromGlobalHotkey()
                }
                .keyboardShortcut(KeyEquivalent(Character(UnicodeScalar(NSF11FunctionKey)!)), modifiers: [])
                Button("在访达中打开当前目录") {
                    AppState.shared.revealCWDInFinder()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.applyActivationPolicy()
        DropDownWindowController.shared.configure()
        StatusItemController.shared.refresh()
        HotkeyManager.shared.onToggle = {
            Task { @MainActor in
                AppState.shared.toggleDropDown()
            }
        }
        HotkeyManager.shared.onMaximize = {
            Task { @MainActor in
                AppState.shared.maximizeFromGlobalHotkey()
            }
        }
        HotkeyManager.shared.register(AppState.shared.config.hotkey)
        LoginItemManager.sync(enabled: AppState.shared.config.launchAtLogin)
        KeybindMonitor.shared.start()
        if AppState.shared.config.startFullscreen {
            AppState.shared.isFullscreen = true
        }

        NSApp.servicesProvider = self
        closeSwiftUIPlaceholderWindows()

        if !UserDefaults.standard.bool(forKey: SharedConstants.firstLaunchKey) {
            UserDefaults.standard.set(true, forKey: SharedConstants.firstLaunchKey)
        }
        AppState.shared.showDropDown()

        runStartupScriptIfNeeded()
        AppState.shared.persistSession()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard DropDownWindowController.shared.isOnScreen, !Prefs.settingsOpen, !AppState.shared.findVisible else { return }
        DropDownWindowController.shared.focusTerminal()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in
            AppState.shared.showDropDown()
        }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            Task { @MainActor in
                AppState.shared.apply(JiKeCommand.parse(url: url))
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            AppState.shared.persistSession()
        }
        HotkeyManager.shared.unregister()
    }

    private func closeSwiftUIPlaceholderWindows() {
        DispatchQueue.main.async {
            for window in NSApp.windows {
                if window is DropDownPanel { continue }
                let id = window.identifier?.rawValue
                if id == SettingsWindowController.identifier || id == "com.apple.SwiftUI.Settings" {
                    continue
                }
                if window.frame.width <= 2 || window.title.isEmpty {
                    window.orderOut(nil)
                }
            }
        }
    }

    private func runStartupScriptIfNeeded() {
        let path = AppState.shared.config.startupScriptPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", ShellQuote.single(path)]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}

enum Prefs {
    static var settingsOpen = false

    @MainActor
    static func applyActivationPolicy() {
        if settingsOpen {
            NSApp.setActivationPolicy(.regular)
            return
        }
        let showDock = AppState.shared.config.showDockIcon
        NSApp.setActivationPolicy(showDock ? .regular : .accessory)
    }

    @MainActor
    static func revealForSettings() {
        settingsOpen = true
        applyActivationPolicy()
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    static func settingsDidClose() {
        settingsOpen = false
        applyActivationPolicy()
    }
}

enum SettingsWindowOpener {
    @MainActor
    static func open() {
        SettingsWindowController.shared.show()
    }
}