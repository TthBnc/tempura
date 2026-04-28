#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_DIR="$ROOT_DIR/.build/app/Tempura.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION" --product Tempura
ICON_PATH="$("$ROOT_DIR/Scripts/build_icon.sh")"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/.build/$CONFIGURATION/Tempura" "$MACOS_DIR/Tempura"
cp "$ICON_PATH" "$RESOURCES_DIR/Tempura.icns"

SPARKLE_FRAMEWORK="$ROOT_DIR/.build/$CONFIGURATION/Sparkle.framework"
if [[ -d "$SPARKLE_FRAMEWORK" ]]; then
    ditto "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/Sparkle.framework"
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/Tempura" >/dev/null 2>&1 || true
fi

if command -v codesign >/dev/null 2>&1; then
    if [[ -d "$FRAMEWORKS_DIR/Sparkle.framework" ]]; then
        codesign --force --deep --sign - "$FRAMEWORKS_DIR/Sparkle.framework" >/dev/null 2>&1 || true
    fi

    codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
fi

echo "$APP_DIR"
