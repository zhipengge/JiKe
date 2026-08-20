# AGENTS.md

macOS 下拉终端。按 F12（笔记本是 Fn+F12）从屏幕边缘滑出，再按一次收起。行为、配色、快捷键、Quick Open、自定义命令 JSON 与 CLI 语义对齐 [Guake](https://github.com/Guake/guake)，终端仿真用 SwiftTerm 1.2.x。

**工程细节、构建/测试命令、手工验证清单都在 [`README.md`](./README.md)，动手前先读它。** 本文件只列容易踩的硬约束和当前进度。

面向用户的营销页 / 隐私政策在 `../apps/jike/`（GitHub Pages）。本仓库 `README.md` 负责下载说明与开发文档。分发走 **GitHub Releases**（Developer ID + 公证），**不要**为上架开 App Sandbox。打包：`./Scripts/release.sh`。

---

## 硬约束

**不要开 App Sandbox。** 下拉终端要跑用户的登录 Shell、读写任意目录。系统「终端」和 iTerm 同样不沙盒。`ENABLE_APP_SANDBOX = NO`，Hardened Runtime 保持开启。打开沙盒后 PTY 几乎不能用。因此 **Mac App Store 基本过不了**，分发走公证，不要为了上架去「修」沙盒。

**SwiftTerm 钉在 1.2.x。** 工程用 `upToNextMinorVersion`、最低 `1.2.1`（实际会解析到 1.2.5）。不要升到 main / 1.3+：那些版本带 plugin 体系，API 对不上。`LocalProcessTerminalView.process` 在 1.2.x 是 internal，本工程自己持有 `LocalProcess`，才能调用公开的 `terminate()`。

**`Shared/` 不能依赖 SwiftUI / SwiftTerm。** 逻辑测试用 `swiftc` 只编 Shared。往 Shared 加文件后必须写进 `LogicTests/run.sh`。

**`AppConfig` 必须手写 Codable。** 合成 Codable 会让旧 JSON 缺字段时整份解码失败。`ConfigStore.load()` 不要把用户清空的 `customCommands` 填回去；默认值只在从未保存过时由 `init()` 带出。

**Guake 色板 index 16/17 与 `palettes.py` 注释相反。** 解析时 index 16 = 前景、17 = 背景，与 Guake `prefs.py` 的 `update_demo_palette` 一致。默认配色是 Tango（白字黑底）。`transparency` 按不透明度用：`alpha = transparency / 100`，默认 90。

**本地快捷键是 Guake 原键，不是 macOS Cmd。** 例如新建标签是 Ctrl+Shift+T。`GtkAccelerator` 把 `<Super>` 映射成 Cmd。改默认键必须同时改 `GuakeKeybindings.localDefaults` 和测试第 11 组。

**三个 UserDefaults key 互不冲突。** `jike.config.v1` / `jike.session.v1` / `jike.firstLaunchDone.v1`。会话和配置不能塞同一个 JSON。

**环境变量与目录配置要对齐 Guake。** 每个标签注入 `GUAKE_TAB_UUID`（另有别名 `JIKE_TAB_UUID`）。目录标题先读 `.guake.yml` 再读 `.jike.yml`。

**最低系统是 macOS 14.0。** 不要随手改成当前 Xcode 的 26.x。

---

## 当前进度（截至 2026-08-20）

首版功能已接上：下拉窗、F12 热键、SwiftTerm PTY、标签/分屏、Guake 快捷键、169 套配色、Quick Open、`jike://` CLI、设置页、菜单栏、登录项。逻辑测试 97 项通过。

### 待办

- [ ] 本仓库首次提交并推到 GitHub（建议 `zhipengge/JiKe`）
- [ ] Apple Developer 创建 **Developer ID Application**，配置 `notarytool` 后跑 `./Scripts/release.sh`
- [ ] `CREATE_GITHUB_RELEASE=1 ./Scripts/release.sh x.y.z` 上传首个 Release
- [ ] `apps/jike/` 文档同步下载链接；GitHub Pages 亲自点开确认
- [ ] 手工验证清单（README）真机跑一遍

### 已确认：分发

不做 Mac App Store。完整版走 GitHub Releases + 可选公证。`ENABLE_APP_SANDBOX` 保持 `NO`。

### 已确认：用户可见名称

面向用户一律用「即刻」。工程内部 target / PRODUCT_NAME / Bundle ID 保持 `JiKe`。中文界面靠 `zh-Hans.lproj/InfoPlist.strings` 和 `CFBundleDisplayName`。
