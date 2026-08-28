import Foundation

struct CustomCommand: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var command: String

    init(id: UUID = UUID(), name: String, command: String) {
        self.id = id
        self.name = name
        self.command = command
    }
}

enum PromptOnCloseTab: Int, Codable, Equatable {
    case never = 0
    case processes = 1
    case always = 2
}

enum TabNameDisplay: Int, Codable, Equatable {
    case fullPath = 0
    case abbreviated = 1
    case lastSegment = 2
}

enum CursorShape: Int, Codable, Equatable {
    case block = 0
    case ibeam = 1
    case underline = 2
}

struct AppConfig: Codable, Equatable {
    var windowHeightPercent: Double = 50
    var windowWidthPercent: Double = 100
    var horizontalAlignment: HorizontalAlignment = .center
    var verticalAlignment: VerticalAlignment = .top
    var displacementX: Double = 0
    var displacementY: Double = 0
    var animationDuration: Double = 0.18
    /// Guake `styleBackground.transparency`，0–100，按不透明度使用，默认 90。
    var transparency: Int = 90
    var paletteID: String = "tango"
    var fontName: String = "Menlo"
    var fontSize: Double = 14
    var scrollbackLines: Int = 1000
    var infiniteScrollback: Bool = false
    var scrollOnOutput: Bool = false
    var scrollOnKeystroke: Bool = true
    var hotkey: GtkAccelerator = GuakeKeybindings.showHide
    var keybindings: [String: String] = GuakeKeybindings.localDefaults
    var hideOnLoseFocus: Bool = false
    var stayOnTop: Bool = true
    var showTabBar: Bool = true
    var tabBarOnTop: Bool = false
    var hideTabBarIfOneTab: Bool = false
    var showTabCloseButtons: Bool = true
    var restoreTabs: Bool = true
    var saveTabsWhenChanged: Bool = true
    var notifyWhenRestoredTabs: Bool = true
    var loadDirectoryConfig: Bool = true
    var launchAtLogin: Bool = false
    var showMenuBarIcon: Bool = true
    var showDockIcon: Bool = false
    var promptOnQuit: Bool = true
    var promptOnCloseTab: PromptOnCloseTab = .never
    var monitor: MonitorPreference = .mouse
    var openNewTabInCWD: Bool = true
    var shellPath: String = ""
    /// macOS 默认开：系统「终端」也是登录 Shell，才能读到 Homebrew 写进 `~/.zprofile` 的 PATH。
    var loginShell: Bool = true
    var startupScriptPath: String = ""
    var quickOpenEnabled: Bool = false
    var quickOpenCommandLine: String = "open '%(file_path)s'"
    var quickOpenInCurrentTerminal: Bool = false
    var copyOnSelect: Bool = false
    var optionAsMeta: Bool = false
    var playBell: Bool = false
    var useTerminalTitle: Bool = true
    var tabNameDisplay: TabNameDisplay = .lastSegment
    var cursorShape: CursorShape = .block
    var searchEngine: SearchEngine = .google
    var customSearchEngineURL: String = ""
    var customCommandFile: String = ""
    var customCommands: [CustomCommand] = []
    var startFullscreen: Bool = false

    var palette: TerminalPalette {
        PaletteCatalog.palette(id: paletteID)
    }

    var tabBarPosition: TabBarPosition {
        tabBarOnTop ? .top : .bottom
    }

    mutating func clamp() {
        windowHeightPercent = WindowGeometry.clampedHeightPercent(windowHeightPercent)
        windowWidthPercent = WindowGeometry.clampedWidthPercent(windowWidthPercent)
        animationDuration = WindowGeometry.clampedAnimationDuration(animationDuration)
        transparency = WindowGeometry.clampedTransparency(transparency)
        fontSize = WindowGeometry.clampedFontSize(fontSize)
        scrollbackLines = min(100_000, max(200, scrollbackLines))
        if PaletteCatalog.palette(id: paletteID).id != paletteID
            && PaletteCatalog.palette(id: paletteID).name.caseInsensitiveCompare(paletteID) != .orderedSame {
            paletteID = "tango"
        }
        if keybindings.isEmpty {
            keybindings = GuakeKeybindings.localDefaults
        }
    }

    func accelerator(_ key: String) -> GtkAccelerator {
        GtkAccelerator(gtk: keybindings[key] ?? GuakeKeybindings.localDefaults[key] ?? "")
    }

    static var `default`: AppConfig { AppConfig() }

    init() {}

    enum CodingKeys: String, CodingKey {
        case windowHeightPercent, windowWidthPercent, horizontalAlignment, verticalAlignment
        case displacementX, displacementY, animationDuration, transparency, paletteID
        case fontName, fontSize, scrollbackLines, infiniteScrollback, scrollOnOutput, scrollOnKeystroke
        case hotkey, keybindings, hideOnLoseFocus, stayOnTop, showTabBar, tabBarOnTop
        case hideTabBarIfOneTab, showTabCloseButtons, restoreTabs, saveTabsWhenChanged
        case notifyWhenRestoredTabs, loadDirectoryConfig, launchAtLogin, showMenuBarIcon, showDockIcon
        case promptOnQuit, promptOnCloseTab, monitor, openNewTabInCWD, shellPath, loginShell
        case startupScriptPath, quickOpenEnabled, quickOpenCommandLine, quickOpenInCurrentTerminal
        case copyOnSelect, optionAsMeta, playBell, useTerminalTitle, tabNameDisplay, cursorShape
        case searchEngine, customSearchEngineURL, customCommandFile, customCommands, startFullscreen
    }

    init(from decoder: Decoder) throws {
        let defaults = AppConfig()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        windowHeightPercent = try c.decodeIfPresent(Double.self, forKey: .windowHeightPercent) ?? defaults.windowHeightPercent
        windowWidthPercent = try c.decodeIfPresent(Double.self, forKey: .windowWidthPercent) ?? defaults.windowWidthPercent
        horizontalAlignment = try c.decodeIfPresent(HorizontalAlignment.self, forKey: .horizontalAlignment) ?? defaults.horizontalAlignment
        verticalAlignment = try c.decodeIfPresent(VerticalAlignment.self, forKey: .verticalAlignment) ?? defaults.verticalAlignment
        displacementX = try c.decodeIfPresent(Double.self, forKey: .displacementX) ?? defaults.displacementX
        displacementY = try c.decodeIfPresent(Double.self, forKey: .displacementY) ?? defaults.displacementY
        animationDuration = try c.decodeIfPresent(Double.self, forKey: .animationDuration) ?? defaults.animationDuration
        transparency = try c.decodeIfPresent(Int.self, forKey: .transparency) ?? defaults.transparency
        paletteID = try c.decodeIfPresent(String.self, forKey: .paletteID) ?? defaults.paletteID
        fontName = try c.decodeIfPresent(String.self, forKey: .fontName) ?? defaults.fontName
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? defaults.fontSize
        scrollbackLines = try c.decodeIfPresent(Int.self, forKey: .scrollbackLines) ?? defaults.scrollbackLines
        infiniteScrollback = try c.decodeIfPresent(Bool.self, forKey: .infiniteScrollback) ?? defaults.infiniteScrollback
        scrollOnOutput = try c.decodeIfPresent(Bool.self, forKey: .scrollOnOutput) ?? defaults.scrollOnOutput
        scrollOnKeystroke = try c.decodeIfPresent(Bool.self, forKey: .scrollOnKeystroke) ?? defaults.scrollOnKeystroke
        hotkey = try c.decodeIfPresent(GtkAccelerator.self, forKey: .hotkey) ?? defaults.hotkey
        let savedKeys = try c.decodeIfPresent([String: String].self, forKey: .keybindings)
        keybindings = GuakeKeybindings.localDefaults.merging(savedKeys ?? [:]) { _, new in new }
        hideOnLoseFocus = try c.decodeIfPresent(Bool.self, forKey: .hideOnLoseFocus) ?? defaults.hideOnLoseFocus
        stayOnTop = try c.decodeIfPresent(Bool.self, forKey: .stayOnTop) ?? defaults.stayOnTop
        showTabBar = try c.decodeIfPresent(Bool.self, forKey: .showTabBar) ?? defaults.showTabBar
        tabBarOnTop = try c.decodeIfPresent(Bool.self, forKey: .tabBarOnTop) ?? defaults.tabBarOnTop
        hideTabBarIfOneTab = try c.decodeIfPresent(Bool.self, forKey: .hideTabBarIfOneTab) ?? defaults.hideTabBarIfOneTab
        showTabCloseButtons = try c.decodeIfPresent(Bool.self, forKey: .showTabCloseButtons) ?? defaults.showTabCloseButtons
        restoreTabs = try c.decodeIfPresent(Bool.self, forKey: .restoreTabs) ?? defaults.restoreTabs
        saveTabsWhenChanged = try c.decodeIfPresent(Bool.self, forKey: .saveTabsWhenChanged) ?? defaults.saveTabsWhenChanged
        notifyWhenRestoredTabs = try c.decodeIfPresent(Bool.self, forKey: .notifyWhenRestoredTabs) ?? defaults.notifyWhenRestoredTabs
        loadDirectoryConfig = try c.decodeIfPresent(Bool.self, forKey: .loadDirectoryConfig) ?? defaults.loadDirectoryConfig
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? defaults.launchAtLogin
        showMenuBarIcon = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? defaults.showMenuBarIcon
        showDockIcon = try c.decodeIfPresent(Bool.self, forKey: .showDockIcon) ?? defaults.showDockIcon
        promptOnQuit = try c.decodeIfPresent(Bool.self, forKey: .promptOnQuit) ?? defaults.promptOnQuit
        promptOnCloseTab = try c.decodeIfPresent(PromptOnCloseTab.self, forKey: .promptOnCloseTab) ?? defaults.promptOnCloseTab
        monitor = try c.decodeIfPresent(MonitorPreference.self, forKey: .monitor) ?? defaults.monitor
        openNewTabInCWD = try c.decodeIfPresent(Bool.self, forKey: .openNewTabInCWD) ?? defaults.openNewTabInCWD
        shellPath = try c.decodeIfPresent(String.self, forKey: .shellPath) ?? defaults.shellPath
        loginShell = try c.decodeIfPresent(Bool.self, forKey: .loginShell) ?? defaults.loginShell
        startupScriptPath = try c.decodeIfPresent(String.self, forKey: .startupScriptPath) ?? defaults.startupScriptPath
        quickOpenEnabled = try c.decodeIfPresent(Bool.self, forKey: .quickOpenEnabled) ?? defaults.quickOpenEnabled
        quickOpenCommandLine = try c.decodeIfPresent(String.self, forKey: .quickOpenCommandLine) ?? defaults.quickOpenCommandLine
        quickOpenInCurrentTerminal = try c.decodeIfPresent(Bool.self, forKey: .quickOpenInCurrentTerminal) ?? defaults.quickOpenInCurrentTerminal
        copyOnSelect = try c.decodeIfPresent(Bool.self, forKey: .copyOnSelect) ?? defaults.copyOnSelect
        optionAsMeta = try c.decodeIfPresent(Bool.self, forKey: .optionAsMeta) ?? defaults.optionAsMeta
        playBell = try c.decodeIfPresent(Bool.self, forKey: .playBell) ?? defaults.playBell
        useTerminalTitle = try c.decodeIfPresent(Bool.self, forKey: .useTerminalTitle) ?? defaults.useTerminalTitle
        tabNameDisplay = try c.decodeIfPresent(TabNameDisplay.self, forKey: .tabNameDisplay) ?? defaults.tabNameDisplay
        cursorShape = try c.decodeIfPresent(CursorShape.self, forKey: .cursorShape) ?? defaults.cursorShape
        searchEngine = try c.decodeIfPresent(SearchEngine.self, forKey: .searchEngine) ?? defaults.searchEngine
        customSearchEngineURL = try c.decodeIfPresent(String.self, forKey: .customSearchEngineURL) ?? defaults.customSearchEngineURL
        customCommandFile = try c.decodeIfPresent(String.self, forKey: .customCommandFile) ?? defaults.customCommandFile
        customCommands = try c.decodeIfPresent([CustomCommand].self, forKey: .customCommands) ?? defaults.customCommands
        startFullscreen = try c.decodeIfPresent(Bool.self, forKey: .startFullscreen) ?? defaults.startFullscreen
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(windowHeightPercent, forKey: .windowHeightPercent)
        try c.encode(windowWidthPercent, forKey: .windowWidthPercent)
        try c.encode(horizontalAlignment, forKey: .horizontalAlignment)
        try c.encode(verticalAlignment, forKey: .verticalAlignment)
        try c.encode(displacementX, forKey: .displacementX)
        try c.encode(displacementY, forKey: .displacementY)
        try c.encode(animationDuration, forKey: .animationDuration)
        try c.encode(transparency, forKey: .transparency)
        try c.encode(paletteID, forKey: .paletteID)
        try c.encode(fontName, forKey: .fontName)
        try c.encode(fontSize, forKey: .fontSize)
        try c.encode(scrollbackLines, forKey: .scrollbackLines)
        try c.encode(infiniteScrollback, forKey: .infiniteScrollback)
        try c.encode(scrollOnOutput, forKey: .scrollOnOutput)
        try c.encode(scrollOnKeystroke, forKey: .scrollOnKeystroke)
        try c.encode(hotkey, forKey: .hotkey)
        try c.encode(keybindings, forKey: .keybindings)
        try c.encode(hideOnLoseFocus, forKey: .hideOnLoseFocus)
        try c.encode(stayOnTop, forKey: .stayOnTop)
        try c.encode(showTabBar, forKey: .showTabBar)
        try c.encode(tabBarOnTop, forKey: .tabBarOnTop)
        try c.encode(hideTabBarIfOneTab, forKey: .hideTabBarIfOneTab)
        try c.encode(showTabCloseButtons, forKey: .showTabCloseButtons)
        try c.encode(restoreTabs, forKey: .restoreTabs)
        try c.encode(saveTabsWhenChanged, forKey: .saveTabsWhenChanged)
        try c.encode(notifyWhenRestoredTabs, forKey: .notifyWhenRestoredTabs)
        try c.encode(loadDirectoryConfig, forKey: .loadDirectoryConfig)
        try c.encode(launchAtLogin, forKey: .launchAtLogin)
        try c.encode(showMenuBarIcon, forKey: .showMenuBarIcon)
        try c.encode(showDockIcon, forKey: .showDockIcon)
        try c.encode(promptOnQuit, forKey: .promptOnQuit)
        try c.encode(promptOnCloseTab, forKey: .promptOnCloseTab)
        try c.encode(monitor, forKey: .monitor)
        try c.encode(openNewTabInCWD, forKey: .openNewTabInCWD)
        try c.encode(shellPath, forKey: .shellPath)
        try c.encode(loginShell, forKey: .loginShell)
        try c.encode(startupScriptPath, forKey: .startupScriptPath)
        try c.encode(quickOpenEnabled, forKey: .quickOpenEnabled)
        try c.encode(quickOpenCommandLine, forKey: .quickOpenCommandLine)
        try c.encode(quickOpenInCurrentTerminal, forKey: .quickOpenInCurrentTerminal)
        try c.encode(copyOnSelect, forKey: .copyOnSelect)
        try c.encode(optionAsMeta, forKey: .optionAsMeta)
        try c.encode(playBell, forKey: .playBell)
        try c.encode(useTerminalTitle, forKey: .useTerminalTitle)
        try c.encode(tabNameDisplay, forKey: .tabNameDisplay)
        try c.encode(cursorShape, forKey: .cursorShape)
        try c.encode(searchEngine, forKey: .searchEngine)
        try c.encode(customSearchEngineURL, forKey: .customSearchEngineURL)
        try c.encode(customCommandFile, forKey: .customCommandFile)
        try c.encode(customCommands, forKey: .customCommands)
        try c.encode(startFullscreen, forKey: .startFullscreen)
    }
}

enum TabBarPosition: String, Codable, Equatable {
    case bottom
    case top
}

enum ConfigStore {
    static func load(defaults: UserDefaults = .standard) -> AppConfig {
        guard let data = defaults.data(forKey: SharedConstants.configKey) else {
            return AppConfig()
        }
        let decoder = JSONDecoder()
        guard var config = try? decoder.decode(AppConfig.self, from: data) else {
            return AppConfig()
        }
        config.clamp()
        return config
    }

    static func save(_ config: AppConfig, defaults: UserDefaults = .standard) {
        var copy = config
        copy.clamp()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(copy) {
            defaults.set(data, forKey: SharedConstants.configKey)
        }
    }

    static func restoredDefaults() -> AppConfig {
        AppConfig()
    }
}