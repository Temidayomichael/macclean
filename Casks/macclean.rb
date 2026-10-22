# Homebrew cask for MacClean.
#
#   brew tap temidayomichael/macclean https://github.com/Temidayomichael/macclean
#   brew install --cask macclean
#
# scripts/update_cask.sh pins the version and checksum after each release.
cask "macclean" do
  version :latest
  sha256 :no_check

  url "https://github.com/Temidayomichael/macclean/releases/latest/download/MacClean.zip"
  name "MacClean"
  desc "Uninstall apps completely and clean caches, logs and old installers"
  homepage "https://github.com/Temidayomichael/macclean"

  depends_on macos: ">= :ventura"

  app "MacClean.app"

  zap trash: [
    "~/Library/Preferences/io.github.temidayomichael.macclean.plist",
    "~/Library/Saved Application State/io.github.temidayomichael.macclean.savedState",
  ]
end
