"""Regulatory Web and Change Monitor: crawl allowlisted portals and extract documents."""
from __future__ import annotations

import hashlib
import json
import posixpath
import re
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path
from typing import Dict, List, Optional, Tuple

LAB = Path(__file__).resolve().parents[1]
DATA = LAB / "data"

# Each crawl day is a snapshot of the training portals. A later day only stores
# pages that changed; unchanged pages are served from the earlier snapshot.
DAYS = {
    "monday": {"date": "2027-01-11", "layers": ["monday"]},
    "tuesday": {"date": "2027-01-12", "layers": ["tuesday", "monday"]},
}
MAX_PAGES_PER_PORTAL = 50
DOCUMENT_TYPES = {
    "regulation", "guidance", "safety-alert", "enforcement-letter", "coverage-decision", "pricing-rule",
}
SKIPPED_SECTIONS = {"nav", "footer", "aside", "header", "script", "style"}


@dataclass
class Page:
    portal: dict
    path: str
    html: str

    @property
    def url(self) -> str:
        return f"portal://{self.portal['id']}/{self.path}"


@dataclass
class Extracted:
    meta: Dict[str, str]
    title: str
    paragraphs: List[str]
    links: List[str]

    @property
    def content_hash(self) -> str:
        canonical = "\n".join([self.title] + self.paragraphs)
        return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


@dataclass
class CrawlResult:
    pages: List[Page] = field(default_factory=list)
    skipped_links: List[Tuple[str, str]] = field(default_factory=list)


class _Extractor(HTMLParser):
    """Keep the main text, drop navigation and boilerplate, collapse whitespace."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.meta: Dict[str, str] = {}
        self.links: List[str] = []
        self.blocks: List[Tuple[str, str]] = []
        self._skip_depth = 0
        self._capture: Optional[str] = None
        self._buffer: List[str] = []

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if tag == "meta" and attributes.get("name"):
            self.meta[attributes["name"].strip().lower()] = (attributes.get("content") or "").strip()
        if tag == "a" and attributes.get("href"):
            self.links.append(attributes["href"].strip())
        if tag in SKIPPED_SECTIONS:
            self._skip_depth += 1
        elif self._skip_depth == 0 and tag in {"h1", "p", "li"}:
            self._capture, self._buffer = tag, []

    def handle_endtag(self, tag):
        if tag in SKIPPED_SECTIONS and self._skip_depth:
            self._skip_depth -= 1
        elif tag == self._capture:
            text = " ".join("".join(self._buffer).split())
            if text:
                self.blocks.append((tag, text))
            self._capture = None

    def handle_data(self, data):
        if self._capture and self._skip_depth == 0:
            self._buffer.append(data)


def extract(html: str) -> Extracted:
    parser = _Extractor()
    parser.feed(html)
    parser.close()
    titles = [text for tag, text in parser.blocks if tag == "h1"]
    paragraphs = [text for tag, text in parser.blocks if tag == "p"]
    return Extracted(parser.meta, titles[0] if titles else "", paragraphs, parser.links)


def load_json(name: str) -> dict:
    return json.loads((DATA / "reference" / name).read_text(encoding="utf-8"))


def _read(day: str, portal_id: str, path: str) -> Optional[str]:
    for layer in DAYS[day]["layers"]:
        candidate = DATA / "portals" / layer / portal_id / path
        if candidate.is_file():
            return candidate.read_text(encoding="utf-8")
    return None


def crawl(day: str) -> CrawlResult:
    """Breadth-first crawl of every allowlisted portal, staying inside each portal."""
    if day not in DAYS:
        raise ValueError(f"Unknown crawl day '{day}'. Choose one of: {', '.join(DAYS)}.")
    result = CrawlResult()
    for portal in load_json("sources.json")["portals"]:
        queue, seen = [portal["start"]], set()
        while queue and len(seen) < MAX_PAGES_PER_PORTAL:
            path = queue.pop(0)
            if path in seen:
                continue
            seen.add(path)
            html = _read(day, portal["id"], path)
            if html is None:
                result.skipped_links.append((f"portal://{portal['id']}/{path}", "page not found"))
                continue
            result.pages.append(Page(portal, path, html))
            for href in extract(html).links:
                if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", href) or href.startswith("//"):
                    result.skipped_links.append((href, "outside the allowlisted portal"))
                    continue
                target = posixpath.normpath(posixpath.join(posixpath.dirname(path), href.split("#", 1)[0]))
                if target.startswith("..") or target.startswith("/"):
                    result.skipped_links.append((href, "outside the allowlisted portal"))
                elif target not in seen:
                    queue.append(target)
    return result


def enrich(extracted: Extracted, portal: dict) -> dict:
    """Add region, publisher, impacted domains and Caldova products to the metadata."""
    text = " ".join([extracted.title] + extracted.paragraphs).lower()
    domains = [
        name for name, keywords in load_json("domains.json")["domains"].items()
        if any(keyword in text for keyword in keywords)
    ]
    portfolio = load_json("portfolio.json")
    products = [
        product["id"] for product in portfolio["products"]
        if any(term in text for term in product["match"])
    ]
    markets = {market for product in portfolio["products"] for market in product["markets"]}
    document_type = extracted.meta.get("document-type", "")
    if document_type not in DOCUMENT_TYPES:
        raise ValueError(f"Unknown document type '{document_type}'.")
    return {
        "document_id": extracted.meta["document-id"],
        "title": extracted.title,
        "document_type": document_type,
        "published": extracted.meta.get("published") or None,
        "effective": extracted.meta.get("effective") or None,
        "region": portal["region"],
        "publisher": portal["publisher"],
        "source_kind": portal["kind"],
        "domains": domains,
        "products_named": products,
        "caldova_sells_in_region": portal["region"] in markets,
    }
