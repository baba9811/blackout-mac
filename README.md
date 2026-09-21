# BlackoutMac

**Black screens. Your choice of how to return.**

BlackoutMac covers every connected display and filters keyboard and mouse input with one shortcut: **Control + Option + B**. Restore with a key or mouse movement, or opt into a password before the cover can be dismissed.

[Website and multilingual guide](https://baba9811.github.io/blackout-mac/) · [Downloads](https://github.com/baba9811/blackout-mac/releases) · [한국어 안내](docs/ko/README.md)

## Why BlackoutMac

- **Choose how to return.** Quick restoration by default; optional password confirmation when you want deliberate dismissal. The menu bar icon shows whether app password protection is enabled.
- **Set it once.** Native launch at login, macOS language matching, and a selectable interface and user guide in 32 languages.
- **Small and local.** A native Swift/AppKit menu bar app with no account, backend, analytics, or third-party runtime dependencies. Source is available under MIT.

## Install

1. Download the universal DMG from **Releases**. The initial release is a **preview**, with interactive validation still in progress. It targets Apple Silicon and Intel Macs running macOS 13 or later.
2. Open the DMG and drag **Blackout.app** into **Applications**.
3. Open Blackout. From the **Blackout menu bar icon → Settings…**, open Accessibility settings and allow Blackout before using blackout mode.

Current builds are locally ad-hoc signed, **not Apple-notarized**. macOS may require you to review and explicitly allow the app in **System Settings → Privacy & Security**. Do not disable Gatekeeper. A Developer ID signed and notarized release remains future distribution work.

## Use

- **Black out:** Control + Option + B, or **Blackout → Blackout Now** in the menu bar.
- **Restore:** move the mouse, scroll, click, or press a key. With password protection enabled, enter your password instead.
- **Settings:** select **Blackout → Settings…** in the menu bar or reopen the app.
- **Status icon:** an open lock means app password protection is off; a closed lock means it is on. Saving password settings updates the icon immediately. The menu bar stays hidden during blackout.
- **Language:** defaults to your OS preference. Choose a language in Settings to override it immediately.
- **Launch at login:** enable it in Settings. This starts the menu bar app after login; it does not automatically black out the screen.
- **Password:** optional and disabled by default. Changing or removing a saved password requires the current password.

## Input protection and limitations

Blackout requires Accessibility permission to install an active keyboard/mouse event filter. While the filter is running, original input is consumed; allowed password-entry events are directed only to Blackout. Input blocking and app-switching restrictions are removed when blackout ends. If the filter cannot start, Blackout refuses to cover the screen. If it stops, Blackout uncovers the screen and reports the problem.

**This is an application overlay, not the macOS security lock.** Force quit, other privileged software, macOS security UI, and Secure Event Input are OS-controlled boundaries. Use **Control + Command + Q** when you need to protect access to your Mac. Do not treat a black overlay as proof that the computer is securely locked.

Settings stay on this Mac. Passwords are stored as salted PBKDF2-HMAC-SHA256 verifiers (600,000 iterations), not plaintext. The app has no network service or analytics.

## Development and recovery

See the [developer guide](docs/development.md) for source builds, tests, release packaging, password recovery, and uninstalling a local build. The [architecture guide](docs/architecture.md) explains the folder boundaries and dependency direction.

## Website

```sh
python3 docs/site/build.py
python3 docs/site/validate.py
```

The website is static HTML with translated guides, language-specific metadata, canonical/hreflang links, a sitemap, and structured data. The Pages workflow publishes only website output. These make the content accessible to crawlers; search or AI visibility is not guaranteed.

## Contributing and license

See [contributing](.github/CONTRIBUTING.md), the [code of conduct](.github/CODE_OF_CONDUCT.md), and the [security policy](.github/SECURITY.md). Reports and translation corrections are welcome in any language. This project is released under the [MIT license](LICENSE).
