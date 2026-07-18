#!/bin/zsh
# 一键发布：构建 → 签名 → DMG → 公证 → 装订 → GitHub Release
# 前置（一次性）：xcrun notarytool store-credentials "aiusagebar" \
#   --apple-id <你的AppleID邮箱> --team-id DBYWRB2S9S --password <App专用密码>
set -e
cd "$(dirname "$0")"

VERSION="${1:?用法: ./release.sh <版本号>  例: ./release.sh 1.1.0}"
PROFILE="${NOTARY_PROFILE:-aiusagebar}"
SIGN_ID="Developer ID Application: Kaihong Chen (DBYWRB2S9S)"
DMG="build/AIUsageBar-${VERSION}.dmg"

VERSION="$VERSION" ./build-app.sh

rm -rf build/dmg && mkdir -p build/dmg
cp -R build/AIUsageBar.app build/dmg/
ln -s /Applications build/dmg/Applications
hdiutil create -volname "AIUsageBar" -srcfolder build/dmg -ov -format UDZO "$DMG"
codesign --force --timestamp --sign "$SIGN_ID" "$DMG"

echo "→ 提交公证（通常 1-5 分钟）…"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
spctl -a -t open --context context:primary-signature -v "$DMG" || true

echo "→ 创建 GitHub Release v${VERSION}…"
gh release create "v${VERSION}" "$DMG" --title "AIUsageBar v${VERSION}" --generate-notes

echo "✅ 发布完成"
