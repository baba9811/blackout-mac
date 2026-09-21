#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

xcrun swiftc "$ROOT/Sources/Core/Security/PasswordSettings.swift" \
  "$ROOT/Tests/Security/PasswordSettingsTests.swift" -o "$TEST_DIR/password"
"$TEST_DIR/password"
xcrun swiftc "$ROOT/Sources/Platform/Input/InputBlocker.swift" \
  "$ROOT/Tests/Input/InputBlockerTests.swift" -o "$TEST_DIR/input"
"$TEST_DIR/input"
xcrun swiftc "$ROOT/Sources/Core/Localization/AppLanguage.swift" \
  "$ROOT/Tests/Localization/LocalizationTests.swift" -o "$TEST_DIR/localization"
"$TEST_DIR/localization" "$ROOT/Resources/Localization"
xcrun swiftc "$ROOT/Sources/Core/Updates/ReleaseVersion.swift" \
  "$ROOT/Sources/Platform/Updates/ReleaseChecker.swift" \
  "$ROOT/Tests/Updates/ReleaseCheckerTests.swift" -o "$TEST_DIR/updates"
"$TEST_DIR/updates"
