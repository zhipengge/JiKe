import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    static let identifier = "JiKeSettings"

    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(
                rootView: SettingsView().environmentObject(AppState.shared)
            )
            let window = NSWindow(contentViewController: hosting)
            window.title = "即刻设置"
            window.identifier = NSUserInterfaceItemIdentifier(Self.identifier)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 780, height: 560))
            window.minSize = NSSize(width: 680, height: 480)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        Prefs.revealForSettings()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        Prefs.settingsDidClose()
        if AppState.shared.isDropDownVisible {
            DropDownWindowController.shared.focusTerminal()
        }
    }
}
