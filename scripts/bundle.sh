#!/bin/bash
# Builds MacClean in release mode and wraps it in a double-clickable .app bundle.
# Usage: scripts/bundle.sh            -> build/MacClean.app
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release

BIN="$(swift build -c release --show-bin-path)/MacClean"
APP="build/MacClean.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MacClean"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
echo -n "APPL????" > "$APP/Contents/PkgInfo"

# Ad-hoc signature so Gatekeeper lets the app launch after right-click > Open.
codesign --force --sign - "$APP"

echo "Built $APP"
