# Contributing

Bug reports, focused fixes, accessibility feedback, and translation corrections are welcome. You may use your preferred language in issues and pull requests.

For installation and use, start with the [multilingual guide](https://baba9811.github.io/blackout-mac/). For development, follow [build and test instructions](../docs/development.md) and the [dependency boundaries](../docs/architecture.md).

Fork the repository, create a branch in your fork, and open a pull request against `main`. People with repository write access may use a branch in this repository. Only maintainers with write access can merge; public access does not grant push or merge permission. `main` requires a pull request and the `validate` check, including for administrators.

Before submitting a change:

1. Explain the problem and expected behavior. Discuss substantial new behavior in an issue first.
2. Keep app features, platform integration, core data, and website content in their existing domains. Core code must not depend on UI or app lifecycle code.
3. Run `zsh scripts/test.command`. For app changes, build with `zsh scripts/build.command /tmp/Blackout.app --universal`, using an unused output path.
4. For website changes, run `python3 docs/site/build.py` and `python3 docs/site/validate.py`.
5. State what you actually tested. Input filtering, login startup, and display/session changes require interactive macOS checks; a successful build alone does not verify them.

App translations live in `Resources/Localization/<language>.lproj/Localizable.strings`; website translations live in `docs/site/translations.json`. Keep keys and `%@` placeholders intact. Test long strings and right-to-left layouts. Initial translations need native-speaker review; corrections are encouraged.

Do not commit app binaries, generated website output, personal paths, credentials, or local workflow notes under `docs/superpowers/`. Never include a real password in a report. Report potential vulnerabilities through the [security policy](SECURITY.md), not a public issue.

Contributions are provided under the project's [MIT license](../LICENSE). Participation follows the [code of conduct](CODE_OF_CONDUCT.md).
