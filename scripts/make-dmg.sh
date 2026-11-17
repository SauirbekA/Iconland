#!/bin/zsh
# Builds build/Iconland-<version>.dmg: app + "Applications" link + one-click "Установить" script + instructions background.
# Usage: scripts/make-dmg.sh
set -euo pipefail
cd "${0:A:h}/.."
VERSION=$(cat VERSION)
NAME="Iconland"
DMG="build/$NAME-$VERSION.dmg"
STAGE="build/dmg-stage"
RW="build/dmg-rw.dmg"

scripts/build-app.sh

rm -rf "$STAGE" "$RW" "$DMG"
mkdir -p "$STAGE/.background"
cp -R "build/$NAME.app" "$STAGE/"
ln -s /Applications "$STAGE/Программы"
swift scripts/make-dmg-background.swift "$STAGE/.background/bg.png"

cat > "$STAGE/Установить.command" <<'SCRIPT'
#!/bin/zsh
# Installs Iconland into /Applications and launches it.
SRC="${0:A:h}/Iconland.app"
DEST="/Applications/Iconland.app"
echo "Устанавливаю Iconland…"
pkill -x Iconland 2>/dev/null && sleep 1
rm -rf "$DEST"
if ! cp -R "$SRC" /Applications/ 2>/dev/null; then
  echo "Нужен пароль администратора:"
  sudo rm -rf "$DEST" && sudo cp -R "$SRC" /Applications/ || { echo "Не удалось установить."; read -k1; exit 1; }
fi
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || sudo xattr -dr com.apple.quarantine "$DEST"
open "$DEST"
echo ""
echo "Готово! Iconland установлен и запущен."
echo "Если появится запрос на управление Finder — нажмите «Разрешить»."
echo "Это окно можно закрыть."
osascript -e 'tell application "Terminal" to close (every window whose name contains "Установить")' >/dev/null 2>&1 &
SCRIPT
chmod +x "$STAGE/Установить.command"

# Writable image → lay out the Finder window → compress.
hdiutil create -quiet -srcfolder "$STAGE" -volname "$NAME" -fs HFS+ -format UDRW -ov "$RW"
MNT=$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | awk -F'\t' '/\/Volumes\//{print $NF}')
sleep 1
if ! osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 840, 588}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 96
    set text size of opts to 13
    set background picture of opts to file ".background:bg.png"
    set position of item "Установить.command" of container window to {320, 120}
    set position of item "$NAME.app" of container window to {180, 250}
    set position of item "Программы" of container window to {460, 250}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT
then
  echo "warning: couldn't style the DMG window (Finder automation denied?) — DMG still works."
fi
sync
hdiutil detach -quiet "$MNT"
hdiutil convert -quiet "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG"
rm -rf "$RW" "$STAGE"
echo "Built $DMG"
