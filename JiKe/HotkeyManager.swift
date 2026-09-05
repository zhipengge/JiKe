import Carbon
import Foundation

final class HotkeyManager {
    static let shared = HotkeyManager()

    static let signature: OSType = 0x4A694B65 // 'JiKe'
    static let toggleID: UInt32 = 1
    static let maximizeID: UInt32 = 2
    static let toggleAliasID: UInt32 = 3
    static let maximizeAliasID: UInt32 = 4

    static let toggleAlias = GtkAccelerator(gtk: "<Super>F12")
    static let maximizeKey = GtkAccelerator(gtk: "F11")
    static let maximizeAlias = GtkAccelerator(gtk: "<Super>F11")

    var onToggle: (() -> Void)?
    var onMaximize: (() -> Void)?

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlerRef: EventHandlerRef?
    private var symbolicHotKeyToken: UnsafeMutableRawPointer?

    func register(_ spec: GtkAccelerator) {
        clearHotKeys()
        if handlerRef == nil {
            installHandler()
        }
        bind(id: Self.toggleID, spec: spec)
        if !sameKey(spec, Self.toggleAlias) {
            bind(id: Self.toggleAliasID, spec: Self.toggleAlias)
        }
        if !sameKey(spec, Self.maximizeKey) {
            bind(id: Self.maximizeID, spec: Self.maximizeKey)
        }
        if !sameKey(spec, Self.maximizeAlias) {
            bind(id: Self.maximizeAliasID, spec: Self.maximizeAlias)
        }
    }

    func unregister() {
        setSystemHotkeysSuppressed(false)
        clearHotKeys()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    /// 终端显示时关掉系统「显示桌面」等符号热键，否则 Fn+F11 到不了即刻。
    func setSystemHotkeysSuppressed(_ suppressed: Bool) {
        if suppressed {
            guard symbolicHotKeyToken == nil else { return }
            symbolicHotKeyToken = PushSymbolicHotKeyMode(OptionBits(kHIHotKeyModeAllDisabled))
        } else if let symbolicHotKeyToken {
            PopSymbolicHotKeyMode(symbolicHotKeyToken)
            self.symbolicHotKeyToken = nil
        }
    }

    fileprivate func handlePress(id: UInt32) {
        switch id {
        case Self.maximizeID, Self.maximizeAliasID:
            onMaximize?()
        case Self.toggleID, Self.toggleAliasID:
            onToggle?()
        default:
            break
        }
    }

    private func sameKey(_ a: GtkAccelerator, _ b: GtkAccelerator) -> Bool {
        a.keyCode == b.keyCode && a.carbonModifiers == b.carbonModifiers
    }

    private func clearHotKeys() {
        for ref in refs.values {
            UnregisterEventHotKey(ref)
        }
        refs.removeAll()
    }

    private func bind(id: UInt32, spec: GtkAccelerator) {
        guard !spec.isUnbound else { return }
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(
            spec.keyCode,
            spec.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            refs[id] = ref
        }
    }

    private func installHandler() {
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
}

private func jikeHotKeyCallback(
    nextHandler: EventHandlerCallRef?,
    theEvent: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    guard let theEvent else { return OSStatus(eventNotHandledErr) }
    let err = GetEventParameter(
        theEvent,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard err == noErr, hotKeyID.signature == HotkeyManager.signature else {
        return OSStatus(eventNotHandledErr)
    }
    HotkeyManager.shared.handlePress(id: hotKeyID.id)
    return noErr
}
