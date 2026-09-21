#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$HOME/Applications/Blackout.app"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT
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
mkdir -p "$(dirname "$APP_DIR")"
rm -rf "$APP_DIR"
mv "$BUILD_DIR/Blackout.app" "$APP_DIR"

echo
echo "Installed: $APP_DIR"
echo "Starting Blackout..."
open "$APP_DIR"
echo
echo "Use Control + Option + B (⌃⌥B) to black out ALL detected displays."
echo "Dock/menu bar/ordinary notifications should be covered."
echo "Move the mouse, click, scroll, or press a key to restore (or enter your password if enabled)."
echo "Open Settings from the Blackout menu bar icon for password protection and launch at login."
