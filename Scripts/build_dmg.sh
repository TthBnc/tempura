#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/.build/app/Tempura.app"
STAGING_DIR="$ROOT_DIR/.build/dmg/Tempura"
DIST_DIR="$ROOT_DIR/dist"
DMG_PATH="$DIST_DIR/Tempura.dmg"

cd "$ROOT_DIR"
"$ROOT_DIR/Scripts/build_app.sh" >/dev/null

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR" "$DIST_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/Tempura.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "Tempura" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "$DMG_PATH"
