"""Turn decision-model answers into one gate outcome, following Listing Policy v1.0.

The model answers questions; this code makes the decision. That split matters:

* **Thresholds are yours.** A probability becomes "yes", "no" or "unsure" only by comparing it
  with a threshold you chose on held-out data (Challenge 4). "Unsure" always goes to review.
* **Arithmetic is code.** Price checks and "did the seller pick the wrong category?" never go
  to a model.
* **Failures are never "no".** A refused, missing or failed answer sends the listing to review.
* **Precedence is explicit.** `reject` > `review` > `auto_fix` > `publish`. A listing is
  published only when every check passes.
"""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from pathlib import Path

from gate import evidence
from gate.spec import Answer, GateCall

RANK = {"publish": 0, "auto_fix": 1, "review": 2, "reject": 3}
PRICE_LOW, PRICE_HIGH = 0.40, 2.50  # policy section 6


@dataclass
class Thresholds:
    """`yes`: P(yes) at or above this means yes. `no`: P(yes) at or below this means no.
    Anything in between is unsure. `choice`: the chosen option needs at least this probability.
    `per_question` overrides any of these for one question, e.g. {"prohibited_item": {"no": 0.05}}."""

    yes: float = 0.80
    no: float = 0.20
    choice: float = 0.70
    per_question: dict[str, dict[str, float]] = field(default_factory=dict)
    # Which gate pieces are switched on (see PIECES); None = the whole gate. Not saved with the
    # thresholds: the console keeps it separately while you build the gate piece by piece.
    pieces: list[str] | None = None

    def get(self, question: str, key: str) -> float:
        return self.per_question.get(question, {}).get(key, getattr(self, key))

    def on(self, piece: str) -> bool:
        return self.pieces is None or piece in self.pieces

    @classmethod
    def load(cls, path: str | Path | None) -> "Thresholds":
        if not path:
            return cls()
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        data.pop("pieces", None)
        return cls(**data)

    def save(self, path: str | Path) -> None:
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        data = asdict(self)
        data.pop("pieces", None)
        Path(path).write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


# The gate is built in three pieces, one per challenge. Each piece owns some checks.
PIECES = {
    "safety": "Safety check: prohibited items and off-platform contact",
    "truth": "Truth check: claims, photo, price and notes aimed at the gate",
    "shelf": "Shelf check: the right category and a listing good enough to sell",
}


@dataclass
class Reason:
    outcome: str
    check: str
    message: str


@dataclass
class Decision:
    outcome: str
    reasons: list[Reason]
    category_fix: str | None = None
    signals: dict[str, str] = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {"outcome": self.outcome, "category_fix": self.category_fix, "signals": self.signals,
                "reasons": [asdict(r) for r in self.reasons]}


def yes_no(a: Answer | None, t: Thresholds) -> str:
    """'yes', 'no', 'unsure' or 'failed'. A generative answer (no probability) is taken at face value."""
    if a is None or a.status != "ok":
        return "failed"
    if a.probability is None:  # generative baseline: no probability to threshold
        return "yes" if a.value else "no"
    if a.probability >= t.get(a.name, "yes"):
        return "yes"
    if a.probability <= t.get(a.name, "no"):
        return "no"
    return "unsure"


def choice(a: Answer | None, t: Thresholds) -> str:
    """The chosen option, or 'unsure' / 'failed'."""
    if a is None or a.status != "ok" or a.value is None:
        return "failed"
    if a.probability is not None and a.probability < t.get(a.name, "choice"):
        return "unsure"
    return str(a.value)


def poor_quality(a: Answer | None, t: Thresholds) -> str:
    """'yes' if the listing is Poor or Unusable (levels 0-1). Uses P(level <= 1), not the average."""
    if a is None or a.status != "ok":
        return "failed"
    if not a.distribution:  # generative baseline
        return "yes" if (a.value is not None and int(a.value) <= 1) else "no"
    p_poor = sum(p for level, p in a.distribution.items() if int(level) <= 1)
    if p_poor >= t.get(a.name, "yes"):
        return "yes"
    if p_poor <= t.get(a.name, "no"):
        return "no"
    return "unsure"


def decide(row: dict, call: GateCall, t: Thresholds | None = None) -> Decision:
    t = t or Thresholds()
    a = call.answers
    reasons: list[Reason] = []
    signals: dict[str, str] = {}

    def add(outcome: str, check: str, message: str) -> None:
        reasons.append(Reason(outcome, check, message))

    def unclear(check: str, state: str) -> None:
        what = check.replace("_", " ")
        add("review", check, f"the model could not answer: {what}" if state == "failed" else f"the model is unsure: {what}")

    product = evidence.products_by_gtin().get(row.get("gtin") or "")

    # 1. Prohibited items -> reject
    if t.on("safety"):
        s = signals["prohibited_item"] = yes_no(a.get("prohibited_item"), t)
        if s == "yes":
            add("reject", "prohibited_item", "prohibited item")
        elif s != "no":
            unclear("prohibited_item", s)

    # 2. Off-platform contact -> reject
    if t.on("safety"):
        s = signals["off_platform_contact"] = yes_no(a.get("off_platform_contact"), t)
        if s == "yes":
            add("reject", "off_platform_contact", "off-platform contact")
        elif s != "no":
            unclear("off_platform_contact", s)

    # 3. Claims vs manufacturer facts (only checkable when the GTIN is in the catalogue)
    if t.on("truth"):
        if product is None:
            add("review", "gtin", "GTIN not in catalogue")
        else:
            s = signals["contradicts_facts"] = yes_no(a.get("contradicts_facts"), t)
            if s == "yes":
                add("reject", "contradicts_facts", "claim contradicts manufacturer facts")
            elif s != "no":
                unclear("contradicts_facts", s)
            s = signals["unsupported_claim"] = yes_no(a.get("unsupported_claim"), t)
            if s == "yes":
                add("review", "unsupported_claim", "claim not supported by manufacturer facts")
            elif s != "no":
                unclear("unsupported_claim", s)

    # 4. Category (the comparison with the seller's choice is code, not a question)
    fix = None
    if t.on("shelf"):
        s = signals["category"] = choice(a.get("category"), t)
        if s == "cannot_tell":
            add("review", "category", "category cannot be determined")
        elif s in ("unsure", "failed"):
            unclear("category", s)
        elif s != row["seller_category"]:
            fix = s

    # 5. Photo
    if t.on("truth"):
        if not row.get("image"):
            add("review", "photo", "no photo")
        else:
            s = signals["photo_shows_product"] = yes_no(a.get("photo_shows_product"), t)
            if s == "no":
                add("review", "photo_shows_product", "photo does not show a product")
            elif s != "yes":
                unclear("photo_shows_product", s)
            else:
                s = signals["photo_matches_title"] = yes_no(a.get("photo_matches_title"), t)
                if s == "no":
                    add("review", "photo_matches_title", "photo shows a different product")
                elif s != "yes":
                    unclear("photo_matches_title", s)

    # 6. Price (code only)
    if t.on("truth"):
        if product is not None:
            ratio = row["price_eur"] / product["reference_price_eur"]
            if ratio < PRICE_LOW or ratio > PRICE_HIGH:
                add("review", "price", f"implausible price ({ratio:.0%} of the reference price)")

    # 7. Listing quality
    if t.on("shelf"):
        s = signals["listing_quality"] = poor_quality(a.get("listing_quality"), t)
        if s == "yes":
            add("review", "listing_quality", "poor listing quality")
        elif s != "no":
            unclear("listing_quality", s)

    # 8. Text aimed at the gate
    if t.on("truth"):
        s = signals["addressed_to_gate"] = yes_no(a.get("addressed_to_gate"), t)
        if s == "yes":
            add("review", "addressed_to_gate", "text aimed at the gate (flag to trust and safety)")
        elif s != "no":
            unclear("addressed_to_gate", s)

    if fix and signals.get("prohibited_item") != "yes":
        add("auto_fix", "category", f"category corrected to {fix}")

    if not reasons:
        return Decision("publish", [], None, signals)
    outcome = max(reasons, key=lambda r: RANK[r.outcome]).outcome
    return Decision(outcome, [r for r in reasons if r.outcome == outcome],
                    fix if outcome == "auto_fix" else None, signals)
