#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Notchify"
BUILD_DIR="$ROOT/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
MODULE_CACHE="$BUILD_DIR/ModuleCache"

rm -rf "$APP_DIR" "$MODULE_CACHE"
mkdir -p "$MACOS" "$RESOURCES" "$MODULE_CACHE"

# Build a universal binary (Apple Silicon + Intel) when both toolchain slices
# are available, so the app runs on every Mac from macOS 14 on. Falls back to
# the host architecture only if a cross-compile slice is unavailable.
COMMON_FLAGS=(
  -swift-version 5
  -module-cache-path "$MODULE_CACHE"
  -parse-as-library
  -O
  -framework AppKit
  -framework SwiftUI
  -framework Combine
  -framework AVFoundation
  -framework ApplicationServices
  -framework ServiceManagement
  -framework Carbon
)

# Collect every Swift source under Notchify/ (recursively). Using `find`
# rather than a glob keeps this working regardless of the shell's globstar
# setting.
SOURCES=()
while IFS= read -r -d '' file; do
  SOURCES+=("$file")
done < <(find "$ROOT/Notchify" -name '*.swift' -print0)

build_slice() {
  local arch="$1" out="$2"
  /usr/bin/swiftc \
    -target "${arch}-apple-macos14.0" \
    "${COMMON_FLAGS[@]}" \
    "${SOURCES[@]}" \
    -o "$out" 2>/dev/null
}

ARM_BIN="$BUILD_DIR/Notchify-arm64"
X86_BIN="$BUILD_DIR/Notchify-x86_64"
rm -f "$ARM_BIN" "$X86_BIN"

ARCHS=()
if build_slice arm64 "$ARM_BIN"; then ARCHS+=("$ARM_BIN"); fi
if build_slice x86_64 "$X86_BIN"; then ARCHS+=("$X86_BIN"); fi

if [ "${#ARCHS[@]}" -eq 0 ]; then
  echo "error: failed to compile any architecture slice" >&2
  exit 1
elif [ "${#ARCHS[@]}" -eq 1 ]; then
  cp "${ARCHS[0]}" "$MACOS/$APP_NAME"
  echo "Note: built single-architecture binary (other slice unavailable)."
else
  lipo -create "${ARCHS[@]}" -output "$MACOS/$APP_NAME"
fi
rm -f "$ARM_BIN" "$X86_BIN"

cp "$ROOT/Notchify/Info.plist" "$CONTENTS/Info.plist"
cp -R "$ROOT/Notchify/Assets" "$RESOURCES/Assets"

# Generate (if needed) and install the app icon at the path Info.plist's
# CFBundleIconFile expects: Contents/Resources/AppIcon.icns.
if [ ! -f "$ROOT/Notchify/Assets/AppIcon.icns" ] || \
   [ "$ROOT/Notchify/Assets/AppIcon.png" -nt "$ROOT/Notchify/Assets/AppIcon.icns" ]; then
  bash "$ROOT/Scripts/make-icon.sh"
fi
cp "$ROOT/Notchify/Assets/AppIcon.icns" "$RESOURCES/AppIcon.icns"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - \
    --entitlements "$ROOT/Notchify/Notchify.entitlements" \
    "$APP_DIR" >/dev/null
fi

echo "Built $APP_DIR"
