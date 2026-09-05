#!/bin/bash
set -e

APP_NAME="LLM Limits"
BUNDLE_NAME="LLM Limits.app"
EXECUTABLE="LLMLimits"
INSTALL_DIR="/Applications"

echo "Building $APP_NAME..."
swift build -c release

echo "Creating app bundle..."
BUNDLE_DIR="$INSTALL_DIR/$BUNDLE_NAME"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

cp .build/release/$EXECUTABLE "$BUNDLE_DIR/Contents/MacOS/$EXECUTABLE"
cp Resources/AppIcon.icns "$BUNDLE_DIR/Contents/Resources/AppIcon.icns"
cp Resources/Assets.car "$BUNDLE_DIR/Contents/Resources/Assets.car"

cat > "$BUNDLE_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleExecutable</key>
    <string>LLMLimits</string>
    <key>CFBundleIdentifier</key>
    <string>com.moka.llm-limits</string>
    <key>CFBundleName</key>
    <string>LLM Limits</string>
    <key>CFBundleDisplayName</key>
    <string>LLM Limits</string>
    <key>CFBundleVersion</key>
    <string>1.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "Installed to $BUNDLE_DIR"
echo "Launching $APP_NAME..."
open "$BUNDLE_DIR"
