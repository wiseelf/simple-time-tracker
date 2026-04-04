#!/bin/bash
set -euo pipefail

APP_NAME="TimeTracker"
BUNDLE_ID="com.wiseelf.timetracker"
VERSION="${VERSION:-1.0.0}"
DIST="dist"
APP="$DIST/$APP_NAME.app"
CONTENTS="$APP/Contents"

echo "Building $APP_NAME $VERSION..."

# 1. Compile release binary
swift build -c release

# 2. Assemble .app bundle
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp ".build/release/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"

# 3. Convert xcassets icon to .icns
ICONSET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET"
ASSET="Sources/TimeTracker/Assets.xcassets/AppIcon.appiconset"
cp "$ASSET/icon_16x16.png"    "$ICONSET/icon_16x16.png"
cp "$ASSET/icon_16x16.png"    "$ICONSET/icon_16x16@2x.png"   2>/dev/null || true
cp "$ASSET/icon_128x128.png"  "$ICONSET/icon_128x128.png"
cp "$ASSET/icon_256x256.png"  "$ICONSET/icon_128x128@2x.png"
cp "$ASSET/icon_256x256.png"  "$ICONSET/icon_256x256.png"
cp "$ASSET/icon_512x512.png"  "$ICONSET/icon_256x256@2x.png" 2>/dev/null || true
cp "$ASSET/icon_512x512.png"  "$ICONSET/icon_512x512.png"    2>/dev/null || true
cp "$ASSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/$APP_NAME.icns"

# 4. Write Info.plist
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
</dict>
</plist>
PLIST

# 5. Ad-hoc sign so UNUserNotificationCenter works on macOS 14+
codesign --force --deep --sign - "$APP"

echo "Built: $APP"
echo "Run:   open $APP"
