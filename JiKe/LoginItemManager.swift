import Foundation
import ServiceManagement

enum LoginItemManager {
    static func sync(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // 用户在系统设置里关掉登录项时，这里会失败，忽略即可。
        }
    }
}