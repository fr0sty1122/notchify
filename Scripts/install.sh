#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/Scripts/build.sh"

APP_NAME="Notchify"
SRC="$ROOT/build/$APP_NAME.app"
DST="/Applications/$APP_NAME.app"

rm -rf "$DST"
cp -R "$SRC" "$DST"
open "$DST"

echo "Installed and launched $DST"

