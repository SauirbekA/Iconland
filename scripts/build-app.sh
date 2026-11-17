#!/bin/zsh
# Builds build/Iconland.app (release, ad-hoc signed). Usage: scripts/build-app.sh [--install] [--run]
set -euo pipefail
cd "${0:A:h}/.."
APP=build/Iconland.app
VERSION=$(cat VERSION)

swift build -c release
BIN=$(swift build -c release --show-bin-path)/Iconland

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Iconland"
rsync -a --delete --exclude '.DS_Store' web/ "$APP/Contents/Resources/web/"
[[ -f assets/AppIcon.icns ]] && cp assets/AppIcon.icns "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Iconland</string>
  <key>CFBundleDisplayName</key><string>Iconland</string>
  <key>CFBundleIdentifier</key><string>local.iconland.app</string>
  <key>CFBundleExecutable</key><string>Iconland</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.lifestyle</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Iconland reads the positions of your desktop icons from Finder so the scenery can form around them. It never reads file contents.</string>
  <key>NSHumanReadableCopyright</key><string>GPL-3.0. Based on Deskland Preview (github.com/BLEZZ0102/Deskland).</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - --identifier local.iconland.app "$APP"
echo "Built $APP ($VERSION)"

if [[ "${1:-}" == "--install" || "${2:-}" == "--install" ]]; then
  pkill -x Iconland 2>/dev/null && sleep 1 || true
  mkdir -p ~/Applications
  rm -rf ~/Applications/Iconland.app
  cp -R "$APP" ~/Applications/
  echo "Installed to ~/Applications/Iconland.app"
  APP=~/Applications/Iconland.app
fi
if [[ "${1:-}" == "--run" || "${2:-}" == "--run" ]]; then
  open "$APP"
fi
