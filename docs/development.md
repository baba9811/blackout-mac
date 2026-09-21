# Development

Run commands from the repository root. Source builds require Apple Command Line Tools (`xcode-select --install`). Regular users should use the [DMG download](https://github.com/baba9811/blackout-mac/releases), which needs no compiler or terminal.

## Local build and install

```sh
zsh scripts/install.command
```

The installer builds a staged, ad-hoc-signed app before replacing `~/Applications/Blackout.app`. It preserves preferences, stops the old process, and launches the new app. System Accessibility approval can require renewal after an ad-hoc rebuild.

To build without installing, choose a new output path:

```sh
zsh scripts/build.command /tmp/Blackout.app
```

## Checks and release packaging

```sh
zsh scripts/test.command
zsh scripts/release.command
```

The release script builds arm64 and x86_64 binaries, combines them into a universal app, and creates a DMG, ZIP, and SHA-256 checksums under `dist/`. The DMG contains an Applications link for drag-and-drop installation. Build scripts share one app builder and bundle the same localization resources.

Current packaging performs ad-hoc signing only. A valid Developer ID certificate, notarization credentials, and a successful Apple notarization result are still required before claiming a notarized release. Never describe ad-hoc signing as Gatekeeper approval.

See [distribution and repository maintenance](distribution.md) for the release checks, Homebrew status, and official references.

Input routing unit tests check consumption, restricted forwarding, blocked shortcuts, and safe input-source switching. Actual event delivery also needs interactive testing on a Mac with Blackout's Accessibility permission enabled; tests do not grant permissions.

## Website and translations

```sh
python3 docs/site/build.py
python3 docs/site/validate.py
```

App strings are in `Resources/Localization/<language>.lproj/Localizable.strings`; language resolution is in `Sources/Core/Localization`. Website content and its generator are separate in `docs/site`. The website's deployment workflow uploads only the generated site, not the source tree or app binaries.

## Recovery and removal

If you forget the app password, run these commands from your own account:

```sh
pkill -x Blackout
defaults delete local.blackout.overlay unlockPassword.v1
open ~/Applications/Blackout.app
```

For the downloaded DMG installation, open `/Applications/Blackout.app` instead. This clears only password protection. Language and login preferences are separate.

Turn off launch at login in Blackout Settings before removing the app. Delete the DMG-installed app in Finder, or run `zsh scripts/uninstall.command` to remove the local `~/Applications` build.
