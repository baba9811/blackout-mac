#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_VERSION="$(cat "$ROOT/VERSION")"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
OUTPUT="$ROOT/dist"
mkdir -p "$OUTPUT" "$STAGING/BlackoutMac"
zsh "$SCRIPT_DIR/build.command" "$STAGING/BlackoutMac/Blackout.app" --universal
ln -s /Applications "$STAGING/BlackoutMac/Applications"
cp "$ROOT/README.md" "$STAGING/BlackoutMac/README.md"
cp "$ROOT/LICENSE" "$STAGING/BlackoutMac/LICENSE"
hdiutil create -ov -volname BlackoutMac -srcfolder "$STAGING/BlackoutMac" \
  -format UDZO "$OUTPUT/BlackoutMac-$APP_VERSION-universal.dmg"
ditto -c -k --sequesterRsrc --keepParent "$STAGING/BlackoutMac/Blackout.app" \
  "$OUTPUT/BlackoutMac-$APP_VERSION-universal.zip"
(cd "$OUTPUT" && shasum -a 256 "BlackoutMac-$APP_VERSION-universal.dmg" "BlackoutMac-$APP_VERSION-universal.zip" > SHA256SUMS)
echo "Release files: $OUTPUT"
echo "Local ad-hoc signature only; these downloads are not Apple-notarized."
