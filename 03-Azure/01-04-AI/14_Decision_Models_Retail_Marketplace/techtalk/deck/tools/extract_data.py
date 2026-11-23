"""Export the real numbers the tech-talk deck animates, from the hack's recorded runs.

Run from the hack's src folder (uses the gate library and data/recorded/):
    cd ../src && python ../techtalk/deck/tools/extract_data.py
Writes techtalk/deck/js/data.js. Nothing here calls a model.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

SRC = Path(__file__).resolve().parents[3] / "src"
sys.path.insert(0, str(SRC))

import config  # noqa: E402
from gate import evaluate, metrics, tune  # noqa: E402
from gate.questions import QUESTIONS  # noqa: E402
from gate.rules import Thresholds, decide  # noqa: E402
from gate.spec import Score  # noqa: E402

RECORDED = config.DATA / "recorded" / "decision-all.jsonl"
OUT = Path(__file__).resolve().parents[1] / "js" / "data.js"

head, rows, calls = evaluate.load(RECORDED)
by_id = {r["listing_id"]: (r, c) for r, c in zip(rows, calls)}
Q = {q.name: q for q in QUESTIONS}


def split(name: str):
    return [(r, c) for r, c in zip(rows, calls) if r["split"] == name]


def listing(lid: str) -> dict:
    r, _ = by_id[lid]
    return {"id": lid, "title": r["title"], "description": r["description"][:320], "price": r["price_eur"],
            "seller_category": r.get("seller_category"), "expected": r["expected"]["outcome"]}


def answer(lid: str, name: str) -> dict:
    a = by_id[lid][1].answers[name]
    q = Q[name]
    out = {"name": name, "kind": a.kind,
           "probability": round(a.probability, 4) if a.probability is not None else None}
    if a.distribution:
        names = {str(i): lvl.value for i, lvl in enumerate(q.levels)} if isinstance(q, Score) else {}
        dist = [[names.get(str(k), str(k)), round(v, 4)] for k, v in a.distribution.items()]
        out["distribution"] = dist if isinstance(q, Score) else sorted(dist, key=lambda kv: -kv[1])
        out["value"] = names.get(str(a.value), a.value)
    return out


tr, te = split("threshold"), split("test")


def pairs_for(name: str, part):
    return [(round(c.answers[name].probability, 4), bool(r["labels"][name])) for r, c in part
            if r["labels"].get(name) is not None and c.answers.get(name) is not None
            and c.answers[name].status == "ok" and c.answers[name].probability is not None]


# The dial: P(yes) for unsupported_claim on the rehearsal, with the answer key, and the tuned lines.
tuned_t, detail = tune.tune([r for r, _ in tr], [c for _, c in tr])
dial = {"question": "unsupported_claim", "instructions": Q["unsupported_claim"].instructions,
        "split": "threshold", "pairs": pairs_for("unsupported_claim", tr),
        "default": {"no": 0.20, "yes": 0.80},
        "tuned": {k: detail["unsupported_claim"][k] for k in ("no", "yes")}}

# The gate tour: real outcomes with the default dial.
default_t = Thresholds()


def gate_case(lid: str, focus: list[str]) -> dict:
    r, c = by_id[lid]
    d = decide(r, c, default_t)
    return {**listing(lid), "outcome": d.outcome, "reasons": [x.message for x in d.reasons][:2],
            "answers": [answer(lid, n) for n in focus]}


def first(pred) -> str:
    return next(r["listing_id"] for r, c in tr if pred(r, c, decide(r, c, default_t)))


clean = first(lambda r, c, d: r["expected"]["outcome"] == "publish" and d.outcome == "publish")
aisle = first(lambda r, c, d: r["expected"]["outcome"] == "auto_fix" and d.outcome == "auto_fix")
tour = [gate_case(clean, ["off_platform_contact", "prohibited_item"]),
        gate_case(aisle, ["category"]),
        gate_case("ZM-0060", ["listing_quality"]),
        gate_case("ZM-0352", ["off_platform_contact"]),
        gate_case("ZM-0828", ["category"])]

types = {"yes_no": {**listing("ZM-0352"), "question": Q["off_platform_contact"].instructions,
                    "answer": answer("ZM-0352", "off_platform_contact")},
         "choice": {**listing("ZM-0828"), "question": Q["category"].instructions,
                    "answer": answer("ZM-0828", "category")},
         "score": {**listing("ZM-0060"), "question": Q["listing_quality"].instructions,
                   "answer": answer("ZM-0060", "listing_quality")}}

calibration = {"question": "unsupported_claim", "split": "test",
               **metrics.calibration(pairs_for("unsupported_claim", te))}


def recorded_call(run: str, lid: str, name: str) -> dict:
    h, rs, cs = evaluate.load(config.DATA / "recorded" / run)
    r, c = next((r, c) for r, c in zip(rs, cs) if r["listing_id"] == lid)
    a = c.answers.get(name)
    return {"run": run, "deployment": h.get("deployment"), "latency_ms": round(c.latency_ms or 0),
            "input_tokens": c.input_tokens, "output_tokens": c.output_tokens,
            "probability": a.probability if a else None, "value": a.value if a else None,
            "status": a.status if a else None}


three_tools = {"listing": listing("ZM-0352"), "question": Q["off_platform_contact"].instructions,
               "decision": recorded_call("decision-all.jsonl", "ZM-0352", "off_platform_contact"),
               "llm": recorded_call("llm-all.jsonl", "ZM-0352", "off_platform_contact")}

data = {"source": f"{RECORDED.name}, recorded {head.get('created', '')[:10]}",
        "dial": dial, "tour": tour, "types": types, "calibration": calibration, "three_tools": three_tools,
        "upper_bound_1_in_387": round(metrics.upper_bound(1, 387), 4)}
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("// Generated by tools/extract_data.py from the hack's recorded runs. Do not edit.\n"
               f"window.TALK_DATA = {json.dumps(data, ensure_ascii=False, indent=1)};\n", encoding="utf-8")
print(f"wrote {OUT.name}: dial n={len(dial['pairs'])} tuned={dial['tuned']} "
      f"tour={[t['id'] + ':' + t['outcome'] for t in tour]} ece={calibration.get('ece')}")
