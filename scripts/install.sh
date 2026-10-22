#!/bin/bash
# Builds MacClean from source and installs it into /Applications.
#
#   curl -fsSL https://raw.githubusercontent.com/Temidayomichael/macclean/main/scripts/install.sh | bash
#
# Needs macOS 13 or newer and the Xcode Command Line Tools (xcode-select --install).
set -euo pipefail

REPO="https://github.com/Temidayomichael/macclean.git"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "MacClean only runs on macOS." >&2
  exit 1
fi

if ! command -v swift >/dev/null 2>&1 || ! xcode-select -p >/dev/null 2>&1; then
  echo "The Xcode Command Line Tools are needed to build MacClean." >&2
  echo "Install them with:  xcode-select --install   and run this script again." >&2
  exit 1
fi

# Build from the checkout we are in, or from a fresh temporary clone.
if [[ -f "$(dirname "$0")/bundle.sh" && -f "$(dirname "$0")/../Package.swift" ]]; then
  SRC="$(cd "$(dirname "$0")/.." && pwd)"
else
  SRC="$(mktemp -d /tmp/macclean.XXXXXX)"
  trap 'rm -rf "$SRC"' EXIT
  echo "Downloading MacClean source…"
  git clone --quiet --depth 1 "$REPO" "$SRC"
fi

echo "Building MacClean (this takes a minute the first time)…"
"$SRC/scripts/bundle.sh" >/dev/null

DEST="/Applications"
if [[ ! -w "$DEST" ]]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi

rm -rf "$DEST/MacClean.app"
cp -R "$SRC/build/MacClean.app" "$DEST/MacClean.app"

echo "Installed $DEST/MacClean.app"
open "$DEST/MacClean.app"
