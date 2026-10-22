# Changelog

## 0.1.0

First release of MacClean, an open-source app uninstaller and cleaner for macOS 13 and newer.

- **Apps**: lists installed apps with sizes, shows the files each one left in `~/Library`, and moves the app and its leftovers to the Trash.
- **Installers**: finds `.dmg`, `.pkg` and `.xip` files in Downloads and Desktop and marks the ones whose app is already installed.
- **Clean**: measures user caches, logs, Xcode DerivedData, iOS device support, simulator caches, npm and Gradle caches and the Trash, and removes what you tick.
- Checks GitHub for new versions once a day, with a manual check in the app menu.
- Install with Homebrew: `brew tap temidayomichael/macclean https://github.com/Temidayomichael/macclean` then `brew install --cask macclean`
- One-line install from source: `curl -fsSL https://raw.githubusercontent.com/Temidayomichael/macclean/main/scripts/install.sh | bash`
