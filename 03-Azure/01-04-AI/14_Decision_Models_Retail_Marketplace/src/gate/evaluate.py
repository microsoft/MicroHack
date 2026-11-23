"""Run the gate's questions over many listings, with a cache and a small number of parallel calls.

Results are cached in `src/runs/cache/`, keyed by model, deployment, evidence, photo and the
exact question wording. Re-running costs nothing; changing one question re-asks only what
changed. Each run is also saved as one JSON Lines file you can report on later.
"""

from __future__ import annotations

import concurrent.futures as cf
import datetime as dt
import hashlib
import json
import threading
from pathlib import Path
from typing import Callable

import config
from gate import clients, evidence
from gate import questions as question_set
from gate.spec import GateCall, Question, spec_signature

CACHE = config.RUNS / "cache"


def deployment(mode: str) -> str:
    return config.DECISION_DEPLOYMENT if mode == "decision" else config.LUNA_DEPLOYMENT


def cache_key(mode: str, row: dict, questions: list[Question], layout: str, photo: bool = True) -> str:
    ev = evidence.build(row, layout)
    blob = json.dumps({
        "mode": mode,
        "endpoint": config.DECISION_ENDPOINT if mode == "decision" else config.OPENAI_ENDPOINT,
        "deployment": deployment(mode),
        "evidence": ev.text(),
        "photo": row.get("image") if photo else None,
        "questions": spec_signature(questions),
    }, sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()[:32]


def ask_one(mode: str, row: dict, questions: list[Question], layout: str = "structured",
            use_cache: bool = True, photo: bool = True) -> tuple[GateCall, bool]:
    """Ask one listing. `photo=False` leaves the photo out, for text-only re-asks: a photo
    counts in full against the rate limit."""
    key = cache_key(mode, row, questions, layout, photo)
    path = CACHE / mode / f"{key}.json"
    if use_cache and path.exists():
        return GateCall.from_dict(json.loads(path.read_text(encoding="utf-8"))), True
    ev = evidence.build(row, layout)
    if not photo:
        ev.photo_b64 = None
    call = clients.ask(mode, ev, questions)
    if not call.error:  # never cache failures
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(call.to_dict()), encoding="utf-8")
    return call, False


def run(mode: str, rows: list[dict], questions: list[Question] | None = None, layout: str = "structured",
        use_cache: bool = True, progress: Callable[[str], None] | None = print,
        photo: bool = True, workers: int | None = None) -> list[GateCall]:
    questions = questions or question_set.active()
    results: list[GateCall | None] = [None] * len(rows)
    done = cached = 0
    lock = threading.Lock()

    def work(i: int) -> None:
        nonlocal done, cached
        call, hit = ask_one(mode, rows[i], questions, layout, use_cache, photo)
        results[i] = call
        with lock:
            done += 1
            cached += hit
            if progress and (done % 10 == 0 or done == len(rows)):
                progress(f"  {mode}: {done}/{len(rows)} listings ({cached} from cache)")

    with cf.ThreadPoolExecutor(max_workers=workers or config.MAX_CONCURRENCY) as pool:
        list(pool.map(work, range(len(rows))))
    return [r for r in results if r is not None]


def changed_questions(head: dict) -> list[Question]:
    """Questions whose wording differs from the ones a saved run was asked with."""
    asked = {q["name"]: q for q in head.get("questions", [])}
    return [q for q in question_set.active() if spec_signature([q])[0] != asked.get(q.name)]


def rescore(base: str | Path, splits: tuple[str, ...] = ("threshold", "test"),
            progress: Callable[[str], None] | None = print) -> Path | None:
    """Re-ask only the questions you changed, on a recorded Microsoft-Decision-1.1 run, and
    keep every other answer. Returns the new run file, or None if nothing changed.

    This is how an improved question in Challenge 2 shows up in your own numbers in Challenges
    3 and 4, without re-running all nine questions on a thousand listings."""
    head, rows, calls = load(base)
    if head["mode"] != "decision":
        raise ValueError("Re-scoring works on Microsoft-Decision-1.1 runs (it is fast enough).")
    changed = changed_questions(head)
    if not changed:
        return None
    keep = [i for i, r in enumerate(rows) if r["split"] in splits]
    rows, calls = [rows[i] for i in keep], [calls[i] for i in keep]
    needs_photo = any(q.requires_photo or q.name == "category" for q in changed)
    fresh = run("decision", rows, questions=changed, progress=progress, photo=needs_photo, workers=6)
    merged = []
    for old, new in zip(calls, fresh):
        call = GateCall.from_dict(old.to_dict())
        call.answers.update({k: v for k, v in new.answers.items() if k in {q.name for q in changed}})
        merged.append(call)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    out = config.RUNS / f"decision-mine-{stamp}.jsonl"
    save(out, "decision", rows, merged, split="+".join(splits), based_on=Path(base).name,
         changed=[q.name for q in changed])
    return out


def rehearsal_run(recorded: Path) -> Path:
    """The run the scorecards use: your newest re-scored run if it was asked with your current
    questions, else the recorded run. The console and `python -m gate launch` both use this."""
    for path in sorted(config.RUNS.glob("decision-mine-*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True):
        with path.open(encoding="utf-8") as f:
            head = json.loads(f.readline())
        if not changed_questions(head):
            return path
    return recorded


def save(path: Path, mode: str, rows: list[dict], calls: list[GateCall], **meta) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    head = {"type": "run", "mode": mode, "deployment": deployment(mode),
            "created": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
            "questions": spec_signature(meta.pop("questions", None) or question_set.active()), **meta}
    with path.open("w", encoding="utf-8") as f:
        f.write(json.dumps(head) + "\n")
        for row, call in zip(rows, calls):
            f.write(json.dumps({"listing_id": row["listing_id"], "call": call.to_dict()}) + "\n")
    return path


def load(path: str | Path) -> tuple[dict, list[dict], list[GateCall]]:
    lines = Path(path).read_text(encoding="utf-8").splitlines()
    head = json.loads(lines[0])
    rows, calls = [], []
    for line in lines[1:]:
        rec = json.loads(line)
        rows.append(evidence.listing(rec["listing_id"]))
        calls.append(GateCall.from_dict(rec["call"]))
    return head, rows, calls
