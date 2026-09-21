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
3. Open Blackout. Choose **Blackout menu bar icon → Settings… → Input Blocking → Open Input Permission Settings…**, then enable Blackout in the system panel that opens.

The permission panel is named **Device Control and Data Access** on macOS 27, and **Accessibility** on macOS 13–26. The app's button opens the appropriate panel directly. The separate Accessibility section for assistive features is not the permission list.

The v0.1.0 preview uses ad-hoc signing. Starting with v0.1.1, previews use a fixed self-signed certificate to keep the signing identity stable across builds. These previews are **not Developer ID signed or Apple-notarized**; the certificate does not provide Apple approval. macOS may require you to review and explicitly allow the app in **System Settings → Privacy & Security**. Do not disable Gatekeeper. A Developer ID signed and notarized release remains future distribution work.

## Use

- **Black out:** Control + Option + B, or **Blackout → Blackout Now** in the menu bar.
- **Restore:** move the mouse, scroll, click, or press a key. With password protection enabled, enter your password instead.
- **Settings:** select **Blackout → Settings…** in the menu bar or reopen the app.
- **Status icon:** the moon is always the app's symbol; a small lock badge appears when app password protection is on. Saving password settings updates it immediately. The menu bar stays hidden during blackout.
- **Dock:** the moon app icon appears while Settings is open. Closing Settings leaves Blackout running in the menu bar.
- **Language:** defaults to your OS preference. Choose a language in Settings to override it immediately.
- **Launch at login:** enable it in Settings. This starts the menu bar app after login; it does not automatically black out the screen.
- **Password:** optional and off by default. Use **Require a password to restore the screen** in Settings. Turning it on opens a new-password dialog; turning it off asks for the current password. The switch changes only after saving succeeds; Cancel leaves it unchanged. When enabled, **Change Password…** opens a separate change dialog and **Forgot Password…** offers recovery.
- **Cancel unlocking:** Cancel returns to the black screen. Keyboard and mouse input cannot reopen the prompt for two seconds, then normal wake behavior resumes.
- **Emergency exit:** hold **Escape for 3 seconds** to end blackout, including when a password is enabled. If the app cannot respond, the recovery watchdog quits it; reopen Blackout afterward. This intentionally bypasses the app password and does not erase it.
- **Forgotten password:** after leaving blackout, choose **Settings… → Forgot Password…** and authenticate with macOS using Touch ID or your Mac login password. Only Blackout's saved password is reset; language and login preferences remain. Cancelling authentication changes nothing.

## Input protection and limitations

Blackout requires macOS input-control permission to install an active keyboard/mouse event filter. While the filter is running, original input is consumed; allowed password-entry events are directed only to Blackout. Input blocking and app-switching restrictions are removed when blackout ends. If the filter cannot start, Blackout refuses to cover the screen. If it stops, Blackout uncovers the screen and reports the problem.

**This is an application overlay, not the macOS security lock.** The optional password only gates normal dismissal through Blackout. Automation already authorized through macOS accessibility permissions may still read or control other apps beneath the cover. Force quit, other privileged software, macOS security UI, and Secure Event Input are OS-controlled boundaries. Use **macOS Lock Screen (Control + Command + Q)** when you need to secure your session. Do not treat a black overlay as proof that the computer is securely locked.

Settings stay on this Mac. Passwords are stored as salted PBKDF2-HMAC-SHA256 verifiers (600,000 iterations), not plaintext. The app has no network service or analytics.

**Check for Updates…** in Settings contacts GitHub only when you click it. It reads public release information; passwords and preferences are not sent.

## Update an existing installation

1. Open Settings to see the installed version and choose **Check for Updates…**. Open the offered release and download its DMG, or visit [Releases](https://github.com/baba9811/blackout-mac/releases).
2. Choose **Quit Blackout** from the menu bar, after restoring the screen if needed.
3. Replace the existing **Blackout.app in the same folder** with the new copy, then open it. Do not keep a second copy in another folder.

Your password and language preferences are stored separately from the app and remain in place. Check launch-at-login status after replacement. A signing identity change, including upgrading from v0.1.0's ad-hoc signature to the fixed certificate, can require one renewed approval of input-control permission. This is not a step required for every update. Updates currently use this manual replacement process.

If Blackout still asks for permission when its switch is already on, quit Blackout, remove its entry from the input-control permission list, then add the currently installed **Blackout.app** again and enable it. Reopen Blackout. An old permission entry can refer to the previous build even though the switch remains on.

## Development and recovery

See the [developer guide](https://github.com/baba9811/blackout-mac/blob/main/docs/development.md) for source builds, tests, release packaging, password recovery, and uninstalling a local build. The [architecture guide](docs/architecture.md) explains the folder boundaries and dependency direction.

## Website

```sh
python3 docs/site/build.py
python3 docs/site/validate.py
```

The website is static HTML with translated guides, language-specific metadata, canonical/hreflang links, a sitemap, and structured data. The Pages workflow publishes only website output. These make the content accessible to crawlers; search or AI visibility is not guaranteed.

## Contributing and license

See [contributing](.github/CONTRIBUTING.md), the [code of conduct](.github/CODE_OF_CONDUCT.md), and the [security policy](.github/SECURITY.md). Reports and translation corrections are welcome in any language. This project is released under the [MIT license](LICENSE).
