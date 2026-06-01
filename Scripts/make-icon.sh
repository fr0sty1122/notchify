#!/usr/bin/env bash
set -euo pipefail

# make-icon.sh - rasterize the app logo into a macOS AppIcon.icns.
#
# Prefers Assets/AppIcon.png (the brand logo); falls back to AppIcon.svg.
# Produces every size macOS expects in an .iconset and compiles it with
# iconutil. build.sh calls this automatically so the bundle always carries
# the current icon.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PNG="${ROOT}/Notchify/Assets/AppIcon.png"
SVG="${ROOT}/Notchify/Assets/AppIcon.svg"
SOURCE="${PNG}"
if [ ! -f "${SOURCE}" ]; then SOURCE="${SVG}"; fi
OUT_ICNS="${ROOT}/Notchify/Assets/AppIcon.icns"
WORK="$(mktemp -d)"
ICONSET="${WORK}/AppIcon.iconset"
MASTER="${WORK}/master.png"

mkdir -p "${ICONSET}"

# Render a high-resolution master once, then downscale from it (downscaling
# gives cleaner results than rasterizing at every tiny size).
sips -s format png -z 1024 1024 "${SOURCE}" --out "${MASTER}" >/dev/null 2>&1

emit() {
  local size="$1" name="$2"
  sips -z "${size}" "${size}" "${MASTER}" --out "${ICONSET}/${name}" >/dev/null 2>&1
}

emit 16    "icon_16x16.png"
emit 32    "icon_16x16@2x.png"
emit 32    "icon_32x32.png"
emit 64    "icon_32x32@2x.png"
emit 128   "icon_128x128.png"
emit 256   "icon_128x128@2x.png"
emit 256   "icon_256x256.png"
emit 512   "icon_256x256@2x.png"
emit 512   "icon_512x512.png"
emit 1024  "icon_512x512@2x.png"

iconutil -c icns "${ICONSET}" -o "${OUT_ICNS}"
rm -rf "${WORK}"

echo "Built ${OUT_ICNS}"
