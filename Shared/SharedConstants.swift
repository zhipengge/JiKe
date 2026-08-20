import Foundation

/// 工程级标识符。改 Bundle ID / 存储 key 时必须与 pbxproj 同步，逻辑测试第 1 组守这条。
enum SharedConstants {
    static let appBundleID = "com.gezhipeng0201.JiKe"
    static let displayName = "即刻"
    static let englishName = "JiKe"
    static let sku = "jike-20260820"
    static let teamID = "7252W54VUU"
    static let urlScheme = "jike"
    static let tabUUIDEnvironmentKey = "GUAKE_TAB_UUID"
    static let tabUUIDAliasKey = "JIKE_TAB_UUID"
    static let directoryConfigFileName = ".jike.yml"
    static let guakeDirectoryConfigFileName = ".guake.yml"

    static let configKey = "jike.config.v1"
    static let sessionKey = "jike.session.v1"
    static let firstLaunchKey = "jike.firstLaunchDone.v1"

    static let loggerSubsystem = appBundleID
}