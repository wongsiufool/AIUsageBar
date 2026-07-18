#!/bin/zsh
# 构建 AIUsageBar.app（发布版应用包）
set -e
cd "$(dirname "$0")"

swift build -c release

APP=build/AIUsageBar.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp .build/release/AIUsageBar "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>AIUsageBar</string>
    <key>CFBundleIdentifier</key><string>local.aiusagebar</string>
    <key>CFBundleName</key><string>AIUsageBar</string>
    <key>CFBundleDisplayName</key><string>AI Usage Bar</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "构建完成: $PWD/$APP"
