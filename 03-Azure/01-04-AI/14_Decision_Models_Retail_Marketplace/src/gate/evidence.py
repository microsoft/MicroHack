"""Load the marketplace data and turn one listing into the evidence a model sees.

Only these fields ever reach a model: the seller's title, description, chosen category and
price, the manufacturer facts looked up by GTIN, and the photo. The dataset's `labels`,
`expected` and `construction` fields are the answer key and are never sent.
"""

from __future__ import annotations

import base64
import functools
import json
from dataclasses import dataclass
from typing import Literal

import config

Layout = Literal["structured", "plain"]


@functools.lru_cache(maxsize=1)
def catalogue() -> dict:
    return json.loads((config.DATA / "catalogue.json").read_text(encoding="utf-8"))


@functools.lru_cache(maxsize=1)
def products_by_gtin() -> dict[str, dict]:
    return {p["gtin"]: p for p in catalogue()["products"]}


@functools.lru_cache(maxsize=1)
def listings() -> list[dict]:
    return json.loads((config.DATA / "listings.json").read_text(encoding="utf-8"))


def listing(listing_id: str) -> dict:
    for row in listings():
        if row["listing_id"] == listing_id:
            return row
    raise KeyError(f"No listing {listing_id!r} in data/listings.json")


def select(split: str | None = None, starter: bool = False, limit: int | None = None,
           ids: list[str] | None = None) -> list[dict]:
    rows = listings()
    if ids:
        wanted = set(ids)
        rows = [r for r in rows if r["listing_id"] in wanted]
    if split and split != "all":
        rows = [r for r in rows if r["split"] == split]
    if starter:
        rows = [r for r in rows if r.get("starter")]
    return rows[:limit] if limit else rows


@functools.lru_cache(maxsize=64)
def photo_base64(file_name: str) -> str:
    return base64.b64encode((config.DATA / "images" / file_name).read_bytes()).decode("ascii")


@dataclass
class Evidence:
    """What the model receives: a JSON-able state (or plain text) and an optional photo."""

    state: dict | str
    photo_b64: str | None  # JPEG, base64

    def text(self) -> str:
        return self.state if isinstance(self.state, str) else json.dumps(self.state, ensure_ascii=False, indent=1)


def build(row: dict, layout: Layout = "structured") -> Evidence:
    product = products_by_gtin().get(row.get("gtin") or "")
    facts = ({"product_name": product["name"], "brand": product["brand"], **product["facts"]}
             if product else "not available (GTIN not in the Zava catalogue)")
    photo = photo_base64(row["image"]) if row.get("image") else None
    seller = {
        "title": row["title"],
        "description": row["description"],
        "seller_category": row["seller_category"],
        "price_eur": row["price_eur"],
    }
    if layout == "structured":
        state = {
            "seller_listing": seller,
            "manufacturer_facts": facts,
            "photo": "attached" if photo else "none",
        }
    else:
        # One run-on block of text, the way many first prototypes do it (Challenge 5 compares).
        facts_text = facts if isinstance(facts, str) else ", ".join(f"{k}: {v}" for k, v in facts.items())
        state = (f"{seller['title']}\n{seller['description']}\nCategory: {seller['seller_category']}\n"
                 f"Price: {seller['price_eur']} EUR\nFacts: {facts_text}\nPhoto: {'attached' if photo else 'none'}")
    return Evidence(state=state, photo_b64=photo)
