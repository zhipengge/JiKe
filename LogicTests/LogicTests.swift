import Foundation

@main
struct LogicTests {
    static func main() {
        var failed = 0
        var passed = 0

        func check(_ name: String, _ condition: () -> Bool) {
            if condition() {
                passed += 1
                print("  PASS  \(name)")
            } else {
                failed += 1
                print("  FAIL  \(name)")
            }
        }

        print("== 1. 标识符一致性 ==")
        check("Bundle ID 为全新产品 ID") { SharedConstants.appBundleID == "com.gezhipeng0201.JiKe" }
        check("SKU 含日期且不复用旧产品") { SharedConstants.sku == "jike-20260820" }
        check("配置 key 不与其它产品撞车") { SharedConstants.configKey == "jike.config.v1" }
        check("会话 key 与配置 key 不同") { SharedConstants.sessionKey != SharedConstants.configKey }
        check("首次启动 key 独立") { SharedConstants.firstLaunchKey != SharedConstants.configKey }
        check("URL scheme 为 jike") { SharedConstants.urlScheme == "jike" }
        check("标签 UUID 环境变量与 Guake 一致") { SharedConstants.tabUUIDEnvironmentKey == "GUAKE_TAB_UUID" }
        check("即刻别名环境变量") { SharedConstants.tabUUIDAliasKey == "JIKE_TAB_UUID" }
        check("目录配置文件名") { SharedConstants.directoryConfigFileName == ".jike.yml" }
        check("显示名是即刻") { SharedConstants.displayName == "即刻" }

        print("== 2. 配置向前兼容：旧 JSON 缺字段仍能解码 ==")
        let defaults = UserDefaults(suiteName: "jike.logic-tests.\(UUID().uuidString)")!
        let emptySuite = UserDefaults(suiteName: "jike.empty.\(UUID().uuidString)")!
        let firstLaunch = ConfigStore.load(defaults: emptySuite)
        check("从未保存过时快捷键是 Fn+F12") { firstLaunch.hotkey == GuakeKeybindings.showHide }
        check("默认自定义命令为空") { firstLaunch.customCommands.isEmpty }
        check("默认配色是 Tango") { firstLaunch.paletteID == "tango" }
        check("默认不透明度 90 与 Guake 一致") { firstLaunch.transparency == 90 }
        check("macOS 默认 Option 不当 Meta") { firstLaunch.optionAsMeta == false }

        let oldJSON = """
        {"paletteID":"nord","fontSize":18,"customCommands":[]}
        """.data(using: .utf8)!
        emptySuite.set(oldJSON, forKey: SharedConstants.configKey)
        let migrated = ConfigStore.load(defaults: emptySuite)
        check("旧 JSON 缺字段仍能解码") { migrated.paletteID == "nord" && migrated.fontSize == 18 }
        check("缺字段补上默认热键") { migrated.hotkey == GuakeKeybindings.showHide }
        check("用户清空的自定义命令不会被填回") { migrated.customCommands.isEmpty }

        var withCommands = AppConfig()
        withCommands.customCommands = [CustomCommand(name: "htop", command: "htop")]
        ConfigStore.save(withCommands, defaults: defaults)
        let loadedCommands = ConfigStore.load(defaults: defaults)
        check("保存后再读自定义命令还在") { loadedCommands.customCommands.map(\.name) == ["htop"] }

        var emptied = loadedCommands
        emptied.customCommands = []
        ConfigStore.save(emptied, defaults: defaults)
        check("主动清空后 load 不会补默认命令") { ConfigStore.load(defaults: defaults).customCommands.isEmpty }

        let restored = ConfigStore.restoredDefaults()
        check("恢复默认才回到出厂配置") { restored == AppConfig.default }

        var tooBig = AppConfig()
        tooBig.windowHeightPercent = 500
        tooBig.transparency = 200
        tooBig.fontSize = 1
        tooBig.clamp()
        check("高度被夹到 100") { tooBig.windowHeightPercent == 100 }
        check("不透明度被夹到 100") { tooBig.transparency == 100 }
        check("字号下限 9") { tooBig.fontSize == 9 }

        print("== 3. 窗口几何 ==")
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let shown = WindowGeometry.frame(
            screen: screen,
            heightPercent: 50,
            widthPercent: 100,
            horizontalAlignment: .center,
            verticalAlignment: .top,
            displacementX: 0,
            displacementY: 0,
            visible: true
        )
        check("可见时贴在工作区顶部") { shown.origin.y == 450 && shown.height == 450 && shown.width == 1440 }
        let hidden = WindowGeometry.frame(
            screen: screen,
            heightPercent: 50,
            widthPercent: 100,
            horizontalAlignment: .center,
            verticalAlignment: .top,
            displacementX: 0,
            displacementY: 0,
            visible: false
        )
        check("隐藏时完全在屏幕上方") { hidden.origin.y > screen.maxY }
        let right = WindowGeometry.frame(
            screen: screen,
            heightPercent: 40,
            widthPercent: 50,
            horizontalAlignment: .right,
            verticalAlignment: .top,
            displacementX: 0,
            displacementY: 0,
            visible: true
        )
        check("宽度 50% 且靠右") { right.width == 720 && abs(right.origin.x - 720) < 0.5 }
        check("Guake 不透明度 90 → alpha 0.9") { WindowGeometry.backgroundAlpha(90) == 0.9 }
        check("ALWAYS_ON_PRIMARY(-1) 回落到主屏") {
            MonitorPreference.resolvedIndex(preference: .index(-1), mouseScreenIndex: 1, primaryIndex: 0, count: 2) == 0
        }
        check("鼠标屏索引被夹到范围内") {
            MonitorPreference.resolvedIndex(preference: .mouse, mouseScreenIndex: 8, primaryIndex: 0, count: 2) == 1
        }
        check("指定不存在的屏回落到最后一块") {
            MonitorPreference.resolvedIndex(preference: .index(9), mouseScreenIndex: 0, primaryIndex: 0, count: 3) == 2
        }

        print("== 4. 分屏树 ==")
        let a = UUID()
        let b = UUID()
        let c = UUID()
        var tree = SplitNode.leaf(id: a)
        tree = tree.splitting(leafID: a, direction: .horizontal, newID: b)
        check("水平拆分后有两个叶子") { tree.leafIDs == [a, b] }
        tree = tree.splitting(leafID: b, direction: .vertical, newID: c)
        check("继续拆分得到三个叶子") { tree.leafIDs == [a, b, c] }
        let afterCloseB = tree.closing(leafID: b)
        check("关掉中间叶子剩下两侧") { afterCloseB?.leafIDs == [a, c] }
        check("关掉最后一个叶子得到 nil") { SplitNode.leaf(id: a).closing(leafID: a) == nil }
        check("关掉不存在的叶子保持原样") { SplitNode.leaf(id: a).closing(leafID: UUID())?.leafIDs == [a] }
        check("下一个 pane 循环") { tree.neighbor(of: c, moving: .next) == a }
        check("上一个 pane") { tree.neighbor(of: b, moving: .previous) == a }
        let ratioClamped = SplitNode.split(id: UUID(), direction: .horizontal, first: .leaf(id: a), second: .leaf(id: b), ratio: 0.5)
            .settingRatio(1.5)
        check("分屏比例被夹到 0.85") { abs(ratioClamped.ratio - 0.85) < 0.0001 }

        print("== 5. 快捷打开解析 ==")
        let py = QuickOpenParser.firstMatch("File \"/tmp/app.py\", line 12, in <module>")
        check("Python traceback 解析路径") { py?.path == "/tmp/app.py" }
        check("Python traceback 解析行号") { py?.line == 12 }
        check("Python traceback 来源标记") { py?.source == .pythonTraceback }
        let gcc = QuickOpenParser.firstMatch("  src/main.c:12")
        check("gcc Filename:line 解析路径") { gcc?.path == "src/main.c" }
        check("gcc Filename:line 解析行号") { gcc?.line == 12 }
        let pytest = QuickOpenParser.firstMatch("tests/test_app.py:18: in test_foo")
        check("pytest 解析路径和行") { pytest?.path == "tests/test_app.py" && pytest?.line == 18 }
        let generic = QuickOpenParser.firstMatch("Shared/AppConfig.swift:80")
        check("通用 path:line") { generic?.path == "Shared/AppConfig.swift" && generic?.line == 80 }
        check("纯路径也识别") { QuickOpenParser.expandCommand("open '%(file_path)s'", target: QuickOpenTarget(path: "/tmp/a.swift", line: 8, column: nil, source: .generic)) == "open '/tmp/a.swift'" }
        check("命令模板填行号") { QuickOpenParser.expandCommand("code -g %(file_path)s:%(line_number)s", target: QuickOpenTarget(path: "a.py", line: 3, column: nil, source: .pythonTraceback)) == "code -g a.py:3" }
        check("非路径文本忽略") { QuickOpenParser.parse("hello world").isEmpty }
        let many = QuickOpenParser.parse("a.swift:1:1: error\na.swift:1:1: error")
        check("同一位置去重") { many.count == 1 }

        print("== 6. 链接与搜索 ==")
        let urls = LinkDetector.urls(in: "see https://example.com/docs, and http://localhost:8080/x.")
        check("识别 https") { urls.contains(URL(string: "https://example.com/docs")!) }
        check("去掉句点") { urls.contains(URL(string: "http://localhost:8080/x")!) }
        check("搜索 URL 含查询词") {
            SearchEngine.google.searchURL(query: "swift term", customURL: "")?.absoluteString.contains("q=swift") == true
        }
        check("Guake 引擎表有 5 个内置") { SearchEngine.allCases.filter { $0 != .custom }.count == 5 }

        print("== 7. 标签标题与 .jike.yml ==")
        check("自定义标题优先") {
            TabTitle.resolved(custom: "工作", yamlTitle: "项目", process: "vim", workingDirectory: "/tmp/demo") == "工作"
        }
        check("yaml 标题次之") {
            TabTitle.resolved(custom: nil, yamlTitle: "项目", process: "vim", workingDirectory: "/tmp/demo") == "项目"
        }
        check("进程名再次之") {
            TabTitle.resolved(custom: nil, yamlTitle: nil, process: "vim", workingDirectory: "/tmp/demo") == "vim"
        }
        check("zsh 不算有效进程名") {
            TabTitle.resolved(custom: nil, yamlTitle: nil, process: "-zsh", workingDirectory: "/Users/demo/code") == "code"
        }
        check("都没有时回落") {
            TabTitle.resolved(custom: "  ", yamlTitle: nil, process: nil, workingDirectory: nil) == "终端"
        }
        check("解析 yaml 标题") {
            DirectoryConfig.title(from: "# comment\ntitle: \"My Great Project\"\n") == "My Great Project"
        }
        check("解析无引号 yaml") { DirectoryConfig.title(from: "title: notes") == "notes" }
        check("空 yaml 无标题") { DirectoryConfig.title(from: "other: 1") == nil }
        check("同时认 .guake.yml 与 .jike.yml") {
            DirectoryConfig.fileNames == [".guake.yml", ".jike.yml"]
        }
        check("解析无引号 yaml") { DirectoryConfig.title(from: "title: notes") == "notes" }
        check("空 yaml 无标题") { DirectoryConfig.title(from: "other: 1") == nil }

        print("== 8. URL scheme 命令 ==")
        check("toggle") { JiKeCommand.parse(url: URL(string: "jike://toggle")!) == .toggle }
        check("空 host 当 toggle") { JiKeCommand.parse(url: URL(string: "jike://")!) == .toggle }
        check("show / hide") {
            JiKeCommand.parse(url: URL(string: "jike://show")!) == .show
                && JiKeCommand.parse(url: URL(string: "jike://hide")!) == .hide
        }
        check("new-tab") { JiKeCommand.parse(url: URL(string: "jike://new-tab")!) == .newTab(path: nil) }
        let tabID = UUID()
        check("选标签") { JiKeCommand.parse(url: URL(string: "jike://tab?id=\(tabID.uuidString)")!) == .selectTab(tabID) }
        check("执行命令") { JiKeCommand.parse(url: URL(string: "jike://execute?cmd=ls%20-l")!) == .execute("ls -l") }
        check("分屏") {
            JiKeCommand.parse(url: URL(string: "jike://split-vertical?percent=40")!) == .splitVertical(percent: 40)
        }
        check("改配色") {
            JiKeCommand.parse(url: URL(string: "jike://change-palette?name=Dracula")!) == .changePalette("Dracula")
        }
        check("fullscreen") { JiKeCommand.parse(url: URL(string: "jike://fullscreen")!) == .fullscreen(true) }
        check("未知命令") {
            if case .unknown = JiKeCommand.parse(url: URL(string: "jike://nope")!) { return true }
            return false
        }
        check("其它 scheme 忽略") {
            if case .unknown = JiKeCommand.parse(url: URL(string: "https://example.com")!) { return true }
            return false
        }

        print("== 9. 配色 ==")
        check("至少 130 套 Guake 配色") { PaletteCatalog.all.count >= 130 }
        check("id 不重复") { Set(PaletteCatalog.ids).count == PaletteCatalog.all.count }
        check("每套都是 16 色且 hex 合法") { PaletteCatalog.all.allSatisfy(\.isValid) }
        check("未知 id 回落到 Tango") { PaletteCatalog.palette(id: "not-exist").name == "Tango" }
        check("默认 config 配色存在") { AppConfig.default.palette.isValid }
        let tangoGTK = "#000000000000:#cccc00000000:#4e4e9a9a0606:#c4c4a0a00000:#34346565a4a4:#757550507b7b:#060698209a9a:#d3d3d7d7cfcf:#555557575353:#efef29292929:#8a8ae2e23434:#fcfce9e94f4f:#72729f9fcfcf:#adad7f7fa8a8:#3434e2e2e2e2:#eeeeeeeeecec:#ffffffffffff:#000000000000"
        let parsedTango = GuakePaletteFormat.parse(gtkPalette: tangoGTK, name: "Tango")
        check("GTK 12 位色解析前景为白") { parsedTango?.foreground == "#FFFFFF" }
        check("GTK 12 位色解析背景为黑") { parsedTango?.background == "#000000" }
        let rgb = TerminalPalette.rgb("#FF8000")
        check("hex 解析") { abs(rgb.0 - 1) < 0.001 && abs(rgb.1 - 128.0 / 255) < 0.001 && rgb.2 == 0 }

        print("== 10. 会话快照与空列表 ==")
        let sessionDefaults = UserDefaults(suiteName: "jike.session.\(UUID().uuidString)")!
        check("从未保存过会话是空") { SessionStore.load(defaults: sessionDefaults).tabs.isEmpty }
        let tab = TabSnapshot(customTitle: "build", workingDirectory: "/tmp")
        SessionStore.save(SessionSnapshot(tabs: [tab], selectedTabID: tab.id), defaults: sessionDefaults)
        let loadedSession = SessionStore.load(defaults: sessionDefaults)
        check("会话能往返") { loadedSession.tabs.first?.customTitle == "build" }
        SessionStore.save(.empty, defaults: sessionDefaults)
        check("空会话会删掉存储，而不是写回默认标签") { SessionStore.load(defaults: sessionDefaults).tabs.isEmpty }

        print("== 11. 快捷键与启动命令 ==")
        check("默认热键显示 Fn+F12") { GuakeKeybindings.showHide.displayName == "Fn+F12" }
        check("F12 键码 0x6F") { GuakeKeybindings.showHide.keyCode == 0x6F && GuakeKeybindings.showHide.carbonModifiers == 0 }
        check("Ctrl+Shift+T 新建标签") {
            let accel = GtkAccelerator(gtk: GuakeKeybindings.localDefaults["new-tab"]!)
            return accel.keyName == "T" && accel.carbonModifiers & 4096 != 0 && accel.carbonModifiers & 512 != 0
        }
        check("Super 映射为 Cmd") {
            let accel = GtkAccelerator(gtk: "<Super>t")
            return accel.carbonModifiers & 256 != 0
        }
        let homeLaunch = ShellLaunch.arguments(shellPath: "/bin/zsh", login: true, workingDirectory: nil)
        check("无 cwd 时登录 shell 用 -l -i") { homeLaunch.args == ["-l", "-i"] && homeLaunch.execName == "-zsh" }
        check("非登录也强制交互式，才会读 zshrc") {
            ShellLaunch.arguments(shellPath: "/bin/zsh", login: false, workingDirectory: nil).args == ["-i"]
        }
        let quoted = ShellQuote.single("/tmp/it's")
        check("单引号转义") { quoted == "'/tmp/it'\\''s'" }
        let cwdLaunch = ShellLaunch.arguments(shellPath: "/bin/zsh", login: true, workingDirectory: "/tmp/project")
        check("有 cwd 时走 -c cd && exec") {
            cwdLaunch.args.count == 2
                && cwdLaunch.args[0] == "-c"
                && cwdLaunch.args[1].contains("cd '/tmp/project'")
                && cwdLaunch.args[1].contains("exec '/bin/zsh' '-l' '-i'")
        }
        check("快捷键目录含新建/关闭/最大化") {
            let ids = Set(GuakeKeybindings.catalog.map(\.id))
            return ids.contains("new-tab") && ids.contains("close-tab") && ids.contains("toggle-fullscreen")
        }
        check("忽略 Caps Lock 仍匹配 Ctrl+Shift+T") {
            let gtk = GuakeKeybindings.localDefaults["new-tab"]!
            let caps = GtkAccelerator.nsControl | GtkAccelerator.nsShift | (1 << 16)
            return GuakeKeybindings.match(keyCode: 0x11, nsModifiers: caps, against: gtk)
        }
        check("Cmd+W 额外键关闭标签") {
            GuakeKeybindings.macOSExtras.contains { $0.id == "close-tab" && $0.gtk == "<Super>w" }
        }
        check("Cmd+C / Cmd+V / Cmd+F 是 macOS 额外键") {
            let ids = Set(GuakeKeybindings.macOSExtras.map(\.id))
            return ids.contains("clipboard-copy") && ids.contains("clipboard-paste") && ids.contains("search-terminal")
        }
        check("访达路径插入会加引号") {
            MacPasteInsertion.text(filePaths: ["/tmp/a b", "/tmp/it's"], fallback: "x")
                == "'/tmp/a b' '/tmp/it'\\''s'"
        }
        check("没有路径时用剪贴板文本") {
            MacPasteInsertion.text(filePaths: [], fallback: "hello") == "hello"
        }
        check("Ctrl+Cmd+F 还原成 GTK 串") {
            GtkAccelerator.gtkString(
                keyCode: 0x03,
                nsModifiers: GtkAccelerator.nsControl | GtkAccelerator.nsCommand
            ) == "<Control><Super>f"
        }

        print("== 11b. Guake 自定义命令 JSON ==")
        let json = """
        [{"type":"menu","description":"dir listing","items":[{"description":"la","cmd":["ls","-la"]}]},{"description":"less ls","cmd":["ls | less",""]}]
        """
        let leaves = GuakeCustomCommandsFile.leaves(json: json)
        check("解析菜单叶子") { leaves.contains(where: { $0.name == "la" && $0.command == "ls -la" }) }
        check("解析顶层命令") { leaves.contains(where: { $0.name == "less ls" && $0.command.contains("ls | less") }) }
        check("坏 JSON 得到空列表") { GuakeCustomCommandsFile.leaves(json: "{not json").isEmpty }

        print("== 12. 存储 key 互不冲突 ==")
        let keys = [
            SharedConstants.configKey,
            SharedConstants.sessionKey,
            SharedConstants.firstLaunchKey,
        ]
        check("三个持久化 key 互不相同") { Set(keys).count == keys.count }

        print("== 13. 全部设置项：默认值、往返、外观副作用 ==")
        let factory = AppConfig.default
        check("默认配色 tango / Tango") { factory.paletteID == "tango" && factory.palette.name == "Tango" }
        check("默认不透明度 90 → alpha 0.9") { factory.transparency == 90 && WindowGeometry.backgroundAlpha(90) == 0.9 }
        check("不透明度 40 → alpha 0.4") { WindowGeometry.backgroundAlpha(40) == 0.4 }
        check("默认字体 Menlo 14") { factory.fontName == "Menlo" && factory.fontSize == 14 }
        check("默认光标方块") { factory.cursorShape == .block }
        check("默认 Option 不当 Meta") { factory.optionAsMeta == false }
        check("默认显示标签栏、底部") { factory.showTabBar && factory.tabBarPosition == .bottom }
        check("默认置顶、不失焦隐藏") { factory.stayOnTop && factory.hideOnLoseFocus == false }
        check("默认不显示 Dock 图标") { factory.showDockIcon == false && factory.showMenuBarIcon }
        check("默认搜索引擎 Google") { factory.searchEngine == .google }
        check("默认光标形状编码 0") { factory.cursorShape.rawValue == 0 }

        func roundTrip(_ mutate: (inout AppConfig) -> Void) -> AppConfig {
            var config = AppConfig()
            mutate(&config)
            let suite = UserDefaults(suiteName: "jike.settings.\(UUID().uuidString)")!
            ConfigStore.save(config, defaults: suite)
            return ConfigStore.load(defaults: suite)
        }

        check("配色往返 Solarized Dark") {
            roundTrip { $0.paletteID = "solarized-dark" }.paletteID == "solarized-dark"
        }
        check("换配色后面前景与 Tango 不同") {
            let tango = PaletteCatalog.palette(id: "tango")
            let solar = PaletteCatalog.palette(id: "solarized-dark")
            return solar.background != tango.background && solar.foreground != tango.foreground
        }
        check("不透明度往返 35") { roundTrip { $0.transparency = 35 }.transparency == 35 }
        check("字体往返 SF Mono 18") {
            let loaded = roundTrip {
                $0.fontName = "SF Mono"
                $0.fontSize = 18
            }
            return loaded.fontName == "SF Mono" && loaded.fontSize == 18
        }
        check("光标往返竖线") { roundTrip { $0.cursorShape = .ibeam }.cursorShape == .ibeam }
        check("窗口几何往返") {
            let loaded = roundTrip {
                $0.windowHeightPercent = 72
                $0.windowWidthPercent = 80
                $0.horizontalAlignment = .right
                $0.verticalAlignment = .bottom
                $0.displacementX = 12
                $0.displacementY = -8
                $0.animationDuration = 0.4
            }
            return loaded.windowHeightPercent == 72
                && loaded.windowWidthPercent == 80
                && loaded.horizontalAlignment == .right
                && loaded.verticalAlignment == .bottom
                && loaded.displacementX == 12
                && loaded.displacementY == -8
                && loaded.animationDuration == 0.4
        }
        check("行为开关往返") {
            let loaded = roundTrip {
                $0.hideOnLoseFocus = true
                $0.stayOnTop = false
                $0.copyOnSelect = true
                $0.playBell = true
                $0.optionAsMeta = true
                $0.loginShell = false
                $0.openNewTabInCWD = false
                $0.launchAtLogin = true
                $0.showDockIcon = true
                $0.showMenuBarIcon = false
                $0.startFullscreen = true
                $0.restoreTabs = false
            }
            return loaded.hideOnLoseFocus
                && loaded.stayOnTop == false
                && loaded.copyOnSelect
                && loaded.playBell
                && loaded.optionAsMeta
                && loaded.loginShell == false
                && loaded.openNewTabInCWD == false
                && loaded.launchAtLogin
                && loaded.showDockIcon
                && loaded.showMenuBarIcon == false
                && loaded.startFullscreen
                && loaded.restoreTabs == false
        }
        check("标签栏与回滚往返") {
            let loaded = roundTrip {
                $0.showTabBar = false
                $0.tabBarOnTop = true
                $0.hideTabBarIfOneTab = true
                $0.showTabCloseButtons = false
                $0.useTerminalTitle = false
                $0.tabNameDisplay = .fullPath
                $0.scrollbackLines = 8000
                $0.infiniteScrollback = true
                $0.scrollOnOutput = true
                $0.scrollOnKeystroke = false
            }
            return loaded.showTabBar == false
                && loaded.tabBarPosition == .top
                && loaded.hideTabBarIfOneTab
                && loaded.showTabCloseButtons == false
                && loaded.useTerminalTitle == false
                && loaded.tabNameDisplay == .fullPath
                && loaded.scrollbackLines == 8000
                && loaded.infiniteScrollback
                && loaded.scrollOnOutput
                && loaded.scrollOnKeystroke == false
        }
        check("快捷打开与搜索往返") {
            let loaded = roundTrip {
                $0.quickOpenEnabled = true
                $0.quickOpenCommandLine = "code -g '%(file_path)s:%(line_number)s'"
                $0.quickOpenInCurrentTerminal = true
                $0.searchEngine = .duckduckgo
                $0.customSearchEngineURL = "https://example.com/q="
                $0.shellPath = "/bin/bash"
                $0.startupScriptPath = "~/bin/on-jike.sh"
            }
            return loaded.quickOpenEnabled
                && loaded.quickOpenCommandLine.contains("code -g")
                && loaded.quickOpenInCurrentTerminal
                && loaded.searchEngine == .duckduckgo
                && loaded.customSearchEngineURL.contains("example.com")
                && loaded.shellPath == "/bin/bash"
                && loaded.startupScriptPath.contains("on-jike.sh")
        }
        check("自定义命令往返") {
            let loaded = roundTrip {
                $0.customCommands = [CustomCommand(name: "测试", command: "pytest -q")]
                $0.customCommandFile = "~/.guake/custom_command.json"
            }
            return loaded.customCommands.first?.name == "测试"
                && loaded.customCommandFile.contains("custom_command.json")
        }
        check("超限字号/透明度被夹紧") {
            let loaded = roundTrip {
                $0.fontSize = 3
                $0.transparency = 0
                $0.windowHeightPercent = 500
            }
            return loaded.fontSize == 9 && loaded.transparency == 1 && loaded.windowHeightPercent == 100
        }
        check("SF Mono 候选含 PostScript 名") {
            TerminalFontNames.candidates(for: "SF Mono").contains("SFMono-Regular")
        }
        check("空字体名回落到 Menlo") {
            TerminalFontNames.candidates(for: "  ").contains("Menlo-Regular")
        }
        check("外观快照随配色变化") {
            var config = AppConfig()
            let before = AppearanceSnapshot(config)
            config.paletteID = "solarized-dark"
            config.transparency = 40
            config.fontSize = 18
            return AppearanceSnapshot(config) != before
        }
        check("中文 locale 注入 zh_CN.UTF-8") {
            let env = TerminalProcessEnvironment.applying(
                to: [:],
                localeIdentifier: "zh-Hans_CN",
                processLANG: nil
            )
            return env["LANG"] == "zh_CN.UTF-8" && env["LC_CTYPE"] == "zh_CN.UTF-8" && env["PYTHONIOENCODING"] == "utf-8"
        }
        check("台湾 locale 注入 zh_TW.UTF-8") {
            TerminalProcessEnvironment.posixUTF8Locale(from: "zh_Hant_TW") == "zh_TW.UTF-8"
        }
        check("已有 UTF-8 LANG 不覆盖") {
            let env = TerminalProcessEnvironment.applying(
                to: ["LANG": "en_US.UTF-8"],
                localeIdentifier: "zh_CN",
                processLANG: "C"
            )
            return env["LANG"] == "en_US.UTF-8"
        }
        check("GBK LANG 会被换成 UTF-8 避免乱码") {
            let env = TerminalProcessEnvironment.applying(
                to: ["LANG": "zh_CN.GBK"],
                localeIdentifier: "zh_CN",
                processLANG: "zh_CN.GBK"
            )
            return TerminalProcessEnvironment.isUTF8(env["LANG"])
        }
        check("默认作为登录 Shell，才能读到 Homebrew 的 zprofile") { AppConfig().loginShell }
        check("PATH 把已存在的 Homebrew 放在系统路径前面") {
            let path = UserPath.resolved(
                current: "/usr/bin:/bin",
                home: "/Users/demo",
                extraDirectories: ["/opt/homebrew/bin", "/opt/missing/bin"],
                fileExists: { $0 == "/opt/homebrew/bin" || $0 == "/Users/demo/.local/bin" },
                contentsOf: { $0 == "/etc/paths" ? "/usr/bin\n/bin\n/usr/sbin\n/sbin\n" : nil },
                directoryListing: { _ in [] }
            )
            let parts = path.split(separator: ":").map(String.init)
            return parts.first == "/opt/homebrew/bin"
                && parts.contains("/usr/bin")
                && parts.contains("/Users/demo/.local/bin")
                && !parts.contains("/opt/missing/bin")
        }
        check("PATH 会读 paths.d 且去重") {
            let path = UserPath.resolved(
                current: "/usr/bin",
                home: "/tmp",
                extraDirectories: [],
                fileExists: { _ in false },
                contentsOf: {
                    switch $0 {
                    case "/etc/paths": return "/usr/bin\n/bin\n"
                    case "/etc/paths.d/homebrew": return "/opt/homebrew/bin\n"
                    default: return nil
                    }
                },
                directoryListing: { $0 == "/etc/paths.d" ? ["homebrew"] : [] }
            )
            let parts = path.split(separator: ":").map(String.init)
            return parts == ["/usr/bin", "/bin", "/opt/homebrew/bin"]
        }

        print()
        if failed == 0 {
            print("ALL \(passed) PASSED")
            exit(0)
        } else {
            print("\(failed) FAILED, \(passed) passed")
            exit(1)
        }
    }
}
