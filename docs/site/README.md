# BlackoutMac website

Static, crawlable user guides for the app's 32 languages. English is at the site root; every other language has its own directory. No JavaScript, third-party fonts, tracking scripts, package manager, or runtime service is required.

From the repository root:

```sh
python3 docs/site/build.py
python3 docs/site/validate.py
```

Generated files go to `docs/site/dist/` and stay untracked. To preview the project URL locally, expose that directory at `/blackout-mac/` in a local static server. The site uses root-relative project paths for assets and language links.

`translations.json` contains all visible documentation. `assets/site.css` provides the responsive layout and `assets/icon.svg` provides the decorative mark. `build.py` owns the repository URL, canonical URL, and download target; the version comes from the repository-root `VERSION` file shared with app packaging. Changes to `VERSION` trigger Pages deployment. Downloads use GitHub's releases page so prereleases remain discoverable and the site does not promise an unpublished asset. The current version is labeled as a preview in every language. Source-build instructions live in [`../development.md`](../development.md).

The Pages workflow builds and validates the site, uploads only `docs/site/dist`, and deploys with GitHub's official Pages actions. Set the repository's Pages source to **GitHub Actions** before the first deployment. A push touching the site or workflow on `main`, or a manual workflow run, publishes it.

Each page contains a localized title and description, canonical URL, reciprocal language alternatives, Open Graph metadata, and SoftwareApplication/FAQPage structured data matching visible content. The build also emits `sitemap.xml`, `robots.txt`, and `llms.txt`. GitHub project sites serve `robots.txt` below the project path; the origin-level robots policy belongs to the account domain. Structured data and `llms.txt` do not guarantee search indexing, rich results, or AI citations.

The validator checks language completeness, visible FAQ/schema parity, page metadata, internal files and fragments, sitemap URLs, and alternate-language links. It does not replace native-language review or browser accessibility testing.

References: [GitHub Pages workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages), [Apple's guidance for opening downloaded apps](https://support.apple.com/en-us/102445).
