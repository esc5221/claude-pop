#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Claude Pop"
PRODUCT_NAME="claude-pop"
BUILD_DIR="$ROOT_DIR/build"
RESOURCES_DIR="$BUILD_DIR/resources"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
APP_RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"

rm -rf "$APP_DIR" "$RESOURCES_DIR" "$ICONSET_DIR"
mkdir -p "$MACOS_DIR" "$APP_RESOURCES_DIR" "$RESOURCES_DIR"

swift build -c release --package-path "$ROOT_DIR"

swift "$ROOT_DIR/scripts/generate_icon.swift" "$RESOURCES_DIR/AppIcon.png"
swift "$ROOT_DIR/scripts/generate_menubar_icon.swift" "$RESOURCES_DIR/MenuBarIconTemplate.png"

mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$RESOURCES_DIR/AppIcon.png" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$RESOURCES_DIR/AppIcon.png" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$RESOURCES_DIR/AppIcon.png" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$RESOURCES_DIR/AppIcon.png" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$RESOURCES_DIR/AppIcon.png" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$RESOURCES_DIR/AppIcon.png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$RESOURCES_DIR/AppIcon.png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$RESOURCES_DIR/AppIcon.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$RESOURCES_DIR/AppIcon.png" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$RESOURCES_DIR/AppIcon.png" "$ICONSET_DIR/icon_512x512@2x.png"
iconutil -c icns "$ICONSET_DIR" -o "$APP_RESOURCES_DIR/AppIcon.icns"

cp "$ROOT_DIR/.build/release/$PRODUCT_NAME" "$MACOS_DIR/$PRODUCT_NAME"
cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$RESOURCES_DIR/MenuBarIconTemplate.png" "$APP_RESOURCES_DIR/MenuBarIconTemplate.png"

chmod +x "$MACOS_DIR/$PRODUCT_NAME"

echo "$APP_DIR"
