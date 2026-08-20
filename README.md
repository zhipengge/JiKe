# 即刻 (JiKe)

macOS 下拉终端。按 **F12**（笔记本 **Fn+F12**）从屏幕边缘滑出，再按一次收起。配色、快捷键、Quick Open、自定义命令与 CLI 语义对齐 [Guake](https://github.com/Guake/guake)。

**不走 Mac App Store。** 真实本地 Shell 需要关闭 App 沙盒（与系统「终端」、iTerm 相同），分发方式为 **GitHub Releases + Developer ID 签名 + 公证**。

---

## 下载安装

1. 打开 [Releases](https://github.com/zhipengge/JiKe/releases/latest)（仓库地址以你实际创建的为准）
2. 下载 `JiKe-x.y.z.zip` 或 `JiKe-x.y.z.dmg`
3. 解压后把 **即刻.app** 拖进「应用程序」
4. 首次打开：若系统提示无法验证开发者，**右键 App → 打开**，再点「打开」

最低系统：**macOS 14.0**。

### 卸载

删除「应用程序」里的即刻，可选删除配置：

```bash
rm ~/Library/Preferences/com.gezhipeng0201.JiKe.plist
```

---

## 快速上手

| 操作 | 按键 |
|---|---|
| 呼出 / 收起 | F12（笔记本 Fn+F12） |
| 新建标签 | Ctrl+Shift+T 或 Cmd+N |
| 关闭标签 | Ctrl+Shift+W、Cmd+W，或空提示符下 Ctrl+D |
| 最大化 | Ctrl+Cmd+F 或 Cmd+Return |
| 设置 | 标签栏齿轮，或 Cmd+, |
| 在访达打开当前目录 | Cmd+Shift+E |

菜单栏图标也可显示 / 隐藏终端。启动后终端会立刻滑出，光标在输入位置。

更多说明与隐私政策：[GitHub Pages · jike](https://zhipengge.github.io/apps/jike/)

---

## 特性

- 下拉窗口：高度 / 宽度 / 对齐 / 透明度可配
- 169 套 Guake 配色，默认 Tango
- 标签、垂直 / 水平分屏
- Quick Open：从 `file:line`、traceback 打开源文件
- 右键：拷贝粘贴、分屏、网页搜索、自定义命令
- 兼容 `.guake.yml` / `.jike.yml` 目录标题
- `jike://` URL（toggle / show / hide / new-tab / execute 等）
- 菜单栏运行、可选登录启动、Cmd+C/V 与拖文件插路径等 macOS 习惯

不收集、不上传任何数据。

---

## 开发者

### 目录

```
JiKe/
├── JiKe/           主 App（SwiftUI 设置 + AppKit 下拉窗 + SwiftTerm）
├── Shared/         纯逻辑（逻辑测试与主 App 共用，禁 SwiftUI / SwiftTerm）
├── Config/         Info.plist（jike://）
├── LogicTests/     swiftc 逻辑测试
└── Scripts/        打包 / 发布
```

| 用途 | 值 |
|---|---|
| Bundle ID | `com.gezhipeng0201.JiKe` |
| 显示名 | 即刻 |
| URL scheme | `jike` |

硬约束见 [`AGENTS.md`](./AGENTS.md)。

### 构建与测试

```bash
# Debug
xcodebuild -project JiKe.xcodeproj -scheme JiKe -configuration Debug \
  -derivedDataPath DerivedData -destination 'platform=macOS,arch=arm64' build

# 逻辑测试
./LogicTests/run.sh
```

SwiftTerm 钉在 **1.2.x**（`upToNextMinor`，实际约 1.2.5），不要升到 1.3+。

### 打安装包（GitHub Release）

```bash
# 打出 dist/JiKe-1.0.0.zip（版本默认读工程 MARKETING_VERSION）
./Scripts/release.sh

# 指定版本
./Scripts/release.sh 1.0.1

# 有 Developer ID + 已配置 notarytool 钥匙串配置时自动签名并公证
export SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="jike-notary"   # xcrun notarytool store-credentials 创建的名字
./Scripts/release.sh 1.0.0

# 打完直接用 gh 上传 Release（需已 git push 且 gh auth login）
CREATE_GITHUB_RELEASE=1 ./Scripts/release.sh 1.0.0
```

产物目录：`dist/`

| 文件 | 说明 |
|---|---|
| `JiKe-x.y.z.app` | 可直接运行的 App |
| `JiKe-x.y.z.zip` | 上传到 GitHub Release 的主资产 |
| `JiKe-x.y.z.dmg` | 可选，Finder 友好安装盘 |
| `JiKe-x.y.z.sha256` | 校验和 |

当前机器若只有 **Apple Development** 证书、没有 **Developer ID Application**，脚本仍会打出 zip；用户需「右键 → 打开」。要过 Gatekeeper 无警告，请到 [Apple Developer](https://developer.apple.com/account/resources/certificates/list) 创建 Developer ID，再用上面的环境变量公证。

配置公证钥匙串（一次性）：

```bash
xcrun notarytool store-credentials "jike-notary" \
  --apple-id "你的AppleID" \
  --team-id "7252W54VUU" \
  --password "app-specific-password"
```

### 手工验证清单

1. Fn+F12 滑出 / 再按收起  
2. 菜单栏图标显示隐藏  
3. 换配色、透明度、字号立刻生效  
4. Ctrl+Shift+T / Cmd+N 新建标签；Ctrl+D 退出 Shell 后关标签  
5. `echo $GUAKE_TAB_UUID` 与 `$JIKE_TAB_UUID` 相同  
6. `open 'jike://new-tab?path=/tmp'`  
7. 中文路径 / `git status` 不乱码  

---

## 为什么不进 App Store

App Store 强制 App Sandbox。沙盒下无法提供「任意目录 + 登录 Shell」的完整下拉终端。即刻与系统终端、iTerm 一样**不启用沙盒**，因此只通过 GitHub Releases（建议公证）分发。

---

## 反馈

- Issues：本仓库 Issues（标题建议带 `[即刻]`）  
- 隐私：[privacy](https://zhipengge.github.io/apps/jike/privacy.html)  

许可与版权 © 2026 gezhipeng。
