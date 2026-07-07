#!/bin/sh
set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="DynamicPageKit Studio.app"
APP_DIR="$ROOT_DIR/StudioApp/Build/$APP_NAME"
EXECUTABLE="$ROOT_DIR/.build/debug/DynamicPageKitStudio"

cd "$ROOT_DIR"
env CLANG_MODULE_CACHE_PATH=.build/ModuleCache swift build

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$ROOT_DIR/StudioApp/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/StudioApp/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/DynamicPageKitStudio"
chmod +x "$APP_DIR/Contents/MacOS/DynamicPageKitStudio"

codesign --force --sign - "$APP_DIR" >/dev/null
echo "$APP_DIR"
