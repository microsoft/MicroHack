"""Score a run against the answer key: per-question quality, calibration, and gate outcomes.

The per-question scoring follows Microsoft's Decision-Benchmarks runner (`dbrun`,
https://github.com/microsoftconnect/Decision-Benchmarks) so your numbers mean the same thing:

* yes/no counts as yes when P(yes) >= 0.5; choice and score count the most probable option;
* `accuracy`, `ece` (expected calibration error, 10 bins) and `brier`;
* `rep_agreement` when the same listings are asked more than once (Challenge 5);
* answers that are missing, refused or failed are left out of accuracy — never counted as
  wrong — and reported as `coverage` instead.

Read the numbers with care. The dataset is a constructed sample (about a quarter of it is
clean), not real marketplace traffic, and a few hundred listings can't certify a safety
level. Every rate below is shown with its count, and `upper_bound()` tells you how bad a
rate could still plausibly be.
"""

from __future__ import annotations

import math
import statistics
from collections import Counter, defaultdict

import config
from gate.questions import QUESTIONS
from gate.rules import Decision, Thresholds, decide
from gate.spec import Answer, Choice, GateCall, Score, YesNo


def upper_bound(failures: int, n: int, confidence: float = 0.95) -> float:
    """One-sided Clopper-Pearson upper bound on a failure rate (e.g. 0 failures in 300 -> ~1%)."""
    if n == 0:
        return 1.0
    if failures >= n:
        return 1.0
    alpha = 1 - confidence

    def cdf(p: float) -> float:  # P(X <= failures) for X ~ Binomial(n, p)
        return sum(math.comb(n, k) * p**k * (1 - p) ** (n - k) for k in range(failures + 1))

    lo, hi = failures / n, 1.0
    for _ in range(60):
        mid = (lo + hi) / 2
        if cdf(mid) > alpha:
            lo = mid
        else:
            hi = mid
    return hi


def truth(question, label):
    """The answer-key value for a question, or None when it isn't scored for that listing."""
    if label is None:
        return None
    if isinstance(question, Score):
        return int(label)
    return label


def calibration(pairs: list[tuple[float, bool]], bins: int = 10) -> dict:
    """Brier score, expected calibration error (10 bins, as dbrun) and a reliability table with
    bin counts. Bins with few listings say little — always read `n`."""
    if not pairs:
        return {}
    brier = statistics.fmean((p - float(y)) ** 2 for p, y in pairs)
    table, ece = [], 0.0
    for b in range(bins):
        lo, hi = b / bins, (b + 1) / bins
        inside = [(p, y) for p, y in pairs if (lo <= p < hi) or (b == bins - 1 and p == 1.0)]
        if not inside:
            continue
        mean_p = statistics.fmean(p for p, _ in inside)
        frac = statistics.fmean(float(y) for _, y in inside)
        ece += len(inside) / len(pairs) * abs(mean_p - frac)
        table.append({"bin": f"{lo:.1f}-{hi:.1f}", "n": len(inside), "mean_p": round(mean_p, 3), "observed": round(frac, 3)})
    return {"brier": round(brier, 4), "ece": round(ece, 4), "table": table}


def question_metrics(rows: list[dict], calls: list[GateCall], questions=None) -> dict:
    out = {}
    for q in questions or QUESTIONS:
        correct, n, failed, pairs, within1, exact = 0, 0, 0, [], 0, 0
        for row, call in zip(rows, calls):
            y = truth(q, row["labels"].get(q.name))
            a: Answer | None = call.answers.get(q.name)
            if y is None or a is None or a.status == "not_asked":
                continue
            n += 1
            if a.status != "ok":
                failed += 1
                continue
            if isinstance(q, YesNo):
                pred = (a.probability >= 0.5) if a.probability is not None else bool(a.value)
                correct += pred == y
                if a.probability is not None:
                    pairs.append((a.probability, bool(y)))
            elif isinstance(q, Choice):
                correct += a.value == y
                if a.probability is not None:
                    pairs.append((a.probability, a.value == y))
            else:  # Score: the gate only needs "Poor or worse?", so that is the headline
                # accuracy; the exact level is subjective (is it Good or Acceptable?) and reported
                # separately, with "within one level".
                if a.distribution:
                    p_poor = sum(p for lvl, p in a.distribution.items() if int(lvl) <= 1)
                    pairs.append((p_poor, y <= 1))
                    pred_poor = p_poor >= 0.5
                else:
                    pred_poor = a.value is not None and int(a.value) <= 1
                correct += pred_poor == (y <= 1)
                exact += a.value == y
                within1 += a.value is not None and abs(int(a.value) - y) <= 1
        answered = n - failed
        m = {"kind": q.kind, "n": n, "answered": answered,
             "coverage": round(answered / n, 3) if n else None,
             "accuracy": round(correct / answered, 3) if answered else None}
        if isinstance(q, Score) and answered:
            m["accuracy_means"] = "poor (level 0-1) vs not poor"
            m["exact_level"] = round(exact / answered, 3)
            m["within_one_level"] = round(within1 / answered, 3)
        if pairs:
            m["calibration"] = calibration(pairs)
        out[q.name] = m
    return out


def gate_metrics(rows: list[dict], decisions: list[Decision]) -> dict:
    confusion: dict[str, Counter] = defaultdict(Counter)
    for row, d in zip(rows, decisions):
        confusion[row["expected"]["outcome"]][d.outcome] += 1
    n = len(rows)
    auto = [(r, d) for r, d in zip(rows, decisions) if d.outcome in ("publish", "auto_fix")]
    unsafe = [(r, d) for r, d in auto if r["expected"]["outcome"] in ("review", "reject")]
    should_pass = [r for r in rows if r["expected"]["outcome"] in ("publish", "auto_fix")]
    false_reject = sum(1 for r, d in zip(rows, decisions)
                       if d.outcome == "reject" and r["expected"]["outcome"] != "reject")
    fixes = [(r, d) for r, d in zip(rows, decisions) if d.outcome == "auto_fix"]
    good_fixes = sum(1 for r, d in fixes if d.category_fix == r["labels"].get("category"))
    reviews = sum(1 for d in decisions if d.outcome == "review")
    return {
        "listings": n,
        "outcome_accuracy": round(sum(r["expected"]["outcome"] == d.outcome for r, d in zip(rows, decisions)) / n, 3) if n else None,
        "review_rate": round(reviews / n, 3) if n else None,
        "auto_published": len(auto),
        "unsafe_published": len(unsafe),
        "unsafe_rate_among_auto_published": round(len(unsafe) / len(auto), 4) if auto else None,
        "unsafe_rate_upper_95": round(upper_bound(len(unsafe), len(auto)), 4) if auto else None,
        "good_listings_auto_published": round(sum(1 for r, d in auto if r["expected"]["outcome"] in ("publish", "auto_fix")) / len(should_pass), 3) if should_pass else None,
        "false_rejects": false_reject,
        "auto_fixes": len(fixes),
        "auto_fix_correct": good_fixes,
        "unsafe_examples": [{"listing_id": r["listing_id"], "expected": r["expected"]["outcome"],
                             "got": d.outcome, "construction": r["construction"]} for r, d in unsafe[:10]],
        "confusion": {exp: dict(c) for exp, c in confusion.items()},
    }


def operations(mode: str, calls: list[GateCall]) -> dict:
    lat = sorted(c.latency_ms for c in calls if c.latency_ms is not None)
    ok = [c for c in calls if not c.error]
    price = config.PRICES.get(mode, {"input": 0.0, "output": 0.0})
    tin = statistics.fmean(c.input_tokens for c in ok) if ok else 0
    tout = statistics.fmean(c.output_tokens for c in ok) if ok else 0
    per_listing = (tin * price["input"] + tout * price["output"]) / 1_000_000

    def pct(p: float) -> float | None:
        return round(lat[min(len(lat) - 1, int(p * len(lat)))]) if lat else None

    return {
        "requests": len(calls),
        "errors": sum(1 for c in calls if c.error),
        "latency_p50_ms": pct(0.5),
        "latency_p95_ms": pct(0.95),
        "queued_s": round(sum(c.wait_ms for c in calls) / 1000, 1),
        "mean_input_tokens": round(tin),
        "mean_output_tokens": round(tout, 1),
        "est_cost_per_10k_listings_usd": round(per_listing * 10_000, 2),
        "price_assumption_usd_per_1m": price,
    }


def oracle_call(row: dict) -> GateCall:
    """A 'perfect model' built from the answer key. Running it through the rules must
    reproduce every expected outcome — a check that rules.py and the dataset agree."""
    answers = {}
    for q in QUESTIONS:
        y = row["labels"].get(q.name)
        if q.requires_photo and not row.get("image"):
            answers[q.name] = Answer(name=q.name, kind=q.kind, status="not_asked")
        elif y is None:
            # Not scored: give the rules a confident, harmless answer.
            harmless = {"category": row["seller_category"], "listing_quality": 3}.get(q.name, False)
            answers[q.name] = Answer(name=q.name, kind=q.kind, value=harmless,
                                     probability=1.0 if not isinstance(q, YesNo) else 0.0,
                                     distribution={"3": 1.0} if isinstance(q, Score) else {})
        elif isinstance(q, YesNo):
            answers[q.name] = Answer(name=q.name, kind=q.kind, probability=1.0 if y else 0.0)
        elif isinstance(q, Choice):
            answers[q.name] = Answer(name=q.name, kind=q.kind, value=y, probability=1.0)
        else:
            answers[q.name] = Answer(name=q.name, kind=q.kind, value=int(y), probability=1.0,
                                     distribution={str(int(y)): 1.0})
    return GateCall(model="oracle", answers=answers)


def predicted(a: Answer | None) -> object | None:
    """The answer as a label, scored the dbrun way (yes at P>=0.5, else the most probable option)."""
    if a is None or a.status != "ok":
        return None
    if a.kind == "yes_no":
        return (a.probability >= 0.5) if a.probability is not None else bool(a.value)
    return a.value


def rep_agreement(first: list[GateCall], second: list[GateCall]) -> dict:
    """How often asking the same question twice gives the same answer (dbrun's `rep_agreement`)."""
    out = {}
    for q in QUESTIONS:
        same = n = 0
        for a, b in zip(first, second):
            pa, pb = predicted(a.answers.get(q.name)), predicted(b.answers.get(q.name))
            if pa is None or pb is None:
                continue
            n += 1
            same += pa == pb
        out[q.name] = {"n": n, "agreement": round(same / n, 3) if n else None}
    return out


def draft_questions():
    """The question set with the two atomic claim questions replaced by the first draft (Challenge 2)."""
    from gate.questions import FIRST_DRAFT_CLAIMS
    out = []
    for q in QUESTIONS:
        if q.name == "contradicts_facts":
            out.append(FIRST_DRAFT_CLAIMS)
        elif q.name != "unsupported_claim":
            out.append(q)
    return out


def questions_for(head: dict):
    """The question set a saved run was asked with (None = the final gate questions)."""
    return draft_questions() if head.get("draft") else None


def report(mode: str, rows: list[dict], calls: list[GateCall], thresholds: Thresholds | None = None,
           questions=None) -> dict:
    if questions is not None:  # a different question set: per-question metrics only
        return {"mode": mode, "questions": question_metrics(rows, calls, questions),
                "gate": None, "operations": operations(mode, calls)}
    decisions = [decide(r, c, thresholds) for r, c in zip(rows, calls)]
    return {
        "mode": mode,
        "questions": question_metrics(rows, calls),
        "gate": gate_metrics(rows, decisions),
        "operations": operations(mode, calls),
    }
