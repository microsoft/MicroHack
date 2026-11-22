"""Launch Day: turn a gate run into the numbers Zava's managers care about.

The gate's metrics (accuracy, review rate, unsafe published) answer "is the model right?".
The launch scorecard answers "what happens on Monday?": how many listings go live in seconds,
how many reviewer hours that leaves, how many bad listings customers would see, and what a day
costs. The assumptions are deliberately simple and visible, and you can change them.
"""

from __future__ import annotations

from collections import Counter, defaultdict

from gate import metrics
from gate.rules import PIECES, Thresholds, decide

ASSUMPTIONS = {
    "listings_per_day": 10_000,
    "minutes_per_review": 2.0,
    "eur_per_reviewer_hour": 30.0,
    "reviewers": 3,
    "eur_per_usd": 0.9,
}

# What kind of problem a listing has, in plain words, and which piece of the gate catches it.
KINDS = [
    ("prohibited", "banned product", "safety"),
    ("off_platform_contact", "contact details to dodge the marketplace", "safety"),
    ("hard:obfuscated_contact", "contact details to dodge the marketplace", "safety"),
    ("contradicted", "a spec that contradicts the manufacturer", "truth"),
    ("unsupported_claim", "an invented feature or warranty", "truth"),
    ("aimed_at_gate", "a note aimed at the reviewer", "truth"),
    ("hard:subtle_aimed_at_gate", "a note aimed at the reviewer", "truth"),
    ("photo_of", "a photo of a different product", "truth"),
    ("hard:similar_photo_of", "a photo of a different product", "truth"),
    ("uninformative_photo", "a photo that shows nothing useful", "truth"),
    ("no_photo", "no photo", "truth"),
    ("price_", "a suspicious price", "truth"),
    ("unknown_gtin", "a product Zava doesn't know", "truth"),
    ("poor_quality", "a listing too poor to sell", "shelf"),
    ("vague", "a listing too poor to sell", "shelf"),
    ("wrong_category", "in the wrong aisle", "shelf"),
]


def kind_of(construction: list[str]) -> tuple[str, str]:
    """The most serious problem a listing has (KINDS is ordered from most to least serious)."""
    for prefix, label, piece in KINDS:
        if any(tag.startswith(prefix) for tag in construction):
            return label, piece
    return "other", ""


def wrong_aisle(row: dict, d) -> bool:
    """Live, but in a category a shopper wouldn't look in."""
    right = row["labels"].get("category")
    if not right or d.outcome not in ("publish", "auto_fix"):
        return False
    shown = d.category_fix if d.outcome == "auto_fix" else row["seller_category"]
    return shown != right


def scorecard(mode: str, rows: list[dict], calls, t: Thresholds, assumptions: dict | None = None) -> dict:
    a = {**ASSUMPTIONS, **(assumptions or {})}
    decisions = [decide(r, c, t) for r, c in zip(rows, calls)]
    n = len(rows)
    per_day = a["listings_per_day"] / n if n else 0
    outcomes = Counter(d.outcome for d in decisions)
    live = outcomes["publish"] + outcomes["auto_fix"]

    bad, aisle = defaultdict(list), []
    honest_to_review = 0
    for r, d in zip(rows, decisions):
        exp = r["expected"]["outcome"]
        if d.outcome in ("publish", "auto_fix") and exp in ("review", "reject"):
            label, piece = kind_of(r["construction"])
            bad[label].append({"listing_id": r["listing_id"], "title": r["title"], "piece": piece})
        elif wrong_aisle(r, d):
            aisle.append({"listing_id": r["listing_id"], "title": r["title"]})
        if d.outcome == "review" and exp in ("publish", "auto_fix"):
            honest_to_review += 1

    on = [p for p in PIECES if t.on(p)]
    reviews_day = outcomes["review"] * per_day
    hours = reviews_day * a["minutes_per_review"] / 60
    ops = metrics.operations(mode, calls)
    model_eur = (ops["est_cost_per_10k_listings_usd"] * a["listings_per_day"] / 10_000 * a["eur_per_usd"]) if on else 0.0
    reviewer_eur = hours * a["eur_per_reviewer_hour"]
    n_bad = sum(len(v) for v in bad.values())
    return {
        "pieces": on,
        "listings": n,
        "outcomes": dict(outcomes),
        "live_fast_pct": round(100 * live / n, 1) if n else 0,
        "bad_live_per_10k": round(n_bad * 10_000 / n) if n else 0,
        "wrong_aisle_per_10k": round(len(aisle) * 10_000 / n) if n else 0,
        "reviews_per_day": round(reviews_day),
        "reviewer_hours_per_day": round(hours),
        "reviewer_days_per_day": round(hours / 8, 1),
        "honest_sent_to_review_per_10k": round(honest_to_review * 10_000 / n) if n else 0,
        "cost_per_day_eur": round(reviewer_eur + model_eur),
        "reviewer_cost_per_day_eur": round(reviewer_eur),
        "model_cost_per_day_eur": round(model_eur, 2),
        "bad_live": [{"kind": k, "count": len(v), "examples": v[:4]} for k, v in sorted(bad.items(), key=lambda x: -len(x[1]))],
        "bad_live_count": n_bad,
        "wrong_aisle": aisle[:6],
        "wrong_aisle_count": len(aisle),
        "assumptions": a,
    }


def check_everything_by_hand(assumptions: dict | None = None) -> dict:
    """The no-AI alternative: a person reads every listing."""
    a = {**ASSUMPTIONS, **(assumptions or {})}
    hours = a["listings_per_day"] * a["minutes_per_review"] / 60
    return {"live_fast_pct": 0, "bad_live_per_10k": 0, "wrong_aisle_per_10k": 0,
            "reviews_per_day": a["listings_per_day"], "reviewer_hours_per_day": round(hours),
            "reviewer_days_per_day": round(hours / 8, 1), "cost_per_day_eur": round(hours * a["eur_per_reviewer_hour"])}
