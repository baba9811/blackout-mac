# Development

Run commands from the repository root. Source builds require Apple Command Line Tools or Xcode with the macOS 26 SDK or later (`xcode-select --install` installs the tools available for your OS). The downloaded app still supports macOS 13 and later. Regular users should use the [DMG download](https://github.com/baba9811/blackout-mac/releases), which needs no compiler or terminal.

## Local build and install

```sh
zsh scripts/install.command
```

The installer builds a staged app before replacing `~/Applications/Blackout.app`. It preserves preferences, stops the old process, and launches the new app. Without a configured signing certificate, development builds use ad-hoc signing and input-control permission can require renewal after each rebuild. The system panel is Device Control and Data Access on macOS 27, or Accessibility on macOS 13–26.

To build without installing, choose a new output path:

```sh
zsh scripts/build.command /tmp/Blackout.app
```

To retain the same code identity across development builds, create a code-signing certificate with Keychain Access's Certificate Assistant, or import an existing identity into your login keychain. A self-signed code-signing certificate is sufficient for local identity continuity; do not add system-wide trust or disable Gatekeeper. Find its full SHA-1 fingerprint with `security find-identity -p codesigning` and configure this checkout once:

```sh
git config --local blackout.signingIdentity CERTIFICATE_SHA1_FINGERPRINT
zsh scripts/install.command
```

The fingerprint is public metadata; the private key stays in Keychain. This Git setting is local and is not committed or inherited by a fresh clone. `BLACKOUT_SIGN_IDENTITY` overrides it for a build; `-` explicitly requests an ad-hoc development build. `BLACKOUT_SIGN_KEYCHAIN` selects a separate keychain for CI. An invalid or unavailable configured identity stops the build; it never falls back to an ad-hoc signature. Keep the same certificate and bundle identifier for subsequent updates. Switching from an old ad-hoc build, losing the private key, or changing the certificate can require a permission renewal.

## Checks and release packaging

```sh
zsh scripts/test.command
zsh scripts/release.command
```

The release script builds arm64 and x86_64 binaries, combines them into a universal app, and creates a DMG, ZIP, and SHA-256 checksums under `dist/`. The DMG contains an Applications link for drag-and-drop installation. Build scripts share one app builder and bundle the same localization resources.

Release packaging requires a persistent certificate and refuses ad-hoc signing. The preview uses a self-signed certificate; a valid Developer ID certificate, notarization credentials, and a successful Apple notarization result are still required before claiming a notarized release. A self-signed certificate does not provide Gatekeeper approval.

After building two different versions with the same self-signed certificate, verify their signatures and mutual identity requirements:

```sh
python3 Tests/Signing/verify_continuity.py /path/to/First.app /path/to/Updated.app
```

This check rejects ad-hoc identities and identical copies of one build. To verify macOS permission continuity, approve the first build, quit it, replace it at the same installation path with the second build, and relaunch without touching System Settings. Confirm permission status and actual blackout behavior. Two different certificate-signed builds retained input-control permission on the development Mac running macOS 27; this does not establish behavior on all supported macOS versions.

See [distribution and repository maintenance](distribution.md) for the release checks, Homebrew status, and official references.

Input routing unit tests check consumption, restricted forwarding, blocked shortcuts, and safe input-source switching. Actual event delivery also needs interactive testing on a Mac with Blackout's input-control permission enabled; tests do not grant permissions.

The unlock panel uses native Liquid Glass on macOS 26 and later and an opaque dark card on earlier versions. Its backing and full-screen cover remain black and opaque. UI checks verify that the surface leaves password-field and button hit testing intact; native material appearance and system accessibility preferences also need visual checks. CI and release packaging use a macOS 26 runner for the required SDK.

Emergency-exit tests use isolated child processes and a simulated key-state reader to verify normal dismissal, an unresponsive main thread, cancellation, and stale-session rejection. They never capture desktop input. Physical Escape detection, including while a secure password field is focused, still requires testing on a real Mac. Installation tests use temporary bundles and injected failures; they never replace the installed app.

## Website and translations

```sh
python3 docs/site/build.py
python3 docs/site/validate.py
```

App strings are in `Resources/Localization/<language>.lproj/Localizable.strings`; language resolution is in `Sources/Core/Localization`. Website content and its generator are separate in `docs/site`. The website's deployment workflow uploads only the generated site, not the source tree or app binaries.

## Recovery and removal

If the system permission switch is on but `AXIsProcessTrusted()` remains false after replacing the app, quit Blackout, remove its old entry from the input-control permission list, add the installed app again, enable it, and relaunch. This can happen when moving from an ad-hoc build to the fixed certificate. Ad-hoc signatures identify a particular build; macOS can retain an entry whose code requirement no longer matches. Do not remove the permission check or weaken code-signing requirements to work around this. Persistent certificate signing preserves the code identity; Developer ID signing and notarization are separate distribution work.

To recover without a terminal, hold **Escape for 3 seconds** to leave blackout, reopen the app if necessary, and choose **Settings → Forgot Password…**. Authenticate with macOS to reset only the app password. Cancelling authentication preserves it. Emergency exit itself bypasses normal password dismissal but does not change the saved password or other preferences.

If the app cannot be opened, the manual recovery fallback from your own account is:

```sh
pkill -x Blackout
defaults delete local.blackout.overlay unlockPassword.v1
open ~/Applications/Blackout.app
```

For the downloaded DMG installation, open `/Applications/Blackout.app` instead. This clears only password protection. Language and login preferences are separate.

Turn off launch at login in Blackout Settings before removing the app. Delete the DMG-installed app in Finder, or run `zsh scripts/uninstall.command` to remove the local `~/Applications` build.
