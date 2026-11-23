"""Choose thresholds from the cost of each kind of mistake (Challenge 4).

Accuracy treats every mistake the same. A marketplace does not: publishing a prohibited item is
far worse than sending a clean listing to a reviewer. So each question gets three costs, in
"reviewer-minutes" (one manual review = 1):

* `miss`        - a problem the gate let through (e.g. a prohibited item published)
* `false_alarm` - a clean listing the gate acted on (rejected, or sent to review)
* `review`      - an "unsure" answer, which always goes to a human

The tuner tries every pair of thresholds on the THRESHOLD split and keeps the cheapest. Change
the costs to match your business and run `gate tune` again - that is the point of the exercise.
Thresholds are chosen on the threshold split only and judged on the test split, never the
other way round.
"""

from __future__ import annotations

from gate.questions import QUESTIONS
from gate.rules import Thresholds
from gate.spec import Choice, GateCall, Score

# For each question: which answer is the "problem", and what each mistake costs.
# problem="yes": the problem is a "yes" answer. problem="no": the problem is a "no" answer
# (the photo checks). Score questions: the problem is level 0-1 (Poor or Unusable).
COSTS: dict[str, dict] = {
    "prohibited_item":      {"problem": "yes", "miss": 100, "false_alarm": 20, "review": 1},
    "off_platform_contact": {"problem": "yes", "miss": 50,  "false_alarm": 20, "review": 1},
    "contradicts_facts":    {"problem": "yes", "miss": 20,  "false_alarm": 20, "review": 1},
    "unsupported_claim":    {"problem": "yes", "miss": 5,   "false_alarm": 1,  "review": 1},
    "addressed_to_gate":    {"problem": "yes", "miss": 20,  "false_alarm": 1,  "review": 1},
    "photo_shows_product":  {"problem": "no",  "miss": 5,   "false_alarm": 1,  "review": 1},
    "photo_matches_title":  {"problem": "no",  "miss": 10,  "false_alarm": 1,  "review": 1},
    "listing_quality":      {"problem": "poor", "miss": 2,  "false_alarm": 1,  "review": 1},
    # Choice: a wrong confident answer becomes a wrong automatic category fix.
    "category":             {"wrong": 5, "review": 1},
}

GRID = [i / 100 for i in range(1, 100)]


def _problem_pairs(name: str, rows: list[dict], calls: list[GateCall], costs: dict | None = None) -> list[tuple[float, bool]]:
    """(P(problem), is_problem) for every listing where the question has a label and a probability."""
    q = next(q for q in QUESTIONS if q.name == name)
    problem = (costs or COSTS)[name]["problem"]
    pairs = []
    for row, call in zip(rows, calls):
        y = row["labels"].get(name)
        a = call.answers.get(name)
        if y is None or a is None or a.status != "ok":
            continue
        if isinstance(q, Score):
            if not a.distribution:
                continue
            p = sum(p for lvl, p in a.distribution.items() if int(lvl) <= 1)
            pairs.append((p, int(y) <= 1))
        else:
            if a.probability is None:
                continue
            if problem == "yes":
                pairs.append((a.probability, bool(y)))
            else:
                pairs.append((1 - a.probability, not bool(y)))
    return pairs


def _count(pairs, lo, hi):
    miss = fa = review = 0
    for p, bad in pairs:
        if p >= hi:
            fa += not bad
        elif p <= lo:
            miss += bad
        else:
            review += 1
    return miss, fa, review


def tune_yes_no(name: str, rows: list[dict], calls: list[GateCall], costs: dict | None = None) -> dict | None:
    """Cheapest (lo, hi) on P(problem): flag at or above hi, clear at or below lo, review between."""
    pairs = _problem_pairs(name, rows, calls)
    if not pairs:
        return None
    c = COSTS[name]
    best = None
    for lo in GRID:
        for hi in GRID:
            if hi <= lo:
                continue
            miss, fa, review = _count(pairs, lo, hi)
            cost = c["miss"] * miss + c["false_alarm"] * fa + c["review"] * review
            # Ties: fewer reviews, then the widest "unsure" band (the most cautious choice).
            key = (cost, review, -(hi - lo))
            if best is None or key < best[0]:
                best = (key, lo, hi, miss, fa, review)
    (cost, _, _), lo, hi, miss, fa, review = best
    # Back to the gate's terms: thresholds on P(yes) (or P(poor) for the score question).
    if c["problem"] == "no":
        yes, no = round(1 - lo, 2), round(1 - hi, 2)
    else:
        yes, no = round(hi, 2), round(lo, 2)
    return {"yes": yes, "no": no, "miss": miss, "false_alarm": fa, "review": review,
            "cost": cost, "n": len(pairs)}


def tune_choice(name: str, rows: list[dict], calls: list[GateCall], costs: dict | None = None) -> dict | None:
    pairs = []
    for row, call in zip(rows, calls):
        y = row["labels"].get(name)
        a = call.answers.get(name)
        if y is None or a is None or a.status != "ok" or a.probability is None:
            continue
        pairs.append((a.probability, a.value == y))
    if not pairs:
        return None
    c = COSTS[name]
    best = None
    for th in GRID:
        wrong = sum(1 for p, ok in pairs if p >= th and not ok)
        review = sum(1 for p, _ in pairs if p < th)
        # Ties: fewer reviews, then the highest threshold (the most cautious choice).
        key = (c["wrong"] * wrong + c["review"] * review, review, -th)
        if best is None or key < best[0]:
            best = (key, th, wrong, review)
    (cost, _, _), th, wrong, review = best
    return {"choice": th, "wrong": wrong, "review": review, "cost": cost, "n": len(pairs)}


def tune(rows: list[dict], calls: list[GateCall], costs: dict | None = None) -> tuple[Thresholds, dict]:
    """Per-question thresholds that minimise the costs above. Questions the run has no
    probabilities for (the generative baseline) keep the defaults."""
    t = Thresholds()
    detail: dict[str, dict] = {}
    for q in QUESTIONS:
        if q.name not in COSTS:
            continue
        d = tune_choice(q.name, rows, calls) if isinstance(q, Choice) else tune_yes_no(q.name, rows, calls)
        if d is None:
            continue
        detail[q.name] = d
        t.per_question[q.name] = {"choice": d["choice"]} if "choice" in d else {"yes": d["yes"], "no": d["no"]}
    return t, detail
