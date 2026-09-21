# Security policy

## Supported versions

Security fixes target the latest published preview or stable release and the `main` branch. Older versions do not receive separate maintenance. Preview releases may still have incomplete interactive validation; consult their release notes.

## Report privately

Use [Report a vulnerability](https://github.com/baba9811/blackout-mac/security/advisories/new) to send a private GitHub security report. Include the app version, macOS version, reproduction steps, and impact. Do not include actual passwords or unrelated personal information. Please allow investigation before publishing exploit details. This is a volunteer project without a guaranteed response time.

## Security boundaries

BlackoutMac is a screen overlay, not a replacement for the macOS security lock. Use **Control + Command + Q** for the OS lock. A person with access to your account can terminate the app or reset its local preferences.

Accessibility permission enables an active keyboard/mouse event filter. When available, the filter consumes original events and directs permitted password-entry events to Blackout. If it cannot start or becomes disabled, the app removes the overlay and reports the failure. This deliberately avoids leaving a black screen that appears to block input when the filter is unavailable. macOS security UI, Secure Event Input, force quit, and other privileged software remain outside this guarantee.

Optional passwords are stored locally as salted PBKDF2-HMAC-SHA256 verifiers. The app has no network service, account system, telemetry, or password recovery service. Local preference tampering and offline password guessing are outside the overlay's protection.

Current downloads use ad-hoc signatures and are not Apple-notarized. Check release notes and checksums before installing. Checksums detect file changes; they do not replace Developer ID signing or notarization.

한국어로도 비공개 취약점 신고를 접수합니다. 비밀번호나 민감한 재현 정보를 공개 이슈에 올리지 마세요.
