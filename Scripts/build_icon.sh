#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SVG_PATH="$ROOT_DIR/Assets/AppIcon.svg"
BUILD_DIR="$ROOT_DIR/.build/icon"
ICONSET_DIR="$BUILD_DIR/Tempura.iconset"
BASE_PNG="$BUILD_DIR/AppIcon.png"
ICNS_PATH="$BUILD_DIR/Tempura.icns"

rm -rf "$ICONSET_DIR"
mkdir -p "$BUILD_DIR" "$ICONSET_DIR"
rm -f "$BASE_PNG" "$ICNS_PATH" "$BUILD_DIR/AppIcon.svg.png"

qlmanage -t -s 1024 -o "$BUILD_DIR" "$SVG_PATH" >/dev/null 2>&1

if [[ -f "$BUILD_DIR/AppIcon.svg.png" ]]; then
    mv "$BUILD_DIR/AppIcon.svg.png" "$BASE_PNG"
elif [[ ! -f "$BASE_PNG" ]]; then
    echo "Failed to render $SVG_PATH" >&2
    exit 1
fi

make_icon() {
    local size="$1"
    local name="$2"
    sips -z "$size" "$size" "$BASE_PNG" --out "$ICONSET_DIR/$name" >/dev/null
}

make_icon 16 "icon_16x16.png"
make_icon 32 "icon_16x16@2x.png"
make_icon 32 "icon_32x32.png"
make_icon 64 "icon_32x32@2x.png"
make_icon 128 "icon_128x128.png"
make_icon 256 "icon_128x128@2x.png"
make_icon 256 "icon_256x256.png"
make_icon 512 "icon_256x256@2x.png"
make_icon 512 "icon_512x512.png"
make_icon 1024 "icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"

echo "$ICNS_PATH"
