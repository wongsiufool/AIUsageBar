#!/bin/zsh
# 构建 AIUsageBar.app
# 默认用 Developer ID 签名（含 Hardened Runtime，可公证）；无证书时回落到 ad-hoc。
set -e
cd "$(dirname "$0")"

VERSION="${VERSION:-1.1}"
SIGN_ID="${SIGN_ID:-Developer ID Application: Kaihong Chen (DBYWRB2S9S)}"

swift build -c release

APP=build/AIUsageBar.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/AIUsageBar "$APP/Contents/MacOS/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>AIUsageBar</string>
    <key>CFBundleIdentifier</key><string>com.kaihongchen.aiusagebar</string>
    <key>CFBundleName</key><string>AIUsageBar</string>
    <key>CFBundleDisplayName</key><string>AI Usage Bar</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

if security find-identity -v -p codesigning | grep -qF "$SIGN_ID"; then
    codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
    echo "已用 Developer ID 签名（Hardened Runtime）"
else
    codesign --force --sign - "$APP"
    echo "⚠️ 未找到 Developer ID 证书，已用 ad-hoc 签名（不可公证）"
fi

echo "构建完成: $PWD/$APP"
