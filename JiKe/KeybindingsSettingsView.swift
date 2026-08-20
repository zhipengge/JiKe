import AppKit
import SwiftUI

struct KeybindingsSettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Form {
            Section("全局（即使终端没收起也能用）") {
                HotkeyRow(title: "呼出 / 收起", gtk: globalHotkeyBinding)
                Text("默认 F12。笔记本请按 Fn+F12。系统「显示桌面」若占用 F11，最大化请用 Ctrl+Cmd+F。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(GuakeKeybindings.catalogSections, id: \.self) { section in
                Section(section) {
                    ForEach(GuakeKeybindings.catalog.filter { $0.section == section }, id: \.id) { spec in
                        HotkeyRow(title: spec.title, gtk: binding(for: spec.id))
                    }
                }
            }
            Section("macOS 额外快捷键（始终可用）") {
                ForEach(Array(GuakeKeybindings.macOSExtras.enumerated()), id: \.offset) { _, extra in
                    LabeledContent(extra.title, value: GtkAccelerator(gtk: extra.gtk).displayName)
                }
                Text("Guake 原键 Ctrl+Shift+T / Ctrl+Shift+W / F11 仍然有效。F11 常被系统占用，所以加了这些 Mac 常用键。Cmd+C 只在有选区时拷贝，不会清空剪贴板。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("关闭当前标签 / 分屏", value: "Ctrl+D 或 exit")
                Text("Ctrl+D 仍发给 Shell（空提示符时退出）。进程结束后即刻关掉该分屏；只剩一个分屏时关掉标签。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("恢复默认快捷键") {
                    var copy = state.config
                    copy.hotkey = GuakeKeybindings.showHide
                    copy.keybindings = GuakeKeybindings.localDefaults
                    state.config = copy
                    HotkeyManager.shared.register(copy.hotkey)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var globalHotkeyBinding: Binding<String> {
        Binding(
            get: { state.config.hotkey.gtk },
            set: { newValue in
                var copy = state.config
                copy.hotkey = GtkAccelerator(gtk: newValue)
                state.config = copy
                HotkeyManager.shared.register(copy.hotkey)
            }
        )
    }

    private func binding(for id: String) -> Binding<String> {
        Binding(
            get: { state.config.keybindings[id] ?? GuakeKeybindings.localDefaults[id] ?? "" },
            set: { newValue in
                var copy = state.config
                copy.keybindings[id] = newValue
                state.config = copy
            }
        )
    }
}

struct HotkeyRow: View {
    let title: String
    @Binding var gtk: String
    @State private var listening = false

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(listening ? "按下新快捷键…" : GtkAccelerator(gtk: gtk).displayName)
                .font(.body.monospaced())
                .foregroundStyle(listening ? Color.accentColor : .secondary)
            Button(listening ? "取消" : "更改") {
                listening.toggle()
                KeybindMonitor.isCapturing = listening
            }
            Button("清空") {
                gtk = ""
                listening = false
                KeybindMonitor.isCapturing = false
            }
            .disabled(gtk.isEmpty && !listening)
        }
        .background(HotkeyCatcher(active: $listening, gtk: $gtk))
        .onDisappear {
            if listening {
                listening = false
                KeybindMonitor.isCapturing = false
            }
        }
    }
}

/// 在设置页本地截获下一次按键，写成 Guake/GTK 加速键字符串。
struct HotkeyCatcher: NSViewRepresentable {
    @Binding var active: Bool
    @Binding var gtk: String

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onCapture = { captured in
            gtk = captured
            active = false
            KeybindMonitor.isCapturing = false
        }
        view.onCancel = {
            active = false
            KeybindMonitor.isCapturing = false
        }
        return view
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        nsView.setActive(active)
    }

    final class CatcherView: NSView {
        var onCapture: ((String) -> Void)?
        var onCancel: (() -> Void)?
        private var monitor: Any?
        private var listening = false

        func setActive(_ active: Bool) {
            if active, !listening {
                listening = true
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    self?.handle(event)
                    return nil
                }
            } else if !active, listening {
                listening = false
                if let monitor {
                    NSEvent.removeMonitor(monitor)
                    self.monitor = nil
                }
            }
        }

        private func handle(_ event: NSEvent) {
            if event.keyCode == 53 {
                onCancel?()
                return
            }
            let flags = UInt(event.modifierFlags.rawValue)
            guard let gtk = GtkAccelerator.gtkString(keyCode: event.keyCode, nsModifiers: flags) else {
                return
            }
            onCapture?(gtk)
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
