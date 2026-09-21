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
xcrun swiftc "$ROOT/Sources/Platform/Input/InputBlocker.swift" \
  "$ROOT/Tests/Input/PointerDeliveryTests.swift" -o "$TEST_DIR/pointer"
"$TEST_DIR/pointer"
xcrun swiftc "$ROOT/Sources/Core/Localization/AppLanguage.swift" \
  "$ROOT/Sources/Features/Blackout/UnlockView.swift" \
  "$ROOT/Tests/Blackout/UnlockViewTests.swift" -o "$TEST_DIR/unlock-view"
"$TEST_DIR/unlock-view"
xcrun swiftc "$ROOT/Sources/Platform/Input/InputBlocker.swift" \
  "$ROOT/Tests/Input/EmergencyExitProcessTests.swift" -o "$TEST_DIR/emergency-exit"
"$TEST_DIR/emergency-exit"
xcrun swiftc "$ROOT/Sources/Core/Security/PasswordSettings.swift" \
  "$ROOT/Sources/Core/Localization/AppLanguage.swift" \
  "$ROOT/Sources/App/PasswordError+Localization.swift" \
  "$ROOT/Sources/Features/Settings/PasswordSheetController.swift" \
  "$ROOT/Tests/Settings/PasswordSheetTests.swift" -o "$TEST_DIR/password-sheets"
"$TEST_DIR/password-sheets"
xcrun swiftc "$ROOT/Sources/Core/Security/PasswordSettings.swift" \
  "$ROOT/Sources/Core/Localization/AppLanguage.swift" \
  "$ROOT/Sources/Core/Updates/ReleaseVersion.swift" \
  "$ROOT/Sources/Platform/Updates/ReleaseChecker.swift" \
  "$ROOT/Sources/App/PasswordError+Localization.swift" \
  "$ROOT/Sources/Features/Settings/PasswordSheetController.swift" \
  "$ROOT/Sources/Features/Settings/SettingsWindowController.swift" \
  "$ROOT/Tests/Settings/PasswordToggleTests.swift" -o "$TEST_DIR/password-toggle"
"$TEST_DIR/password-toggle"
xcrun swiftc "$ROOT/Sources/Core/Localization/AppLanguage.swift" \
  "$ROOT/Tests/Localization/LocalizationTests.swift" -o "$TEST_DIR/localization"
"$TEST_DIR/localization" "$ROOT/Resources/Localization"
xcrun swiftc "$ROOT/Sources/Core/Updates/ReleaseVersion.swift" \
  "$ROOT/Sources/Platform/Updates/ReleaseChecker.swift" \
  "$ROOT/Tests/Updates/ReleaseCheckerTests.swift" -o "$TEST_DIR/updates"
"$TEST_DIR/updates"
python3 -B -m unittest discover -s "$ROOT/Tests/Installation" -v
python3 -B -m unittest discover -s "$ROOT/Tests/Signing" -v
