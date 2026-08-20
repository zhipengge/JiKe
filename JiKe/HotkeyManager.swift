import Carbon
import Foundation

final class HotkeyManager {
    static let shared = HotkeyManager()

    var onPressed: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func register(_ spec: GtkAccelerator) {
        unregister()
        guard !spec.isUnbound else { return }
        let hotKeyID = EventHotKeyID(signature: OSType(0x4A694B65), id: 1)
        let status = RegisterEventHotKey(
            spec.keyCode,
            spec.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            jikeHotKeyCallback,
            1,
            &eventType,
            nil,
            &handlerRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    fileprivate func handlePress() {
        onPressed?()
    }
}

private func jikeHotKeyCallback(
    nextHandler: EventHandlerCallRef?,
    theEvent: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    HotkeyManager.shared.handlePress()
    return noErr
}