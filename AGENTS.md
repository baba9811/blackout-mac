# Repository working principles

## Understand the change

- Read the relevant implementation, callers, tests, and documentation before editing; trace the affected behavior end to end.
- Fix the root cause in the narrowest shared location. Reuse existing code, standard libraries, and native macOS capabilities before adding dependencies or abstractions.
- Keep changes focused on the requested outcome and preserve unrelated work. Avoid speculative features, broad refactors, and one-off frameworks.
- Use the architecture, development, and distribution guides for current details; keep this file about durable principles rather than tree inventories, versions, or copied commands.

## Responsibilities and dependencies

- Keep dependencies one-way: app orchestration composes features and platform services; those use core logic, never the reverse.
- Core logic owns domain rules and stored data without UI or application lifecycle dependencies.
- Platform code owns operating-system and external-service integration; return results or callbacks rather than reaching into app or feature state.
- Features own presentation and user interactions. App orchestration owns cross-feature lifecycle and session state.
- Group related work within its existing domain, with nested responsibilities where useful. Keep resources, documentation, and packaging separate from runtime logic; do not flatten unrelated concerns into shared utilities.

## Preserve the user's Mac

- Preserve settings, password verifiers, language choices, login preferences, and app identity across updates; make necessary migrations explicit and recoverable.
- Respect macOS permission checks and signing identity. Never bypass denied or stale permission checks to make an installation appear to work.
- Keep input-filter failure handling safe: do not leave a misleading cover when interception is unavailable, and restore input and presentation state on exit.
- Treat Blackout as an overlay. Its password gates normal dismissal through the app; it does not secure the macOS session or prevent authorized accessibility automation from reading or controlling other apps.
- Use macOS Lock Screen for session security. Do not strengthen security claims beyond demonstrated behavior.

## Verification and documentation

- Run the smallest meaningful existing checks for the affected behavior. Add focused regression coverage for nontrivial logic; avoid tests that merely repeat the implementation.
- State exactly what was checked and what remains unverified. Compilation, unit tests, and synthetic events do not prove physical input interception, permission behavior, display changes, login startup, or session security.
- Verify those platform behaviors on an actual Mac before claiming them; coordinate interactive checks that affect the user's desktop or session.
- Keep user-visible behavior, localized strings, and relevant guides consistent. Preserve translation keys and placeholders, and check long text and right-to-left layouts when affected.
- Verify OS-specific labels, permission-panel names, shortcuts, and version-dependent claims against current authoritative evidence; do not guess or copy stale terminology.

## Releases and repository hygiene

- Maintain a single source of truth for release versions; packaging and documentation must derive their versions from it and agree with published artifacts.
- Published version tags and release assets are immutable. Ship a new version for changed artifacts instead of silently replacing an existing release.
- Distinguish local signing, Developer ID signing, notarization, and actual installation validation; claim only the steps completed.
- Never commit generated builds, archives, generated site output, secrets, credentials, real passwords, or machine-specific personal paths.
- Keep Superpowers design, specification, plan, review-package, and progress notes local, ignored, and untracked under `docs/superpowers/` unless the user explicitly requests versioning. If asked to stop tracking existing notes, remove them from the Git index while preserving the local files.
