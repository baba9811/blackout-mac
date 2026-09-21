# Distribution and repository maintenance

## Current release status

The initial download is a preview with an ad-hoc signature. It is not Apple-notarized. Builds target macOS 13 or later on arm64 and x86_64; cross-compilation does not establish runtime compatibility on every supported OS or Intel hardware.

Before promoting a preview to stable, test the actual app installed from the release DMG:

- Accessibility denied, granted, and revoked while active; failed input filtering must uncover the screen and report the problem.
- Keyboard, mouse, scrolling, media keys, and switching shortcuts with an unrelated app focused before blackout; verify that app receives no input while protected blackout remains active.
- Password disabled, correct/wrong password, cancel, copy/paste, Korean input switching, and Arabic/Hebrew layout.
- Multiple displays, full-screen Spaces, connecting/disconnecting a display, sleep/wake, and macOS lock/unlock.
- Launch at login enabled and disabled, including an actual logout/login or restart.
- At least one Intel Mac and the oldest supported macOS version before claiming those combinations have been tested.

Unit tests verify password storage, event-routing decisions, and localization integrity. They do not verify system permission prompts, actual event delivery, hardware changes, or a reboot.

## Build and publish

The root [`VERSION`](../VERSION) file is the single source for the public `major.minor.patch` version. Update it when preparing a release. The app bundle, archive filenames, website version labels, structured data, and `llms.txt` all read that file. Changing it on `main` automatically rebuilds and deploys all language pages. CI checks the bundle and generated pages against it. README downloads link to Releases, so no versioned download URLs need manual replacement. Keep release tags in the form `v` plus the value in `VERSION` and describe behavior changes in release notes.

1. Run the checks in the [developer guide](development.md) and the interactive checks above. Record any missing coverage in the release notes.
2. Run `zsh scripts/release.command`. Check the DMG, app bundle, both architectures, and `SHA256SUMS`.
3. Tag the tested source commit and attach the DMG, ZIP, and checksums to its GitHub release. Use a prerelease while validation is incomplete. Do not silently replace published assets; publish a new version for changes.
4. Keep download links pointed at the releases list while only prereleases are available.

For normal Gatekeeper distribution, obtain a Developer ID Application certificate, sign with Hardened Runtime and a secure timestamp, submit with `xcrun notarytool`, and staple the accepted ticket. Verify the final downloaded distribution with Gatekeeper. Credentials belong in protected secrets or the local keychain, never in the repository. This repository does not currently automate notarization.

## GitHub settings

The public repository uses a concise description, the Pages URL, and relevant Topics. Community files live under `.github/`; the MIT license is at the root and is included in distributions. Private vulnerability reporting is enabled. CI uses read-only permissions, and only the Pages deployment job receives Pages/OIDC write permissions. Official Actions are pinned to full commit SHAs.

The static website provides localized URLs, reciprocal `hreflang`, canonical links, visible FAQs with matching structured data, a sitemap, and `llms.txt`. These aid discovery; they do not promise search rankings or AI citations. The site has no analytics or third-party JavaScript.

## Homebrew

A personal tap can distribute a Cask after versioned downloads and checksums are available. The official `homebrew/cask` repository has separate acceptance, notability, and Gatekeeper requirements. An ad-hoc build does not satisfy notarized distribution; do not advertise `brew install` until a tested Cask exists.

## Primary references

- [Apple: packaging and testing macOS software](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)
- [Apple: notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [GitHub: secure use of Actions](https://docs.github.com/en/actions/reference/security/secure-use)
- [GitHub: custom Pages workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
- [GitHub: community health files](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file)
- [GitHub: repository Topics](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/classifying-your-repository-with-topics)
- [Homebrew: acceptable Casks](https://docs.brew.sh/Acceptable-Casks) and [personal taps](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
