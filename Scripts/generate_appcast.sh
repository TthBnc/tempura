#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
DMG_PATH="${1:-$DIST_DIR/Tempura.dmg}"
UPDATE_DIR="$ROOT_DIR/.build/update-feed"
APPCAST_NAME="appcast.xml"
APPCAST_PATH="$DIST_DIR/$APPCAST_NAME"
SPARKLE_BIN_DIR="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin"
SPARKLE_ACCOUNT="${SPARKLE_ACCOUNT:-com.tebe.tempura}"

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT_DIR/Packaging/Info.plist")"

if [[ ! -f "$DMG_PATH" ]]; then
    echo "Missing DMG at $DMG_PATH" >&2
    exit 1
fi

if [[ ! -x "$SPARKLE_BIN_DIR/generate_appcast" ]]; then
    echo "Missing Sparkle generate_appcast tool. Run swift package resolve first." >&2
    exit 1
fi

rm -rf "$UPDATE_DIR"
mkdir -p "$UPDATE_DIR" "$DIST_DIR"
cp "$DMG_PATH" "$UPDATE_DIR/Tempura.dmg"

"$SPARKLE_BIN_DIR/generate_appcast" \
    --account "$SPARKLE_ACCOUNT" \
    --download-url-prefix "https://github.com/TthBnc/tempura/releases/download/v$VERSION/" \
    --full-release-notes-url "https://github.com/TthBnc/tempura/releases/tag/v$VERSION" \
    --link "https://github.com/TthBnc/tempura" \
    -o "$APPCAST_NAME" \
    "$UPDATE_DIR" >/dev/null

cp "$UPDATE_DIR/$APPCAST_NAME" "$APPCAST_PATH"
echo "$APPCAST_PATH"
