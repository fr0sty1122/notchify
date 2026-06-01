#!/usr/bin/env bash
set -euo pipefail

# dev.sh - build Notchify and (re)launch it.
#
# Usage:
#   ./Scripts/dev.sh           Build once, then relaunch the app.
#   ./Scripts/dev.sh --watch   Build + relaunch, then keep watching the
#                              Notchify sources and rebuild on every change.
#
# This runs the app straight from ./build (not /Applications) so iteration
# stays fast. Use ./Scripts/install.sh when you want it in /Applications.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Notchify"
APP_DIR="${ROOT}/build/${APP_NAME}.app"
SRC_DIR="${ROOT}/Notchify"

build_and_run() {
  echo "==> Building ${APP_NAME} ..."
  if ! "${ROOT}/Scripts/build.sh"; then
    echo "[x] Build failed - leaving the running instance untouched." >&2
    return 1
  fi

  # Stop any instance we previously launched so the new binary takes over.
  if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
    echo "==> Stopping running ${APP_NAME} ..."
    pkill -x "${APP_NAME}" || true
    # Give the process a moment to release the status bar item.
    sleep 0.4
  fi

  echo "==> Launching ${APP_NAME} ..."
  open "${APP_DIR}"
  echo "[ok] ${APP_NAME} is running ($(date '+%H:%M:%S'))."
}

# A signature of the current source tree (paths + mtimes). When it changes,
# we know to rebuild. Works without any extra tooling installed.
source_signature() {
  find "${SRC_DIR}" -type f \
    \( -name '*.swift' -o -name 'Info.plist' -o -name '*.entitlements' \) \
    -exec stat -f '%N %m' {} + 2>/dev/null | sort
}

watch_loop() {
  echo "==> Watching ${SRC_DIR} for changes (Ctrl-C to stop) ..."

  if command -v fswatch >/dev/null 2>&1; then
    # Preferred: event-driven via fswatch.
    build_and_run || true
    # -o batches events into a single line per burst.
    fswatch -o -l 0.4 \
      --event Created --event Updated --event Removed --event Renamed \
      "${SRC_DIR}" | while read -r _; do
      build_and_run || true
    done
  else
    echo "    (fswatch not found - using a 1s polling fallback."
    echo "     Install with 'brew install fswatch' for instant rebuilds.)"
    local last current
    build_and_run || true
    last="$(source_signature)"
    while true; do
      sleep 1
      current="$(source_signature)"
      if [[ "${current}" != "${last}" ]]; then
        last="${current}"
        build_and_run || true
      fi
    done
  fi
}

case "${1:-}" in
  --watch|-w)
    watch_loop
    ;;
  "")
    build_and_run
    ;;
  *)
    echo "Usage: $0 [--watch]" >&2
    exit 64
    ;;
esac
