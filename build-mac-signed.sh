#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$("$ROOT_DIR/build.sh")"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Claude Pop"
DMG_PATH="$DIST_DIR/Claude-Pop.dmg"

: "${DEVELOPER_ID_APP:?Set DEVELOPER_ID_APP to your Developer ID Application identity.}"

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

codesign --force --deep --options runtime --sign "$DEVELOPER_ID_APP" "$APP_DIR"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$APP_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_DIR"
  xcrun stapler staple "$DMG_PATH"
fi

echo "$DMG_PATH"
