#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$HOME/Applications/Blackout.app"
mkdir -p "$(dirname "$APP_DIR")"
# Keep both renames on the installation filesystem.
BUILD_DIR="$(mktemp -d "$(dirname "$APP_DIR")/.Blackout-install.XXXXXX")"
INSTALL_COMPLETE=false
cleanup() {
  if [[ "$INSTALL_COMPLETE" == false && ( -e "$BUILD_DIR/Previous.app" || -L "$BUILD_DIR/Previous.app" ) ]]; then
    if [[ -e "$APP_DIR" || -L "$APP_DIR" ]] || ! mv "$BUILD_DIR/Previous.app" "$APP_DIR"; then
      echo "Could not restore the previous app. It is preserved at: $BUILD_DIR/Previous.app" >&2
      return
    fi
  fi
  rm -rf "$BUILD_DIR"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Apple Command Line Tools are required once to build Blackout.app."
  echo "Opening Apple's installer..."
  xcode-select --install || true
  echo
  echo "After Command Line Tools finish installing, run install.command again."
  read -k 1 "?Press any key to close..."
  exit 1
fi

zsh "$SCRIPT_DIR/build.command" "$BUILD_DIR/Blackout.app"

echo "Stopping the previous Blackout, if it is running..."
pkill -x Blackout >/dev/null 2>&1 || true
sleep 0.3
echo "Replacing the previous local build..."
if [[ -e "$APP_DIR" || -L "$APP_DIR" ]]; then
  mv "$APP_DIR" "$BUILD_DIR/Previous.app"
fi
mv "$BUILD_DIR/Blackout.app" "$APP_DIR"
INSTALL_COMPLETE=true

echo
echo "Installed: $APP_DIR"
echo "Starting Blackout..."
open "$APP_DIR"
echo
echo "Use Control + Option + B (⌃⌥B) to black out ALL detected displays."
echo "Dock/menu bar/ordinary notifications should be covered."
echo "Move the mouse, click, scroll, or press a key to restore (or enter your password if enabled)."
echo "Open Settings from the Blackout menu bar icon for password protection and launch at login."
