#!/bin/bash
# Cuts a release from your Mac, without GitHub Actions.
#
#   scripts/release.sh 0.2.0
#
# It sets the version in Info.plist, builds MacClean.app, zips it, pins the
# Homebrew cask to the zip, commits, tags v<version>, pushes, and (if the
# GitHub CLI is installed and logged in) creates the release and uploads the zip.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/release.sh <version>, for example 0.2.0}"
TAG="v$VERSION"
ZIP="build/MacClean.zip"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Commit or stash your changes first; the working tree must be clean." >&2
  exit 1
fi

echo "==> Setting version $VERSION in Resources/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Resources/Info.plist

echo "==> Building MacClean.app"
scripts/bundle.sh

echo "==> Zipping"
rm -f "$ZIP"
ditto -c -k --keepParent build/MacClean.app "$ZIP"

echo "==> Pinning the Homebrew cask"
scripts/update_cask.sh "$VERSION" "$ZIP"

echo "==> Committing and tagging $TAG"
git add Resources/Info.plist Casks/macclean.rb
git commit -m "Release $VERSION"
git tag -a "$TAG" -m "MacClean $VERSION"
git push origin HEAD "$TAG"

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  echo "==> Publishing the GitHub release"
  if gh release view "$TAG" >/dev/null 2>&1; then
    gh release upload "$TAG" "$ZIP" --clobber
  else
    NOTES="$(awk -v v="$VERSION" '
      $0 ~ "^## " v "$" { on = 1; next }
      /^## / && on { exit }
      on { print }' CHANGELOG.md)"
    gh release create "$TAG" "$ZIP" --title "MacClean $VERSION" --notes "${NOTES:-MacClean $VERSION}"
  fi
  echo "Done: https://github.com/Temidayomichael/macclean/releases/tag/$TAG"
else
  echo
  echo "GitHub CLI not found or not logged in, so finish the release by hand:"
  echo "  1. Open https://github.com/Temidayomichael/macclean/releases/new?tag=$TAG"
  echo "  2. Title it 'MacClean $VERSION' and paste the $VERSION section of CHANGELOG.md."
  echo "  3. Drag $(pwd)/$ZIP into 'Attach binaries' and publish."
  echo "(Install the CLI with 'brew install gh' and run 'gh auth login' to automate this next time.)"
fi
