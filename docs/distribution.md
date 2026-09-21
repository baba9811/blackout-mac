# Distribution and repository maintenance

## Current release status

The initial download is a preview with an ad-hoc signature. It is not Apple-notarized. Builds target macOS 13 or later on arm64 and x86_64; cross-compilation does not establish runtime compatibility on every supported OS or Intel hardware.

Before promoting a preview to stable, test the actual app installed from the release DMG:

- Input-control permission denied, granted, stale after replacement, and revoked while active; failed input filtering must uncover the screen and report the problem.
- Keyboard, mouse, scrolling, media keys, and switching shortcuts with an unrelated app focused before blackout; verify that app receives no input while protected blackout remains active.
- Password disabled, correct/wrong password, cancel, copy/paste, Korean input switching, and Arabic/Hebrew layout.
- Multiple displays, full-screen Spaces, connecting/disconnecting a display, sleep/wake, and macOS lock/unlock.
- Launch at login enabled and disabled, including an actual logout/login or restart.
- At least one Intel Mac and the oldest supported macOS version before claiming those combinations have been tested.

Unit tests verify password storage, event-routing decisions, and localization integrity. They do not verify system permission prompts, actual event delivery, hardware changes, or a reboot.

## Build and publish

The root [`VERSION`](../VERSION) file is the single source for the public `major.minor.patch` version. The app bundle, archive filenames, website version labels, structured data, and `llms.txt` all read it. CI checks the bundle and generated pages against it. README download links point to Releases, so versioned links do not need manual replacement.

The normal release flow is to change `VERSION` in a pull request and merge it to `main`. The Release workflow then validates and packages that commit, creates its matching `v<version>` tag and GitHub prerelease, and uploads the DMG, ZIP, and checksums. Pages updates all 32 guides after that release succeeds; it checks that the documented version has a published release before deployment. This prevents documentation from advertising a version whose build failed. Ordinary main pushes without a version change run CI and any relevant site deployment, without creating another release.

Alternatively, push a `v<version>` tag for a commit already on `main`, or manually run Release on `main`. A tag that disagrees with `VERSION`, a commit outside `main`, or an existing version tag pointing at a different commit stops the release. Rerunning an existing release leaves its assets untouched. Current automated releases remain prereleases until signing and interactive validation are ready; the publish job alone receives repository write permission.

1. Run the checks in the [developer guide](development.md) and the interactive checks above. Record any missing coverage in the release notes.
2. Run `zsh scripts/release.command`. Check the DMG, app bundle, both architectures, and `SHA256SUMS`.
3. Merge the version change or push the matching tag to trigger the workflow above. Check its result and release assets. Do not silently replace published assets; publish a new version for changes.
4. Keep download links pointed at the releases list while only prereleases are available.

For normal Gatekeeper distribution, obtain a Developer ID Application certificate, sign with Hardened Runtime and a secure timestamp, submit with `xcrun notarytool`, and staple the accepted ticket. Verify the final downloaded distribution with Gatekeeper. Credentials belong in protected secrets or the local keychain, never in the repository. This repository does not currently automate notarization.

Keep the bundle identifier and signing identity consistent across updates. Ad-hoc signatures tie permission grants to a particular build's code hash: users may see an enabled permission switch while macOS rejects the replacement app. The recovery is to quit, remove the old permission entry, add and approve the installed app, and relaunch. A restart alone does not repair a mismatched code requirement. Do not replace the signed identity check with a permissive requirement.

## GitHub settings

The public repository uses a concise description, the Pages URL, and relevant Topics. Community files live under `.github/`; the MIT license is at the root and is included in distributions. Private vulnerability reporting is enabled. CI uses read-only permissions, and only the Pages deployment job receives Pages/OIDC write permissions. Official Actions are pinned to full commit SHAs.

`main` requires a pull request, an up-to-date branch, the GitHub Actions `validate` check, resolved review conversations, and linear history. These rules include administrators. Force pushes and branch deletion are disabled. No external approval is required for the solo maintainer's own PRs. Outside contributors use forks; granting someone write access also permits them to merge compliant PRs. Version tags matching `v*` cannot be updated or deleted after creation.

The static website provides localized URLs, reciprocal `hreflang`, canonical links, readable FAQs, software metadata, a sitemap, and a custom 404 page. `llms.txt` is provided for systems that use it; it is not a Google ranking factor. The site has no analytics or third-party JavaScript. See the [site maintenance guide](site/README.md) for current primary references and discovery limits.

## Homebrew

A personal tap can distribute a Cask after versioned downloads and checksums are available. The official `homebrew/cask` repository has separate acceptance, notability, and Gatekeeper requirements. An ad-hoc build does not satisfy notarized distribution; do not advertise `brew install` until a tested Cask exists.

## Primary references

- [Apple: packaging and testing macOS software](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)
- [Apple: notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Apple: code signing requirements](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html)
- [GitHub: secure use of Actions](https://docs.github.com/en/actions/reference/security/secure-use)
- [GitHub: custom Pages workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
- [GitHub: community health files](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file)
- [GitHub: repository Topics](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/classifying-your-repository-with-topics)
- [Homebrew: acceptable Casks](https://docs.brew.sh/Acceptable-Casks) and [personal taps](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
