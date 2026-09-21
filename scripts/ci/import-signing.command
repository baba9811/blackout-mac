#!/bin/zsh
set -euo pipefail
umask 077

: "${RUNNER_TEMP:?Use a private temporary runner directory}"
: "${GITHUB_ENV:?Missing workflow environment file}"
: "${BLACKOUT_SIGN_CERT_BASE64:?Missing signing certificate secret}"
: "${BLACKOUT_SIGN_CERT_PASSWORD:?Missing signing certificate password secret}"
: "${BLACKOUT_SIGN_IDENTITY:?Missing expected certificate fingerprint}"
[[ "$BLACKOUT_SIGN_IDENTITY" =~ '^[[:xdigit:]]{40}$' ]] || { echo 'Invalid certificate fingerprint' >&2; exit 1; }

CERT_PATH="$RUNNER_TEMP/blackout-signing.p12"
KEYCHAIN_PATH="$RUNNER_TEMP/blackout-signing.keychain-db"
[[ ! -e "$CERT_PATH" && ! -e "$KEYCHAIN_PATH" ]] || { echo 'Signing staging already exists' >&2; exit 1; }
trap 'rm -f "$CERT_PATH"' EXIT
print -rn -- "$BLACKOUT_SIGN_CERT_BASE64" | /usr/bin/base64 --decode > "$CERT_PATH"
KEYCHAIN_PASSWORD="$(/usr/bin/openssl rand -hex 32)"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 3600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$CERT_PATH" -k "$KEYCHAIN_PATH" -P "$BLACKOUT_SIGN_CERT_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null
# macOS 26 also requires the keychain in the search list, even with codesign --keychain.
python3 - "$KEYCHAIN_PATH" <<'PY'
import shlex, subprocess, sys
keychains = shlex.split(subprocess.check_output(["security", "list-keychains", "-d", "user"], text=True))
subprocess.run(["security", "list-keychains", "-d", "user", "-s", *keychains, sys.argv[1]], check=True)
PY
print -r -- "BLACKOUT_SIGN_IDENTITY=$BLACKOUT_SIGN_IDENTITY" >> "$GITHUB_ENV"
print -r -- "BLACKOUT_SIGN_KEYCHAIN=$KEYCHAIN_PATH" >> "$GITHUB_ENV"
