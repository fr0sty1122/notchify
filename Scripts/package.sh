#!/usr/bin/env bash
set -euo pipefail

# package.sh - build Notchify and produce a polished, HiDPI .dmg with a
# drag-to-Applications layout, a retina-sharp background, and a branded volume
# icon (and an icon on the .dmg file itself), the way Apple installers look.
#
# Output: dist/Notchify-<version>.dmg
#
# Distribution note: ad-hoc code signing. The app runs; Gatekeeper warns on
# first open until you sign + notarize with a Developer ID (commands at end).

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Notchify"
VOL_NAME="Notchify"
BUILD_DIR="$ROOT/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
DIST_DIR="$ROOT/dist"
STAGING="$BUILD_DIR/dmg-staging"
BG_SVG="$ROOT/Notchify/Assets/DMGBackground.svg"
ICNS="$ROOT/Notchify/Assets/AppIcon.icns"
RW_DMG="$BUILD_DIR/${APP_NAME}-rw.dmg"

# Window + layout geometry (points).
WIN_W=640
WIN_H=400
ICON_SIZE=128
APP_X=160; APP_Y=205
APPS_X=480; APPS_Y=205

# 1. Build the app bundle (universal binary + icon).
"$ROOT/Scripts/build.sh"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist" 2>/dev/null || echo "0.0.0")"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"

mkdir -p "$DIST_DIR"
rm -rf "$STAGING"; mkdir -p "$STAGING"

# 2. Stage app + Applications shortcut + volume icon.
cp -R "$APP_DIR" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"
cp "$ICNS" "$STAGING/.VolumeIcon.icns"

# 3. HiDPI background: render @1x and @2x PNGs, then combine into a single
#    multi-resolution TIFF. Retina displays use the @2x rep, so it stays crisp
#    instead of upscaling a 1x image (which is what looked blurry).
mkdir -p "$STAGING/.background"
sips -s format png -z "$WIN_H" "$WIN_W" "$BG_SVG" \
  --out "$BUILD_DIR/bg-1x.png" >/dev/null 2>&1
sips -s format png -z "$((WIN_H * 2))" "$((WIN_W * 2))" "$BG_SVG" \
  --out "$BUILD_DIR/bg-2x.png" >/dev/null 2>&1
tiffutil -cathidpicheck "$BUILD_DIR/bg-1x.png" "$BUILD_DIR/bg-2x.png" \
  -out "$STAGING/.background/background.tiff" >/dev/null 2>&1
rm -f "$BUILD_DIR/bg-1x.png" "$BUILD_DIR/bg-2x.png"

# 4. (Volume icon is added after mount, below.)

# 5. Create a read-write DMG and mount it at /Volumes/<name>.
rm -f "$RW_DMG" "$DMG_PATH"
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGING" \
  -fs HFS+ -format UDRW -ov "$RW_DMG" >/dev/null

MOUNT_DIR="/Volumes/$VOL_NAME"
cleanup() { hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1 || true; }
cleanup
# Capture the real mount point hdiutil chooses (avoids name-collision surprises).
MOUNT_DIR="$(hdiutil attach "$RW_DMG" -nobrowse -noverify -noautoopen | awk -F'\t' '/\/Volumes\//{print $NF}' | tail -1)"
if [ -z "$MOUNT_DIR" ] || [ ! -d "$MOUNT_DIR" ]; then
  echo "error: failed to mount staging DMG" >&2
  exit 1
fi
trap cleanup EXIT

# Branded volume icon: staged on the volume; final bless happens after the
# Finder layout (Finder's window update can drop a freshly-blessed icon).
[ -f "$MOUNT_DIR/.VolumeIcon.icns" ] && echo "  volume icon staged" || echo "  WARN: volume icon not written"

# 6. Lay out the Finder window: HiDPI background, icon positions, no toolbar.
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 140, 200 + $WIN_W, 140 + $WIN_H}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to $ICON_SIZE
    set text size of theViewOptions to 13
    set background picture of theViewOptions to POSIX file "$MOUNT_DIR/.background/background.tiff"
    set position of item "$APP_NAME.app" of container window to {$APP_X, $APP_Y}
    set position of item "Applications" of container window to {$APPS_X, $APPS_Y}
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

# Re-assert the volume icon AFTER Finder's layout (which can drop the hidden
# icon file / un-bless the volume), then commit.
cp "$ICNS" "$MOUNT_DIR/.VolumeIcon.icns"
SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
SetFile -a V "$MOUNT_DIR/.VolumeIcon.icns" 2>/dev/null || true

sync
cleanup
trap - EXIT

# 7. Convert to a compressed, read-only DMG for distribution.
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG_PATH" >/dev/null
rm -f "$RW_DMG"

# 8. Give the .dmg FILE itself the app icon (so it shows the logo in Finder).
#    Dependency-free: derive an 'icns' resource from the icns, attach it to the
#    file's resource fork, and flag the file as having a custom icon.
ICON_TMP="$BUILD_DIR/dmgicon"
rm -rf "$ICON_TMP"; mkdir -p "$ICON_TMP"
# sips can embed an icns into a throwaway file, then DeRez extracts the icon
# resource we Rez back onto the dmg.
cp "$ICNS" "$ICON_TMP/icon.icns"
if sips -i "$ICON_TMP/icon.icns" >/dev/null 2>&1; then
  DeRez -only icns "$ICON_TMP/icon.icns" > "$ICON_TMP/icon.rsrc" 2>/dev/null || true
  if [ -s "$ICON_TMP/icon.rsrc" ]; then
    Rez -append "$ICON_TMP/icon.rsrc" -o "$DMG_PATH" 2>/dev/null || true
    SetFile -a C "$DMG_PATH" 2>/dev/null || true
  fi
fi
rm -rf "$ICON_TMP"
rm -rf "$STAGING"

echo "Packaged $DMG_PATH"
echo ""
echo "Open the .dmg and drag $APP_NAME onto the Applications folder."
echo ""
echo "For a Gatekeeper-clean release, sign + notarize with a Developer ID:"
echo "  codesign --force --deep --options runtime \\"
echo "    --sign \"Developer ID Application: YOUR NAME (TEAMID)\" \\"
echo "    --entitlements \"$ROOT/Notchify/Notchify.entitlements\" \"$APP_DIR\""
echo "  xcrun notarytool submit \"$DMG_PATH\" --apple-id you@example.com \\"
echo "    --team-id TEAMID --password APP_SPECIFIC_PW --wait"
echo "  xcrun stapler staple \"$DMG_PATH\""
