cask "fleet" do
  version "1.1.0"
  sha256 "a2591ceda7ae3b3bb57345e66ab479367d7eeeac8f862795d973c50bdaf2f4e0"

  url "https://github.com/mrKangHo/Fleet/releases/download/v#{version}/Fleet-#{version}.zip"
  name "Fleet"
  desc "Track GitHub repository neglect and run AI agent tasks"
  homepage "https://github.com/mrKangHo/Fleet"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma
  depends_on arch: :arm64

  app "Fleet.app"

  zap trash: [
    "~/Library/Application Support/WorkManager",
    "~/Library/Caches/com.workmanager.macos",
    "~/Library/HTTPStorages/com.workmanager.macos",
    "~/Library/HTTPStorages/com.workmanager.macos.binarycookies",
    "~/Library/Preferences/com.workmanager.macos.plist",
  ]

  caveats <<~EOS
    Fleet is not yet code-signed or notarized. If macOS blocks it on first launch,
    right-click Fleet.app in Finder and choose "Open", or run:
      xattr -cr /Applications/Fleet.app
  EOS
end
