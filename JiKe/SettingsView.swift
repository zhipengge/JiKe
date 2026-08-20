import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var selection: SettingsPane = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selection) { pane in
                Label(pane.title, systemImage: pane.icon)
                    .tag(pane)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            switch selection {
            case .general: GeneralSettingsView()
            case .appearance: AppearanceSettingsView()
            case .behavior: BehaviorSettingsView()
            case .keybindings: KeybindingsSettingsView()
            case .commands: CustomCommandsView()
            case .permissions: PermissionsView()
            case .about: AboutView()
            }
        }
        .frame(minWidth: 680, minHeight: 480)
        .environmentObject(state)
    }
}

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, appearance, behavior, keybindings, commands, permissions, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: return "通用"
        case .appearance: return "外观"
        case .behavior: return "行为"
        case .keybindings: return "快捷键"
        case .commands: return "自定义命令"
        case .permissions: return "权限"
        case .about: return "关于"
        }
    }
    var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .appearance: return "paintpalette"
        case .behavior: return "keyboard"
        case .keybindings: return "command"
        case .commands: return "terminal"
        case .permissions: return "lock.shield"
        case .about: return "info.circle"
        }
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Form {
            Section("呼出（Guake show-hide）") {
                LabeledContent("全局快捷键") {
                    Text(state.config.hotkey.displayName)
                        .font(.body.monospaced())
                }
                Text("默认与 Guake 相同：F12。笔记本请按 Fn+F12。若被系统占用，到「系统设置 → 键盘 → 键盘快捷键」关掉冲突项。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("登录时启动", isOn: $state.config.launchAtLogin)
                Toggle("显示托盘 / 菜单栏图标", isOn: $state.config.showMenuBarIcon)
                Toggle("显示 Dock 图标", isOn: $state.config.showDockIcon)
                Toggle("退出前确认", isOn: $state.config.promptOnQuit)
            }
            Section("窗口") {
                Slider(value: $state.config.windowHeightPercent, in: 10...100, step: 1) {
                    Text("高度 \(Int(state.config.windowHeightPercent))%")
                }
                Slider(value: $state.config.windowWidthPercent, in: 20...100, step: 1) {
                    Text("宽度 \(Int(state.config.windowWidthPercent))%")
                }
                Picker("水平对齐", selection: $state.config.horizontalAlignment) {
                    Text("居中").tag(HorizontalAlignment.center)
                    Text("靠左").tag(HorizontalAlignment.left)
                    Text("靠右").tag(HorizontalAlignment.right)
                }
                Picker("垂直对齐", selection: $state.config.verticalAlignment) {
                    Text("顶部落下").tag(VerticalAlignment.top)
                    Text("底部升起").tag(VerticalAlignment.bottom)
                }
                Slider(value: $state.config.displacementX, in: -400...400, step: 1) {
                    Text("水平偏移 \(Int(state.config.displacementX)) px")
                }
                Slider(value: $state.config.displacementY, in: -400...400, step: 1) {
                    Text("垂直偏移 \(Int(state.config.displacementY)) px")
                }
                Slider(value: $state.config.animationDuration, in: 0...0.6, step: 0.02) {
                    Text(String(format: "动画 %.2f 秒", state.config.animationDuration))
                }
                Picker("出现在", selection: $state.config.monitor) {
                    Text("鼠标所在屏幕").tag(MonitorPreference.mouse)
                    Text("主屏幕").tag(MonitorPreference.primary)
                    ForEach(0..<NSScreen.screens.count, id: \.self) { index in
                        Text("屏幕 \(index + 1)").tag(MonitorPreference.index(index))
                    }
                }
                Toggle("启动时最大化", isOn: $state.config.startFullscreen)
            }
            Section("启动") {
                Toggle("启动时恢复上次的标签", isOn: $state.config.restoreTabs)
                Toggle("标签变化时自动保存会话", isOn: $state.config.saveTabsWhenChanged)
                Toggle("恢复标签后提示", isOn: $state.config.notifyWhenRestoredTabs)
                Toggle("读取目录里的 .guake.yml / .jike.yml", isOn: $state.config.loadDirectoryConfig)
                TextField("启动脚本（可选）", text: $state.config.startupScriptPath)
                Text("对齐 Guake startup-script。也可用 open jike://new-tab 这类 URL。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("恢复默认设置") {
                    state.restoreDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AppearanceSettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var paletteQuery = ""

    private var transparencyBinding: Binding<Double> {
        Binding(
            get: { Double(state.config.transparency) },
            set: { value in
                var copy = state.config
                copy.transparency = Int(value)
                state.config = copy
            }
        )
    }

    private var filteredPalettes: [TerminalPalette] {
        let query = paletteQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return PaletteCatalog.all }
        return PaletteCatalog.all.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.id.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Form {
            Section("配色（Guake palettes.py，共 \(PaletteCatalog.all.count) 套）") {
                TextField("搜索配色", text: $paletteQuery)
                PalettePreview(palette: state.config.palette)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(filteredPalettes) { palette in
                            Button {
                                state.applyPalette(palette.id)
                            } label: {
                                HStack(spacing: 8) {
                                    PaletteSwatch(palette: palette)
                                    Text(palette.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if palette.id == state.config.paletteID {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background(
                                    palette.id == state.config.paletteID
                                        ? Color.accentColor.opacity(0.12)
                                        : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(minHeight: 200, maxHeight: 260)
                Slider(value: transparencyBinding, in: 1...100, step: 1) {
                    Text("背景不透明度 \(state.config.transparency)%（Guake transparency）")
                }
            }
            Section("字体与标签") {
                Picker("字体", selection: $state.config.fontName) {
                    ForEach(TerminalFontNames.displayNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                TextField("自定义字体名（PostScript 或家族名）", text: $state.config.fontName)
                Text("SF Mono 会解析成 SFMono-Regular。中文自动回落到苹方，避免方块乱码。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Stepper(value: $state.config.fontSize, in: 9...48, step: 1) {
                    Text("字号 \(Int(state.config.fontSize))")
                }
                Picker("光标形状", selection: $state.config.cursorShape) {
                    Text("方块").tag(CursorShape.block)
                    Text("竖线").tag(CursorShape.ibeam)
                    Text("下划线").tag(CursorShape.underline)
                }
                Toggle("Option 作为 Meta / Esc", isOn: $state.config.optionAsMeta)
                Text("默认关闭，方便用 Option 输入中文和特殊符号。需要 Emacs 风格 Meta 时再打开。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("显示标签栏", isOn: $state.config.showTabBar)
                Toggle("标签栏在顶部（Guake tab-on-top）", isOn: $state.config.tabBarOnTop)
                Toggle("只有一个标签时隐藏标签栏", isOn: $state.config.hideTabBarIfOneTab)
                Toggle("显示标签关闭按钮", isOn: $state.config.showTabCloseButtons)
                Toggle("用终端标题作为标签名", isOn: $state.config.useTerminalTitle)
                Picker("路径型标签名", selection: $state.config.tabNameDisplay) {
                    Text("完整路径").tag(TabNameDisplay.fullPath)
                    Text("缩写路径").tag(TabNameDisplay.abbreviated)
                    Text("最后一段").tag(TabNameDisplay.lastSegment)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct PaletteSwatch: View {
    let palette: TerminalPalette

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(palette.ansi.prefix(8).enumerated()), id: \.offset) { _, hex in
                let rgb = TerminalPalette.rgb(hex)
                Rectangle()
                    .fill(Color(red: rgb.0, green: rgb.1, blue: rgb.2))
                    .frame(width: 9, height: 14)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
        )
    }
}

struct PalettePreview: View {
    let palette: TerminalPalette

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(palette.ansi.enumerated()), id: \.offset) { _, hex in
                let rgb = TerminalPalette.rgb(hex)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: rgb.0, green: rgb.1, blue: rgb.2))
                    .frame(width: 18, height: 18)
            }
        }
        .padding(8)
        .background(color(palette.background))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func color(_ hex: String) -> Color {
        let rgb = TerminalPalette.rgb(hex)
        return Color(red: rgb.0, green: rgb.1, blue: rgb.2)
    }
}

struct BehaviorSettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Form {
            Section("交互") {
                Toggle("始终置顶", isOn: $state.config.stayOnTop)
                Toggle("失去焦点时隐藏", isOn: $state.config.hideOnLoseFocus)
                Toggle("选中即复制", isOn: $state.config.copyOnSelect)
                Toggle("响铃", isOn: $state.config.playBell)
                Picker("关闭标签时确认", selection: $state.config.promptOnCloseTab) {
                    Text("从不").tag(PromptOnCloseTab.never)
                    Text("有进程时").tag(PromptOnCloseTab.processes)
                    Text("总是").tag(PromptOnCloseTab.always)
                }
            }
            Section("终端进程") {
                TextField("Shell 路径（空则用 $SHELL）", text: $state.config.shellPath)
                Toggle("作为登录 Shell 启动（Guake 默认为关）", isOn: $state.config.loginShell)
                Toggle("在当前工作目录开新标签", isOn: $state.config.openNewTabInCWD)
                Toggle("无限回滚", isOn: $state.config.infiniteScrollback)
                Stepper(value: $state.config.scrollbackLines, in: 200...100000, step: 200) {
                    Text("回滚行数 \(state.config.scrollbackLines)")
                }
                .disabled(state.config.infiniteScrollback)
                Toggle("有输出时滚动到底", isOn: $state.config.scrollOnOutput)
                Toggle("按键时滚动到底", isOn: $state.config.scrollOnKeystroke)
            }
            Section("快速打开（Guake Quick Open）") {
                Toggle("启用（Ctrl+点击 / Command-点击 / 右键）", isOn: $state.config.quickOpenEnabled)
                Toggle("在当前终端执行打开命令", isOn: $state.config.quickOpenInCurrentTerminal)
                TextField("命令模板", text: $state.config.quickOpenCommandLine)
                Text("Guake 默认是 gedit %(file_path)s。macOS 默认改成 open '%(file_path)s'。也可用 %(line_number)s，例如 code -g '%(file_path)s:%(line_number)s'。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("macOS") {
                Text("拖文件进终端会插入加引号的路径；从访达拷贝文件再 Cmd+V 同样有效。Cmd+C / V / A / F 按 Mac 习惯工作。窗口收起时若开启响铃，Dock 图标会弹跳提醒。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("网页搜索") {
                Picker("搜索引擎", selection: $state.config.searchEngine) {
                    ForEach(SearchEngine.allCases.filter { $0 != .custom }) { engine in
                        Text(engine.label).tag(engine)
                    }
                    Text("自定义").tag(SearchEngine.custom)
                }
                if state.config.searchEngine == .custom {
                    TextField("自定义搜索 URL 前缀", text: $state.config.customSearchEngineURL)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct CustomCommandsView: View {
    @EnvironmentObject private var state: AppState
    @State private var draftName = ""
    @State private var draftCommand = ""

    var body: some View {
        Form {
            Section("右键菜单命令") {
                if state.config.customCommands.isEmpty {
                    Text("还没有自定义命令。添加后会出现在终端右键菜单里，点一下就写入当前终端。")
                        .foregroundStyle(.secondary)
                }
                ForEach($state.config.customCommands) { $command in
                    HStack {
                        TextField("名称", text: $command.name)
                        TextField("命令", text: $command.command)
                        Button("删除", role: .destructive) {
                            state.config.customCommands.removeAll { $0.id == command.id }
                        }
                    }
                }
            }
            Section("Guake custom_command.json") {
                TextField("JSON 文件路径", text: $state.config.customCommandFile)
                Text("格式与 Guake 相同：description + cmd 数组，可选 type=menu 分组。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("新增") {
                TextField("名称，例如 跑测试", text: $draftName)
                TextField("命令，例如 pytest -q", text: $draftCommand)
                Button("添加") {
                    let name = draftName.trimmingCharacters(in: .whitespaces)
                    let command = draftCommand.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty, !command.isEmpty else { return }
                    state.config.customCommands.append(CustomCommand(name: name, command: command))
                    draftName = ""
                    draftCommand = ""
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct PermissionsView: View {
    var body: some View {
        Form {
            Section("我们会用到的能力") {
                LabeledContent("全局快捷键") {
                    Text("用系统热键接口注册 Fn+F12，不需要辅助功能权限。")
                }
                LabeledContent("本地终端") {
                    Text("在伪终端里运行你的登录 Shell，权限与系统「终端」相同。")
                }
                LabeledContent("打开文件 / 链接") {
                    Text("你主动 Command-点击或右键时，才用系统默认应用打开。")
                }
                LabeledContent("登录项") {
                    Text("仅在你打开「登录时启动」后，向系统注册登录启动。")
                }
            }
            Section("我们不申请、也不使用") {
                Text("完全磁盘访问、摄像头、麦克风、通讯录、位置、日历、提醒事项、自动化、网络追踪、广告标识。")
                    .foregroundStyle(.secondary)
            }
            Section("为什么没有 App 沙盒") {
                Text("下拉终端要执行任意命令、读写你当前目录下的项目文件。系统终端和 iTerm 同样不启用沙盒；启用后 Shell 几乎无法工作。本 App 仍开启 Hardened Runtime，不收集、不上传任何数据。")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image("AppLogo")
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            Text("即刻")
                .font(.largeTitle.bold())
            Text("macOS 下拉终端。配色、快捷键与命令对齐 Guake：按 \(GuakeKeybindings.showHide.displayName) 呼出，再按一次收起。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("版本 1.0")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Link("使用说明", destination: URL(string: "https://zhipengge.github.io/apps/jike/")!)
                Link("隐私政策", destination: URL(string: "https://zhipengge.github.io/apps/jike/privacy.html")!)
                Link("支持", destination: URL(string: "https://zhipengge.github.io/apps/jike/support.html")!)
            }
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}