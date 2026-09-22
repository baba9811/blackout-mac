# BlackoutMac

Keep background AI work running while your screens stay covered. Add a password if you want. [Compatibility →](docs/usage/README.md#ai-work)

I built BlackoutMac after the password field disappeared on my macOS 27.0 Lock Screen.

**[Download DMG](https://github.com/baba9811/blackout-mac/releases)** · [Website](https://baba9811.github.io/blackout-mac/) · [한국어](docs/ko/README.md)

macOS 13+ · Apple Silicon and Intel · 32 languages

> Previews are **not Developer ID signed or Apple-notarized**. If Apple cannot check for malware, choose **Done**, then **System Settings → Privacy & Security → Open Anyway** for Blackout. [First-launch help →](docs/usage/README.md#installation)

## Quick Start

1. Download a DMG from [Releases](https://github.com/baba9811/blackout-mac/releases), open it, and drag **Blackout.app** into **Applications**.
2. Open Blackout. From its menu bar icon, choose **Settings… → Input Blocking → Open Input Permission Settings…** and enable Blackout in the panel that opens.
3. Press **Control + Option + B**, or choose **Blackout Now** from the menu bar.
4. Move the mouse, scroll, click, or press a key to return. If you enabled a password, enter it when prompted.

**Emergency exit:** hold **Escape for 3 seconds**, even with a password enabled. [Recovery help →](docs/usage/README.md#password-and-recovery)

Blackout is a screen overlay; its password only gates normal dismissal. To secure your Mac session, use **macOS Lock Screen (Control + Command + Q)**. [Limits →](docs/usage/README.md#input-blocking-and-security)

## Preview

![Blackout's password prompt: a moon icon, password field, and Cancel and Unlock buttons on a black background.](docs/assets/unlock-preview.png)

## Documentation

- [Settings, password recovery, and input permissions](docs/usage/README.md)
- [Updating an existing installation](docs/usage/README.md#updates)
- [Multilingual user guide](https://baba9811.github.io/blackout-mac/)
- [Build, test, and uninstall](docs/development.md) · [Architecture](docs/architecture.md) · [Distribution](docs/distribution.md)

Reports and translation corrections are welcome in any language. See [contributing](.github/CONTRIBUTING.md), the [code of conduct](.github/CODE_OF_CONDUCT.md), and the [security policy](.github/SECURITY.md). [MIT license](LICENSE).
