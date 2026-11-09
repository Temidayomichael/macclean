# Changelog

## 0.2.1

- Maintenance release used to try **Install Update** end to end from 0.2.0. No changes to the app itself.

## 0.2.0

- **Clean Mode**: locks the keyboard, trackpad and mouse so you can wipe your Mac without typing, clicking or triggering shortcuts. Pick 30 seconds to 10 minutes; a countdown shows on every screen, and holding Escape for 3 seconds unlocks early. Needs Accessibility access for a full lock; without it, typing and clicks are still blocked.
- New **Keyboard** tab with the Clean Mode controls, permission status and tips, plus a **Clean Mode** menu with ⇧⌘L.
- Optional **menu bar icon** to start Clean Mode without opening the window. While it is shown, MacClean keeps running after the window is closed.
- **Install Update** in the update banner downloads the new release, swaps it in for the running copy and reopens it. Download is still there for doing it by hand.

## 0.1.0

First release of MacClean, an open-source app uninstaller and cleaner for macOS 13 and newer.

- **Apps**: lists installed apps with sizes, shows the files each one left in `~/Library`, and moves the app and its leftovers to the Trash.
- **Installers**: finds `.dmg`, `.pkg` and `.xip` files in Downloads and Desktop and marks the ones whose app is already installed.
- **Clean**: measures user caches, logs, Xcode DerivedData, iOS device support, simulator caches, npm and Gradle caches and the Trash, and removes what you tick.
- Checks GitHub for new versions once a day, with a manual check in the app menu.
- Install with Homebrew: `brew tap temidayomichael/macclean https://github.com/Temidayomichael/macclean` then `brew install --cask macclean`
- One-line install from source: `curl -fsSL https://raw.githubusercontent.com/Temidayomichael/macclean/main/scripts/install.sh | bash`
