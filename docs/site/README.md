# BlackoutMac website

Static, crawlable user guides for the app's 32 languages. English is at the site root; every other language has its own directory. No JavaScript, third-party fonts, tracking scripts, package manager, or runtime service is required.

From the repository root:

```sh
python3 docs/site/build.py
python3 docs/site/validate.py
```

Generated files go to `docs/site/dist/` and stay untracked. To preview the project URL locally, expose that directory at `/blackout-mac/` in a local static server. The site uses root-relative project paths for assets and language links.

`translations.json` contains all visible documentation. `assets/site.css` provides the responsive layout and `assets/icon.svg` provides the decorative mark. `build.py` owns the repository URL, canonical URL, and download target; the version comes from the repository-root `VERSION` file shared with app packaging. Changes to `VERSION` trigger Pages deployment. Downloads use GitHub's releases page so prereleases remain discoverable and the site does not promise an unpublished asset. The current version is labeled as a preview in every language. Source-build instructions live in [`../development.md`](../development.md).

The Pages workflow builds and validates the site, uploads only `docs/site/dist`, and deploys with GitHub's official Pages actions. Set the repository's Pages source to **GitHub Actions** before the first deployment. Site/version changes on `main`, a completed Release workflow, or a manual run trigger it. Deployment waits until a published release exists for `VERSION`, so a failed package build cannot advance the documented version. Only `main` may deploy to the `github-pages` environment.

Each page contains a localized title and description, canonical URL, reciprocal language alternatives, Open Graph metadata, and SoftwareApplication data matching visible content. The build also emits `sitemap.xml`, `robots.txt`, `llms.txt`, and a custom `404.html` that links to every language. The error page is marked `noindex` and uses absolute links so it works for missing nested paths. GitHub project sites serve `robots.txt` below the project path; the origin-level robots policy belongs to the account domain.

The validator checks language completeness, visible text and software metadata, version consistency, internal files and fragments, sitemap URLs, alternate-language links, and the 404 recovery links. It does not replace native-language review or browser accessibility testing.

Google retired FAQ rich results in May 2026, so the user-facing FAQ remains ordinary HTML. `llms.txt` is a convenience for systems that choose to use it, not a Google Search or AI ranking factor. Do not add invented reviews, ratings, or claims to structured data. Search indexing and AI citations are not guaranteed. Submit the project sitemap in Search Console if maintaining search coverage; automatic language redirects are intentionally avoided so every translated page stays directly accessible.

References: [GitHub Pages workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages), [custom 404 pages](https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-custom-404-page-for-your-github-pages-site), [Google's language-version guidance](https://developers.google.com/search/docs/specialty/international/localized-versions), [Google Search updates](https://developers.google.com/search/updates#june-2026), [Apple's guidance for opening downloaded apps](https://support.apple.com/en-us/102445).
