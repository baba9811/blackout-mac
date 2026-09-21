#!/usr/bin/env python3
"""Build the crawlable, dependency-free BlackoutMac website."""

import html
import json
import re
import shutil
from pathlib import Path
from urllib.parse import urlsplit
from xml.etree.ElementTree import Element, SubElement, ElementTree, register_namespace

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "dist"
BASE = "https://baba9811.github.io/blackout-mac/"
REPO = "https://github.com/baba9811/blackout-mac"
DOWNLOAD = REPO + "/releases"
VERSION = (ROOT.parents[1] / "VERSION").read_text().strip()
if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", VERSION):
    raise ValueError("VERSION must contain a major.minor.patch number")
SECTION_IDS = ("install", "accessibility", "shortcut", "password", "login", "language", "privacy", "recovery")
LOCALES = (
    "en", "ko", "ja", "zh-Hans", "zh-Hant", "es", "fr", "de", "it", "pt-BR", "pt-PT",
    "ru", "uk", "pl", "nl", "sv", "da", "nb", "fi", "cs", "sk", "hu", "ro", "tr",
    "ar", "he", "hi", "th", "vi", "id", "ms", "el",
)


def url(code):
    return BASE if code == "en" else BASE + code + "/"


def page(code, data):
    t = data[code]
    esc = html.escape
    download, guide, language, skip, faq_label, issues, apple = t["labels"]
    asset = urlsplit(BASE).path + "assets/"
    title = "BlackoutMac — " + t["headline"]
    alternate = "\n".join(
        f'<link rel="alternate" hreflang="{lang}" href="{url(lang)}">' for lang in LOCALES
    ) + f'\n<link rel="alternate" hreflang="x-default" href="{BASE}">'
    language_links = "".join(
        f'<a lang="{lang}" hreflang="{lang}" href="{urlsplit(url(lang)).path}"'
        + (' aria-current="page"' if lang == code else "")
        + f'>{esc(data[lang]["name"])}</a>' for lang in LOCALES
    )
    sections = []
    for number, (section_id, (heading, body)) in enumerate(zip(SECTION_IDS, t["sections"]), 1):
        reference = (
            f'<a class="reference" href="https://support.apple.com/en-us/102445">{esc(apple)} ↗</a>'
            if section_id == "install" else ""
        )
        sections.append(
            f'<section class="doc-card" id="{section_id}"><span class="doc-number" aria-hidden="true">{number:02}</span>'
            f'<div><h3>{esc(heading)}</h3><p>{esc(body)}</p>{reference}</div></section>'
        )
    questions = "".join(
        f'<details><summary>{esc(question)}</summary><p>{esc(answer)}</p></details>'
        for question, answer in t["faqs"]
    )
    schema = {
        "@context": "https://schema.org",
        "@graph": [
            {
                "@type": "SoftwareApplication", "@id": BASE + "#application",
                "name": "BlackoutMac", "applicationCategory": "UtilitiesApplication",
                "operatingSystem": "macOS 13 or later", "softwareVersion": VERSION,
                "url": url(code), "downloadUrl": DOWNLOAD,
                "description": t["description"], "inLanguage": code,
                "license": REPO + "/blob/main/LICENSE",
                "softwareHelp": {"@type": "WebPage", "url": url(code) + "#guide"},
            },
        ],
    }
    schema_json = json.dumps(schema, ensure_ascii=False).replace("<", "\\u003c")
    direction = "rtl" if code in ("ar", "he") else "ltr"
    og_locale = {
        "en": "en_US", "ko": "ko_KR", "ja": "ja_JP", "zh-Hans": "zh_CN", "zh-Hant": "zh_TW",
        "es": "es_ES", "fr": "fr_FR", "de": "de_DE", "it": "it_IT", "pt-BR": "pt_BR", "pt-PT": "pt_PT",
        "ru": "ru_RU", "uk": "uk_UA", "pl": "pl_PL", "nl": "nl_NL", "sv": "sv_SE", "da": "da_DK",
        "nb": "nb_NO", "fi": "fi_FI", "cs": "cs_CZ", "sk": "sk_SK", "hu": "hu_HU", "ro": "ro_RO",
        "tr": "tr_TR", "ar": "ar_SA", "he": "he_IL", "hi": "hi_IN", "th": "th_TH", "vi": "vi_VN",
        "id": "id_ID", "ms": "ms_MY", "el": "el_GR",
    }[code]
    return f'''<!doctype html>
<html lang="{code}" dir="{direction}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title)}</title>
<meta name="description" content="{esc(t["description"])}">
<meta name="theme-color" content="#f3f0e7">
<meta name="robots" content="index,follow">
<link rel="canonical" href="{url(code)}">
{alternate}
<meta property="og:type" content="website">
<meta property="og:site_name" content="BlackoutMac">
<meta property="og:title" content="{esc(title)}">
<meta property="og:description" content="{esc(t["description"])}">
<meta property="og:url" content="{url(code)}">
<meta property="og:locale" content="{og_locale}">
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="{esc(title)}">
<meta name="twitter:description" content="{esc(t["description"])}">
<link rel="icon" type="image/svg+xml" href="{asset}icon.svg">
<link rel="stylesheet" href="{asset}site.css">
<script type="application/ld+json">{schema_json}</script>
</head>
<body>
<a class="skip" href="#main">{esc(skip)}</a>
<div class="wrap">
<header>
  <a class="brand" href="{urlsplit(url(code)).path}"><img src="{asset}icon.svg" alt="" width="36" height="36">BlackoutMac</a>
  <nav class="nav" aria-label="BlackoutMac">
    <a class="nav-guide" href="#guide">{esc(guide)}</a>
    <a href="{REPO}">GitHub ↗</a>
    <details class="languages"><summary><span aria-hidden="true">◎</span> {esc(t["name"])}</summary><nav class="language-menu" aria-label="{esc(language)}">{language_links}</nav></details>
  </nav>
</header>
<main id="main">
  <section class="hero" aria-labelledby="headline">
    <div>
      <div class="eyebrow">BlackoutMac / macOS</div>
      <h1 id="headline">{esc(t["headline"])}</h1>
      <p class="intro">{esc(t["description"])}</p>
      <div class="actions"><a class="button primary" href="{DOWNLOAD}">{esc(download)} <span aria-hidden="true">↓</span></a><a class="button secondary" href="#guide">{esc(guide)} <span aria-hidden="true">↗</span></a></div>
      <p class="release-note"><a href="#install">{esc(t["notice"])}</a></p>
    </div>
    <div class="art" aria-hidden="true">
      <div class="monitor"><div class="monitor-bar">☾</div><div class="moon"></div></div>
      <div class="monitor-foot"></div><div class="monitor-base"></div>
      <div class="shortcut"><kbd>⌃ Control</kbd><span class="plus">+</span><kbd>⌥ Option</kbd><span class="plus">+</span><kbd>B</kbd></div>
    </div>
  </section>
  <div class="specs"><span>macOS 13+</span><span>Apple Silicon + Intel</span><span>{esc(language)} · 32</span><span>v{VERSION} · {esc(t["status"])}</span></div>
  <section class="guide" id="guide" aria-labelledby="guide-title">
    <div class="section-heading"><h2 id="guide-title">{esc(guide)}</h2><span>01 — 08</span></div>
    <div class="guide-grid">{"".join(sections)}</div>
  </section>
  <section class="faq" id="faq" aria-labelledby="faq-title"><h2 id="faq-title">{esc(faq_label)}</h2>{questions}</section>
</main>
<footer><span class="footer-brand">● BlackoutMac</span><div class="footer-links"><a href="{REPO}">GitHub ↗</a><a href="{REPO}/blob/main/LICENSE">MIT</a><a href="{REPO}/issues">{esc(issues)} ↗</a><a href="#privacy">{esc(t["sections"][6][0])}</a></div></footer>
</div>
</body>
</html>
'''


def main():
    data = json.loads((ROOT / "translations.json").read_text())
    if set(data) != set(LOCALES):
        raise ValueError(f"Expected exactly {len(LOCALES)} languages; missing {set(LOCALES) - set(data)}")
    for code, t in data.items():
        if len(t["sections"]) != len(SECTION_IDS) or len(t["labels"]) != 7 or len(t["faqs"]) != 2:
            raise ValueError(f"Incomplete translation: {code}")
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir()
    shutil.copytree(ROOT / "assets", OUT / "assets")
    for code in LOCALES:
        destination = OUT if code == "en" else OUT / code
        destination.mkdir(exist_ok=True)
        (destination / "index.html").write_text(page(code, data))
    languages = "".join(
        f'<li><a lang="{lang}" href="{url(lang)}">{html.escape(data[lang]["name"])}</a></li>'
        for lang in LOCALES
    )
    (OUT / "404.html").write_text(f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex"><title>BlackoutMac — 404</title>
<link rel="stylesheet" href="{BASE}assets/site.css"></head>
<body><main class="wrap"><header><a class="brand" href="{BASE}">BlackoutMac</a></header>
<h1>404</h1><p>Page not found. Choose your language to return to the guide.</p>
<nav aria-label="User guides by language"><ul class="recovery-languages">{languages}</ul></nav>
</main></body></html>''')
    (OUT / ".nojekyll").touch()
    (OUT / "robots.txt").write_text(f"User-agent: *\nAllow: /\n\nSitemap: {BASE}sitemap.xml\n")
    ns = "http://www.sitemaps.org/schemas/sitemap/0.9"
    xhtml = "http://www.w3.org/1999/xhtml"
    register_namespace("", ns)
    register_namespace("xhtml", xhtml)
    sitemap = Element(f"{{{ns}}}urlset")
    for code in LOCALES:
        entry = SubElement(sitemap, f"{{{ns}}}url")
        SubElement(entry, f"{{{ns}}}loc").text = url(code)
        for lang in (*LOCALES, "x-default"):
            SubElement(entry, f"{{{xhtml}}}link", rel="alternate", hreflang=lang, href=url("en" if lang == "x-default" else lang))
    ElementTree(sitemap).write(OUT / "sitemap.xml", encoding="utf-8", xml_declaration=True)
    links = "\n".join(f'- [{data[lang]["name"]}]({url(lang)}): Installation, permissions, usage, privacy, recovery, and FAQ.' for lang in LOCALES)
    (OUT / "llms.txt").write_text(f'''# BlackoutMac

> A macOS menu bar app that covers detected displays in black. Password protection is optional and disabled by default.

## App facts
- macOS 13 or later; universal Apple Silicon and Intel build; version {VERSION} preview. Real-device input validation is ongoing.
- Control + Option + B or the Blackout menu activates the cover.
- Without a password, keyboard or mouse input restores the screens.
- macOS input-control permission is required. Use Blackout Settings to open the permission panel: Device Control and Data Access on macOS 27, or Accessibility on macOS 13–26. The app refuses to cover screens without working input interception and removes covers if interception fails.
- Optional password changes and removal require the current password. A salted password verifier is stored locally.
- Native launch at login; 32 languages; follows the system language unless overridden.
- No backend or telemetry. GitHub hosts this website and downloads.
- This is not a macOS security lock. Force Quit and macOS security screens are outside its guarantee. Use macOS Lock Screen to secure a session.
- The distributed app is ad-hoc signed, not Developer ID signed, and not notarized by Apple. Review installation instructions before opening.

## Primary links
- [Releases]({DOWNLOAD}): Download the universal DMG preview and read release notes.
- [Repository]({REPO}): Source and issue tracking.
- [Development guide]({REPO}/blob/main/docs/development.md): Building from source.

## Localized user guides
{links}
''')
    print(f"Built {len(LOCALES)} localized pages in {OUT}")


if __name__ == "__main__":
    main()
