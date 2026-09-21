# Using BlackoutMac

[Quick Start](../../README.md#quick-start) · [한국어](ko.md) · [Downloads](https://github.com/baba9811/blackout-mac/releases)

## Installation

1. Download the universal DMG from **Releases**. Releases are **previews**, with interactive validation still in progress. It targets Apple Silicon and Intel Macs running macOS 13 or later.
2. Open the DMG and drag **Blackout.app** into **Applications**.
3. Open Blackout. Choose **Blackout menu bar icon → Settings… → Input Blocking → Open Input Permission Settings…**, then enable Blackout in the system panel that opens.

The app's button opens the appropriate input-control permission panel for your macOS version. This permission list is separate from the general Accessibility settings for assistive features. See [Apple's guidance on granting app control](https://support.apple.com/guide/mac-help/allow-accessibility-apps-to-access-your-mac-mh43185/mac).

Preview releases are **not Developer ID signed or Apple-notarized**. Release notes describe each build's signing method. A self-signed certificate can keep the app's identity stable between builds; it does not provide Apple approval. If macOS blocks opening, review the download's source and follow [Apple's instructions for opening an app from an unknown developer](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac). If you choose to allow it, use **System Settings → Privacy & Security** and the app-specific **Open Anyway** option. Keep Gatekeeper enabled.

## Everyday use and settings

- **Black out:** Control + Option + B, or **Blackout → Blackout Now** in the menu bar.
- **Restore:** move the mouse, scroll, click, or press a key. With password protection enabled, enter your password instead.
- **Settings:** select **Blackout → Settings…** in the menu bar or reopen the app.
- **Status icon:** the moon is always the app's symbol; a small lock badge appears when app password protection is on. Saving password settings updates it immediately. The menu bar stays hidden during blackout.
- **Dock:** the moon app icon appears while Settings is open. Closing Settings leaves Blackout running in the menu bar.
- **Language:** defaults to your OS preference. Choose a language in Settings to override it immediately.
- **Launch at login:** enable it in Settings. This starts the menu bar app after login; it does not automatically black out the screen.

## Password and recovery

- **Password:** optional and off by default. Use **Require a password to restore the screen** in Settings. Turning it on opens a new-password dialog; turning it off asks for the current password. The switch changes only after saving succeeds; Cancel leaves it unchanged. When enabled, **Change Password…** opens a separate change dialog and **Forgot Password…** offers recovery.
- **Cancel unlocking:** Cancel returns to the black screen. Keyboard and mouse input cannot reopen the prompt for two seconds, then normal wake behavior resumes.
- **Switch input language:** in the unlock prompt, **Control + Space** cycles through your enabled keyboard input sources.
- **Emergency exit:** hold **Escape for 3 seconds** to end blackout, including when a password is enabled. If the app cannot respond, the recovery watchdog quits it; reopen Blackout afterward. This intentionally bypasses the app password and does not erase it.
- **Forgotten password:** after leaving blackout, choose **Settings… → Forgot Password…** and authenticate with macOS using Touch ID or your Mac login password. Only Blackout's saved password is reset; language and login preferences remain. Cancelling authentication changes nothing.

## Input blocking and security

Blackout requires macOS input-control permission to install an active keyboard/mouse event filter. While the filter is running, original input is consumed; allowed password-entry events are directed only to Blackout. Input blocking and app-switching restrictions are removed when blackout ends. If the filter cannot start, Blackout refuses to cover the screen. If it stops, Blackout uncovers the screen and reports the problem.

**This is an application overlay, not the macOS security lock.** The optional password only gates normal dismissal through Blackout. Automation already authorized through macOS accessibility permissions may still read or control other apps beneath the cover. Force quit, other privileged software, macOS security UI, and Secure Event Input are OS-controlled boundaries. Use **macOS Lock Screen (Control + Command + Q)** when you need to secure your session, as listed in [Apple's keyboard shortcuts](https://support.apple.com/en-us/102650). Do not treat a black overlay as proof that the computer is securely locked.

Settings stay on this Mac. Passwords are stored as salted PBKDF2-HMAC-SHA256 verifiers (600,000 iterations), not plaintext. The app has no network service or analytics.

**Check for Updates…** in Settings contacts GitHub only when you click it. It reads public release information; passwords and preferences are not sent.

## Updates

1. Open Settings to see the installed version and choose **Check for Updates…**. Open the offered release and download its DMG, or visit [Releases](https://github.com/baba9811/blackout-mac/releases).
2. Choose **Quit Blackout** from the menu bar, after restoring the screen if needed.
3. Replace the existing **Blackout.app in the same folder** with the new copy, then open it. Do not keep a second copy in another folder.

Your password and language preferences are stored separately from the app and remain in place. Check launch-at-login status after replacement. A signing identity change can require one renewed approval of input-control permission. This is not a step required for every update. Updates currently use this manual replacement process.

If Blackout still asks for permission when its switch is already on, quit Blackout, remove its entry from the input-control permission list, then add the currently installed **Blackout.app** again and enable it. Reopen Blackout. An old permission entry can refer to the previous build even though the switch remains on.

For source builds, tests, local password recovery, and uninstalling, see the [developer guide](../development.md). Release signing and validation details are in the [distribution guide](../distribution.md).
