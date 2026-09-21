#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_VERSION="$(cat "$ROOT/VERSION")"
if [[ "$APP_VERSION" != <->.<->.<-> ]]; then
  echo "VERSION must contain a major.minor.patch number." >&2
  exit 1
fi
APP_DIR="${1:?Usage: zsh build.command output/Blackout.app [--universal]}"
if [[ "$APP_DIR" != *.app || -e "$APP_DIR" || $# -gt 2 || ( $# -eq 2 && "$2" != --universal ) ]]; then
  echo "Choose a new .app output path; optional second argument: --universal." >&2
  exit 1
fi
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT
CONTENTS="$APP_DIR/Contents"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Blackout</string>
  <key>CFBundleDisplayName</key><string>Blackout</string>
  <key>CFBundleIdentifier</key><string>local.blackout.overlay</string>
  <key>CFBundleVersion</key><string>$APP_VERSION</string>
  <key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
  <key>CFBundleExecutable</key><string>Blackout</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST

ARCHITECTURES=("$(uname -m)")
if [[ "${2:-}" == --universal ]]; then ARCHITECTURES=(arm64 x86_64); fi
SOURCES=("$ROOT"/Sources/**/*.swift)
BINARIES=()
for arch in "${ARCHITECTURES[@]}"; do
  echo "Building Blackout $APP_VERSION ($arch)..."
  binary="$BUILD_DIR/Blackout-$arch"
  xcrun swiftc -O -target "$arch-apple-macosx13.0" -sdk "$SDK_PATH" \
    -framework AppKit -framework CoreGraphics -framework Carbon \
    -framework Security -framework ServiceManagement \
    "${SOURCES[@]}" -o "$binary"
  BINARIES+=("$binary")
done
xcrun lipo -create "${BINARIES[@]}" -output "$CONTENTS/MacOS/Blackout"
cp -R "$ROOT"/Resources/Localization/. "$CONTENTS/Resources/"
cp "$ROOT/LICENSE" "$CONTENTS/Resources/LICENSE"
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
