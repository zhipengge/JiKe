#!/usr/bin/env bash
# 打即刻 GitHub Release 安装包：Release 构建 →（可选）Developer ID 签名 + 公证 → zip / dmg
#
# 用法:
#   ./Scripts/release.sh [版本号]
# 环境变量:
#   SIGN_IDENTITY     Developer ID Application: ...（有则签名）
#   NOTARY_PROFILE    notarytool 钥匙串配置名（有则公证）
#   SKIP_NOTARY=1     跳过公证
#   SKIP_DMG=1        不打 dmg
#   CREATE_GITHUB_RELEASE=1  用 gh 创建/更新 Release 并上传资产
#   GITHUB_REPO       默认 zhipengge/JiKe
#   DERIVED_DATA      默认仓库内 .release-derived
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROJECT="JiKe.xcodeproj"
SCHEME="JiKe"
APP_NAME="JiKe"
DISPLAY_NAME="即刻"
BUNDLE_ID="com.gezhipeng0201.JiKe"
GITHUB_REPO="${GITHUB_REPO:-zhipengge/JiKe}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/.release-derived}"
DIST="$ROOT/dist"

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(grep -m1 'MARKETING_VERSION' "$ROOT/$PROJECT/project.pbxproj" | sed -E 's/.*MARKETING_VERSION = ([^;]+);/\1/' | tr -d ' ')"
fi
if [[ -z "$VERSION" ]]; then
  VERSION="1.0.0"
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
STAGE="$DIST/stage-$STAMP"
APP_OUT="$DIST/${APP_NAME}-${VERSION}.app"
ZIP_OUT="$DIST/${APP_NAME}-${VERSION}.zip"
DMG_OUT="$DIST/${APP_NAME}-${VERSION}.dmg"
SUM_OUT="$DIST/${APP_NAME}-${VERSION}.sha256"

echo "==> 版本 $VERSION"
echo "==> 清理旧产物"
mkdir -p "$DIST"
rm -rf "$STAGE" "$APP_OUT"
mkdir -p "$STAGE"

echo "==> xcodebuild Release"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  -destination 'platform=macOS,arch=arm64' \
  -quiet \
  build

BUILT_APP="$(find "$DERIVED_DATA/Build/Products/Release" -maxdepth 1 -name '*.app' -print -quit)"
if [[ -z "$BUILT_APP" || ! -d "$BUILT_APP" ]]; then
  echo "找不到 Release .app，请检查构建日志" >&2
  exit 1
fi

echo "==> 复制 $BUILT_APP"
ditto "$BUILT_APP" "$STAGE/${APP_NAME}.app"

# 显示名已是「即刻」；Finder 里仍显示为 JiKe.app 文件名，便于脚本一致。
# 用户拖到应用程序后 Dock 显示名来自 CFBundleDisplayName。

sign_app() {
  local app="$1"
  local identity="$2"
  echo "==> codesign ($identity)"
  codesign --force --deep --options runtime --timestamp \
    --sign "$identity" \
    "$app"
  codesign --verify --deep --strict --verbose=2 "$app"
}

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  sign_app "$STAGE/${APP_NAME}.app" "$SIGN_IDENTITY"
else
  # 尝试自动找 Developer ID
  AUTO_ID="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -1 || true)"
  if [[ -n "$AUTO_ID" ]]; then
    echo "==> 自动使用 $AUTO_ID"
    SIGN_IDENTITY="$AUTO_ID"
    sign_app "$STAGE/${APP_NAME}.app" "$SIGN_IDENTITY"
  else
    echo "!! 未找到 Developer ID Application，将打出未公证包。"
    echo "   用户需右键 → 打开。正式发布请设置 SIGN_IDENTITY 与 NOTARY_PROFILE。"
    # 用 ad-hoc 签一下，避免完全无签名
    codesign --force --deep --sign - "$STAGE/${APP_NAME}.app" || true
  fi
fi

if [[ -n "${SIGN_IDENTITY:-}" && -n "${NOTARY_PROFILE:-}" && "${SKIP_NOTARY:-0}" != "1" ]]; then
  echo "==> 打 zip 供公证"
  NOTARY_ZIP="$DIST/${APP_NAME}-${VERSION}-notarize.zip"
  ditto -c -k --keepParent "$STAGE/${APP_NAME}.app" "$NOTARY_ZIP"
  echo "==> notarytool submit ($NOTARY_PROFILE)"
  xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "==> stapler"
  xcrun stapler staple "$STAGE/${APP_NAME}.app"
  xcrun stapler validate "$STAGE/${APP_NAME}.app"
  rm -f "$NOTARY_ZIP"
elif [[ -n "${SIGN_IDENTITY:-}" ]]; then
  echo "!! 已签名但未公证（未设 NOTARY_PROFILE 或 SKIP_NOTARY=1）"
fi

ditto "$STAGE/${APP_NAME}.app" "$APP_OUT"
# 去掉本机扩展属性，避免 zip 里出现 AppleDouble / 路径痕迹
xattr -cr "$APP_OUT" 2>/dev/null || true

echo "==> zip"
rm -f "$ZIP_OUT"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr --keepParent "$APP_OUT" "$ZIP_OUT"

if [[ "${SKIP_DMG:-0}" != "1" ]]; then
  echo "==> dmg"
  rm -f "$DMG_OUT"
  DMG_STAGE="$DIST/dmg-$STAMP"
  mkdir -p "$DMG_STAGE"
  ditto "$APP_OUT" "$DMG_STAGE/${DISPLAY_NAME}.app"
  xattr -cr "$DMG_STAGE/${DISPLAY_NAME}.app" 2>/dev/null || true
  ln -s /Applications "$DMG_STAGE/Applications"
  hdiutil create -volname "$DISPLAY_NAME" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_OUT"
  rm -rf "$DMG_STAGE"
fi

echo "==> sha256"
# 只写文件名，不要带本机绝对路径
(
  cd "$DIST"
  shasum -a 256 "$(basename "$ZIP_OUT")"
  [[ -f "$(basename "$DMG_OUT")" ]] && shasum -a 256 "$(basename "$DMG_OUT")"
) | tee "$SUM_OUT"

rm -rf "$STAGE"

echo
echo "完成:"
echo "  $ZIP_OUT"
[[ -f "$DMG_OUT" ]] && echo "  $DMG_OUT"
echo "  $SUM_OUT"
echo "  $APP_OUT"
echo
echo "上传 GitHub Release 示例:"
echo "  gh release create v${VERSION} -R ${GITHUB_REPO} -t \"即刻 ${VERSION}\" -n \"macOS 14+。解压后拖入应用程序。首次请右键打开。\" \\"
echo "    \"${ZIP_OUT}\" \"$([ -f "$DMG_OUT" ] && echo "$DMG_OUT")\" \"${SUM_OUT}\""

if [[ "${CREATE_GITHUB_RELEASE:-0}" == "1" ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "CREATE_GITHUB_RELEASE=1 但未安装 gh" >&2
    exit 1
  fi
  ASSETS=("$ZIP_OUT" "$SUM_OUT")
  [[ -f "$DMG_OUT" ]] && ASSETS+=("$DMG_OUT")
  NOTES="$(cat <<EOF
## 即刻 ${VERSION}

macOS 14.0+ 下拉终端。不走 Mac App Store（无沙盒，完整本地 Shell）。

### 安装

1. 下载 \`JiKe-${VERSION}.zip\`（或 dmg）
2. 解压，将「即刻」拖入「应用程序」
3. 首次启动：右键 App → 打开（若已公证且 Developer ID 签名，通常可直接打开）

### 校验

\`\`\`
shasum -a 256 -c JiKe-${VERSION}.sha256
\`\`\`

不收集任何数据。隐私说明：https://zhipengge.github.io/apps/jike/privacy.html
EOF
)"
  if gh release view "v${VERSION}" -R "$GITHUB_REPO" >/dev/null 2>&1; then
    echo "==> 更新已有 Release v${VERSION}"
    gh release upload "v${VERSION}" "${ASSETS[@]}" -R "$GITHUB_REPO" --clobber
  else
    echo "==> 创建 Release v${VERSION}"
    gh release create "v${VERSION}" "${ASSETS[@]}" \
      -R "$GITHUB_REPO" \
      -t "即刻 ${VERSION}" \
      -n "$NOTES"
  fi
  echo "Release: https://github.com/${GITHUB_REPO}/releases/tag/v${VERSION}"
fi
