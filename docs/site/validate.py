#!/usr/bin/env python3
"""Check generated language pages, metadata, schemas, and local link targets."""

import json
import re
from html.parser import HTMLParser
from urllib.parse import urljoin, urlsplit, unquote
from xml.etree import ElementTree

from build import BASE, DOWNLOAD, LOCALES, OUT, ROOT, SECTION_IDS, VERSION, url


class Page(HTMLParser):
    def __init__(self, source):
        super().__init__(convert_charrefs=True)
        self.tags = []
        self.ids = set()
        self.text = []
        self.schema = ""
        self.in_schema = False
        self.feed(source)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.tags.append((tag, attrs))
        if "id" in attrs:
            assert attrs["id"] not in self.ids, f"Duplicate id: {attrs['id']}"
            self.ids.add(attrs["id"])
        if tag == "script" and attrs.get("type") == "application/ld+json":
            self.in_schema = True

    def handle_endtag(self, tag):
        if tag == "script":
            self.in_schema = False

    def handle_data(self, value):
        if self.in_schema:
            self.schema += value
        else:
            self.text.append(value)


def main():
    data = json.loads((ROOT / "translations.json").read_text())
    assert set(data) == set(LOCALES)
    pages = {}
    for code in LOCALES:
        path = OUT / ("index.html" if code == "en" else f"{code}/index.html")
        pages[code] = Page(path.read_text())
    for code, page in pages.items():
        t = data[code]
        visible = " ".join(page.text)
        assert all(isinstance(value, str) and value.strip() for value in t["labels"])
        assert all(value.strip() for pair in t["sections"] + t["faqs"] for value in pair)
        assert {attrs.get("lang") for tag, attrs in page.tags if tag == "html"} == {code}
        assert sum(tag == "h1" for tag, _ in page.tags) == 1
        assert set(SECTION_IDS) <= page.ids
        assert {attrs["href"] for tag, attrs in page.tags if tag == "link" and attrs.get("rel") == "canonical"} == {url(code)}
        alternates = {attrs["hreflang"]: attrs["href"] for tag, attrs in page.tags if tag == "link" and attrs.get("rel") == "alternate"}
        assert alternates == {**{lang: url(lang) for lang in LOCALES}, "x-default": BASE}
        metas = {attrs.get("name", attrs.get("property")): attrs.get("content") for tag, attrs in page.tags if tag == "meta"}
        assert metas["description"] == metas["og:description"] == t["description"]
        assert metas["og:url"] == url(code)
        assert re.fullmatch(r"[a-z]{2}_[A-Z]{2}", metas["og:locale"])
        assert metas["og:title"] == "BlackoutMac — " + t["headline"]
        assert all(value in visible for pair in t["sections"] + t["faqs"] for value in pair)
        if code != "en":
            assert t["description"] != data["en"]["description"]
            assert all(pair[1] != english[1] for pair, english in zip(t["sections"], data["en"]["sections"]))
        schema = json.loads(page.schema)
        assert schema["@context"] == "https://schema.org"
        app = schema["@graph"][0]
        assert app["@type"] == "SoftwareApplication" and app["downloadUrl"] == DOWNLOAD
        assert app["inLanguage"] == code and app["description"] == t["description"]
        assert app["softwareVersion"] == VERSION and f"v{VERSION}" in visible
        assert "offers" not in app and "aggregateRating" not in app
        for tag, attrs in page.tags:
            for attr in ("href", "src"):
                if attr not in attrs:
                    continue
                destination = urlsplit(urljoin(url(code), attrs[attr]))
                if destination.netloc != urlsplit(BASE).netloc:
                    continue
                prefix = urlsplit(BASE).path
                assert destination.path.startswith(prefix), (code, attrs[attr])
                relative = unquote(destination.path[len(prefix):])
                target = OUT / relative
                if destination.path.endswith("/"):
                    target /= "index.html"
                assert target.is_file(), f"Broken link in {code}: {attrs[attr]}"
                if destination.fragment:
                    assert destination.fragment in Page(target.read_text()).ids, (code, attrs[attr])
    sitemap = ElementTree.parse(OUT / "sitemap.xml")
    ns = {"s": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    assert {node.text for node in sitemap.findall("s:url/s:loc", ns)} == {url(lang) for lang in LOCALES}
    assert f"Sitemap: {BASE}sitemap.xml" in (OUT / "robots.txt").read_text()
    llms = (OUT / "llms.txt").read_text()
    assert all(url(lang) in llms for lang in LOCALES)
    error_page = Page((OUT / "404.html").read_text())
    assert any(tag == "meta" and attrs.get("name") == "robots" and attrs.get("content") == "noindex" for tag, attrs in error_page.tags)
    assert {attrs["href"] for tag, attrs in error_page.tags if tag == "a"} >= {url(lang) for lang in LOCALES}
    print(f"PASS: {len(pages)} translated pages; internal links, anchors, metadata, hreflang, JSON-LD, sitemap, robots, and llms.txt")


if __name__ == "__main__":
    main()
