"""Launch Day console - FastAPI + one static HTML page, no build step.

Run locally from src/:   uv run uvicorn ui.app:app --reload --port 8000
In the lab it runs as an Azure web app with a managed identity (no keys, no sign-in step).

Every button calls the same library as the command line (gate.evaluate, gate.rules, gate.tune,
gate.perturb, gate.judge), so what you see here is exactly what `python -m gate` measures. Each
result also returns the request that was sent and the code behind it ("Show me the code").
"""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import sys
import threading
import time
import uuid
from dataclasses import asdict
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import FileResponse, HTMLResponse, JSONResponse, PlainTextResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import config  # noqa: E402
from gate import clients, evaluate, evidence, launch, metrics, perturb, tune  # noqa: E402
from gate import judge as judging  # noqa: E402
from gate import questions as question_set  # noqa: E402
from gate.questions import FIRST_DRAFT_CLAIMS, QUESTIONS  # noqa: E402
from gate.rules import PIECES, Thresholds, decide  # noqa: E402
from gate.spec import Choice, Option, Score, YesNo, spec_signature  # noqa: E402

app = FastAPI(title="Zava Marketplace - Listing Gate")
STATIC = Path(__file__).parent / "static"
RECORDED = config.DATA / "recorded"
THRESHOLDS_FILE = config.STATE / "thresholds.json"
REVIEWS_FILE = config.STATE / "reviews.json"
QUEUE_FILE = config.STATE / "queue.json"
NOTES_FILE = config.STATE / "notes.json"
EXAMS_FILE = config.STATE / "exams.json"
REDTEAM_FILE = config.STATE / "redteam.json"
GATE_FILE = config.STATE / "gate.json"
ASSUMPTIONS_FILE = config.STATE / "assumptions.json"
_lock = threading.Lock()
_jobs: dict[str, dict[str, Any]] = {}
MODEL_LABELS = {"decision": "Microsoft-Decision-1.1", "luna": "gpt-6-luna Decisions API",
                "llm": "gpt-6-luna Responses API (chat)"}


# --------------------------------------------------------------------------------------------
# Access code (web app only). The lab puts a code on your Hackbox; locally there is none.
# --------------------------------------------------------------------------------------------

def _token() -> str:
    return hashlib.sha256(f"gate:{config.ACCESS_CODE}".encode()).hexdigest()


@app.middleware("http")
async def access_code(request: Request, call_next):
    if not config.ACCESS_CODE or request.url.path in ("/login", "/api/health"):
        return await call_next(request)
    if request.cookies.get("gate_access") == _token():
        return await call_next(request)
    if request.url.path.startswith("/api/"):
        return JSONResponse(status_code=401, content={"error": "Enter your access code first."})
    return RedirectResponse("/login")


LOGIN_PAGE = """<!doctype html><meta charset="utf-8"><title>Launch Day</title>
<style>body{font-family:Segoe UI,system-ui,sans-serif;background:#f4f6fa;display:grid;place-items:center;height:100vh;margin:0}
form{background:#fff;padding:32px 36px;border-radius:12px;box-shadow:0 2px 12px #0001;min-width:320px}
h1{font-size:20px;margin:0 0 6px}p{color:#555;font-size:14px}input{font-size:16px;padding:8px;width:100%;box-sizing:border-box;margin:10px 0}
button{background:#1f5fa8;color:#fff;border:0;padding:10px 16px;border-radius:6px;font-size:15px;cursor:pointer;width:100%}.err{color:#b3261e}</style>
<form method="post" action="/login"><h1>Zava Marketplace &middot; Launch Day</h1>
<p>Enter the <b>AccessCode</b> from your Hackbox.</p>{error}<input name="code" autofocus autocomplete="off">
<button>Open the console</button></form>"""


@app.get("/login", response_class=HTMLResponse)
def login_page() -> str:
    return LOGIN_PAGE.replace("{error}", "")


@app.post("/login")
async def login(request: Request):
    form = await request.body()
    code = dict(p.split("=", 1) for p in form.decode().split("&") if "=" in p).get("code", "")
    from urllib.parse import unquote_plus
    if config.ACCESS_CODE and unquote_plus(code).strip() == config.ACCESS_CODE:
        resp = RedirectResponse("/", status_code=303)
        resp.set_cookie("gate_access", _token(), httponly=True, samesite="lax", secure=request.url.scheme == "https")
        return resp
    return HTMLResponse(LOGIN_PAGE.replace("{error}", '<p class="err">That code is not right.</p>'), status_code=401)


# --------------------------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------------------------

def thresholds() -> Thresholds:
    t = Thresholds.load(THRESHOLDS_FILE if THRESHOLDS_FILE.exists() else None)
    t.pieces = gate_pieces()
    return t


def gate_pieces() -> list[str]:
    """The pieces of the gate you have switched on so far (the gate starts empty)."""
    return _read(GATE_FILE, {"pieces": []})["pieces"]


def assumptions() -> dict:
    return {**launch.ASSUMPTIONS, **_read(ASSUMPTIONS_FILE, {})}


def rehearsal_run() -> str:
    """Your newest re-scored run (your questions) if there is one, else the recorded run."""
    return evaluate.rehearsal_run(RECORDED / "decision-all.jsonl").name


def _read(path: Path, default):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else default


def _write(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=1, ensure_ascii=False), encoding="utf-8")


def public(row: dict) -> dict:
    """A listing without its answer key."""
    return {k: row.get(k) for k in ("listing_id", "split", "seller", "seller_category", "title",
                                    "description", "price_eur", "image", "gtin", "starter")}


def guarded(fn):
    try:
        return fn()
    except RuntimeError as exc:  # configuration problems: show the fix
        return JSONResponse(status_code=400, content={"error": str(exc)})


def code_for(mode: str, row_or_ev, questions) -> dict:
    """'Show me the code': the exact request, a minimal script that sends it, and the files."""
    ev = row_or_ev if isinstance(row_or_ev, evidence.Evidence) else evidence.build(row_or_ev)
    req = clients.request_preview(mode, ev, questions)
    if mode == "decision":
        snippet = (
            "import httpx\nfrom azure.identity import DefaultAzureCredential\n\n"
            "token = DefaultAzureCredential().get_token(\"https://cognitiveservices.azure.com/.default\").token\n"
            f"r = httpx.post(\"{req['url']}\",\n"
            "               headers={\"Authorization\": f\"Bearer {token}\"},\n"
            "               json=body)  # body = the request shown above\n"
            "answers = r.json()[\"answers\"]   # keyed by question name, e.g. answers[\"prohibited_item\"][\"noul\"]")
        files = ["gate/clients.py → ask_decision()", "gate/evidence.py → build()", "gate/questions.py"]
    elif mode == "luna":
        snippet = (
            "from openai import OpenAI\nfrom azure.identity import DefaultAzureCredential, get_bearer_token_provider\n\n"
            "token = get_bearer_token_provider(DefaultAzureCredential(), \"https://cognitiveservices.azure.com/.default\")\n"
            f"client = OpenAI(base_url=\"{config.OPENAI_ENDPOINT}/openai/v1/\", api_key=token)\n"
            "resp = client.decisions.create(**body)   # body = the request shown above\n"
            "for a in resp.answers:                     # one answer per question, in order\n"
            "    print(a.name, a.type)")
        files = ["gate/clients.py → ask_luna()", "gate/evidence.py → build()", "gate/questions.py"]
    else:
        snippet = (
            "from openai import OpenAI\nfrom azure.identity import DefaultAzureCredential, get_bearer_token_provider\n\n"
            "token = get_bearer_token_provider(DefaultAzureCredential(), \"https://cognitiveservices.azure.com/.default\")\n"
            f"client = OpenAI(base_url=\"{config.OPENAI_ENDPOINT}/openai/v1/\", api_key=token)\n"
            "resp = client.responses.create(**body)   # body = the request shown above\n"
            "answers = json.loads(resp.output_text)    # true/false and labels - no probabilities")
        files = ["gate/clients.py → ask_llm()", "gate/evidence.py → build()"]
    return {"request": req, "python": snippet, "files": files}


def _job(kind: str, work) -> str:
    job_id = uuid.uuid4().hex[:8]
    _jobs[job_id] = {"kind": kind, "status": "running", "progress": "starting...", "started": time.time()}

    def progress(msg: str) -> None:
        _jobs[job_id]["progress"] = msg.strip()

    def runner():
        try:
            _jobs[job_id].update(status="done", result=work(progress), seconds=round(time.time() - _jobs[job_id]["started"]))
        except Exception as exc:  # noqa: BLE001 - surface to the page
            _jobs[job_id].update(status="error", error=f"{type(exc).__name__}: {exc}")

    threading.Thread(target=runner, daemon=True).start()
    return job_id


def _run_file(name: str) -> Path:
    for folder in (RECORDED, config.RUNS):
        p = folder / name
        if p.exists() and p.suffix == ".jsonl" and p.parent in (RECORDED, config.RUNS):
            return p
    raise HTTPException(404, f"No run called {name!r}")


def _split(rows, calls, split: str):
    if split == "all":
        return rows, calls
    keep = [i for i, r in enumerate(rows) if r["split"] == split]
    return [rows[i] for i in keep], [calls[i] for i in keep]


def _slim(rep: dict) -> dict:
    if rep.get("gate"):
        rep["gate"].pop("confusion", None)
    return rep


# --------------------------------------------------------------------------------------------
# Status, config, listings
# --------------------------------------------------------------------------------------------

_status_cache: dict[str, Any] = {}


@app.get("/api/health")
def health() -> dict:
    """Used by the lab automation: the app is up AND its identity can call Microsoft-Decision-1.1."""
    try:
        q = [YesNo(name="ok", instructions="Is this a garden product?")]
        call = clients.ask("decision", evidence.Evidence(state="Garden hose 25 m", photo_b64=None), q)
        ok = not call.error and call.answers["ok"].status == "ok"
        return {"ok": ok, "detail": call.error}
    except Exception as exc:  # noqa: BLE001
        return JSONResponse(status_code=503, content={"ok": False, "detail": str(exc)})


@app.get("/api/status")
def status(refresh: bool = False) -> dict:
    """One quick call per model, for the lights in the header."""
    if not refresh and _status_cache.get("at", 0) > time.time() - 300:
        return _status_cache["data"]
    q = [YesNo(name="ok", instructions="Is this a garden product?")]
    ev = evidence.Evidence(state={"seller_listing": {"title": "Garden hose 25 m"}}, photo_b64=None)
    out = {}
    for mode in clients.MODES:
        try:
            call = clients.ask(mode, ev, q)
            a = call.answers.get("ok")
            out[mode] = {"ok": not call.error and a is not None and a.status == "ok", "label": MODEL_LABELS[mode],
                         "ms": round(call.latency_ms or 0), "detail": call.error}
        except Exception as exc:  # noqa: BLE001
            out[mode] = {"ok": False, "label": MODEL_LABELS[mode], "detail": str(exc)[:300]}
    _status_cache.update(at=time.time(), data=out)
    return out


@app.get("/api/config")
def get_config() -> dict:
    return {"decision_endpoint": config.DECISION_ENDPOINT, "openai_endpoint": config.OPENAI_ENDPOINT,
            "decision_deployment": config.DECISION_DEPLOYMENT, "luna_deployment": config.LUNA_DEPLOYMENT,
            "judge_deployment": config.JUDGE_DEPLOYMENT, "project_endpoint": config.PROJECT_ENDPOINT,
            "thresholds": asdict(thresholds()), "thresholds_file": THRESHOLDS_FILE.exists(),
            "questions": spec_signature(question_set.active()), "edited": sorted(question_set.overrides()),
            "categories": [o.value for o in QUESTIONS[0].options if o.value != "cannot_tell"],
            "images": sorted(p.name for p in (config.DATA / "images").glob("*.jpg")),
            "products": [{"gtin": p["gtin"], "name": f"{p['brand']} {p['name']}", "category": p["category"],
                          "reference_price_eur": p["reference_price_eur"], "image": f"{p['product_id']}.jpg"}
                         for p in evidence.catalogue()["products"]]}


@app.get("/api/listings")
def listings(split: str = "dev", starter: bool = True) -> list[dict]:
    return [public(r) for r in evidence.select(split=split, starter=starter)]


@app.get("/api/listings/{listing_id}")
def one_listing(listing_id: str, answer: bool = False) -> dict:
    try:
        row = evidence.listing(listing_id)
    except KeyError as exc:
        raise HTTPException(404, str(exc)) from exc
    out = public(row)
    product = evidence.products_by_gtin().get(row.get("gtin") or "")
    out["manufacturer_facts"] = product["facts"] if product else None
    out["reference_price_eur"] = product["reference_price_eur"] if product else None
    if answer:
        out["answer_key"] = {"expected": row["expected"], "labels": row["labels"], "construction": row["construction"]}
    return out


# --------------------------------------------------------------------------------------------
# Challenge 1: ask the gate's questions, or your own
# --------------------------------------------------------------------------------------------

class AskRequest(BaseModel):
    listing_id: str
    model: str = "decision"
    layout: str = "structured"


@app.post("/api/ask")
def ask(req: AskRequest) -> Any:
    def run():
        row = evidence.listing(req.listing_id)
        qs = question_set.active()
        started = time.perf_counter()
        call, cached = evaluate.ask_one(req.model, row, qs, layout=req.layout)
        t = thresholds()
        d = decide(row, call, t)
        full = Thresholds(**{**asdict(t), "pieces": None})
        return {"call": call.to_dict(), "cached": cached, "decision": d.to_dict(),
                "decision_full_gate": decide(row, call, full).to_dict(),
                "elapsed_ms": round((time.perf_counter() - started) * 1000),
                "code": code_for(req.model, evidence.build(row, req.layout), qs)}
    return guarded(run)


class CustomQuestion(BaseModel):
    listing_id: str
    model: str = "decision"
    kind: str = "yes_no"  # yes_no | choice | score
    instructions: str
    options: list[str] = []


@app.post("/api/custom")
def custom(req: CustomQuestion) -> Any:
    """Ask your own question about a listing and see the typed answer."""
    def run():
        if req.model not in ("decision", "luna"):
            raise RuntimeError("Custom questions go to a decision model: choose Microsoft-Decision-1.1 or gpt-6-luna.")
        opts = tuple(Option(o.strip(), o.strip()) for o in req.options if o.strip())
        if req.kind == "yes_no":
            q = YesNo(name="my_question", instructions=req.instructions)
        elif req.kind == "choice":
            if len(opts) < 2:
                raise RuntimeError("A choice question needs at least two options.")
            q = Choice(name="my_question", instructions=req.instructions, options=opts)
        else:
            if len(opts) < 2:
                raise RuntimeError("A score question needs at least two levels, lowest first.")
            q = Score(name="my_question", instructions=req.instructions, levels=opts)
        ev = evidence.build(evidence.listing(req.listing_id))
        call = clients.ask(req.model, ev, [q])
        return {"call": call.to_dict(), "code": code_for(req.model, ev, [q])}
    return guarded(run)


# --------------------------------------------------------------------------------------------
# Challenge 2: the gate's questions
# --------------------------------------------------------------------------------------------

@app.get("/api/questions")
def get_questions() -> dict:
    edited = question_set.overrides()
    out = []
    for q, sig in zip(QUESTIONS, spec_signature(QUESTIONS)):
        out.append({**sig, "original": q.instructions, "current": edited.get(q.name, q.instructions),
                    "edited": q.name in edited})
    return {"questions": out, "first_draft": spec_signature([FIRST_DRAFT_CLAIMS])[0]}


class Wording(BaseModel):
    instructions: str


@app.put("/api/questions/{name}")
def put_question(name: str, w: Wording) -> dict:
    if not w.instructions.strip():
        raise HTTPException(400, "The question can't be empty.")
    try:
        question_set.save_override(name, w.instructions)
    except KeyError as exc:
        raise HTTPException(404, f"No question {name!r}") from exc
    return get_questions()


@app.delete("/api/questions/{name}")
def reset_question(name: str) -> dict:
    question_set.reset(None if name == "all" else name)
    return get_questions()


class EvalRequest(BaseModel):
    model: str = "decision"
    draft: bool = False          # ask the first-draft claims question instead of the two yes/no ones
    compare_original: bool = True  # also score the original wording, for a before/after view


@app.post("/api/jobs/evaluate")
def job_evaluate(req: EvalRequest) -> dict:
    """Run the gate on the 24-listing starter set and score it against the answer key."""
    rows = evidence.select(split="dev", starter=True)

    def work(progress):
        qs = metrics.draft_questions() if req.draft else question_set.active()
        calls = evaluate.run(req.model, rows, questions=qs, progress=progress)
        full = thresholds()
        full.pieces = None  # compare question wordings on the whole gate
        rep = metrics.report(req.model, rows, calls, full, questions=qs if req.draft else None)
        listing_rows = [{"listing_id": r["listing_id"], "title": r["title"], "expected": r["expected"]["outcome"],
                         "answers": c.to_dict()["answers"],
                         "outcome": decide(r, c, full).outcome if not req.draft else None,
                         "labels": r["labels"]} for r, c in zip(rows, calls)]
        out = {"report": _slim(rep), "listings": listing_rows, "draft": req.draft,
               "edited": sorted(question_set.overrides())}
        if req.compare_original and not req.draft and question_set.overrides():
            progress("scoring the original wording for comparison...")
            base_calls = evaluate.run(req.model, rows, questions=QUESTIONS, progress=progress)
            out["original"] = _slim(metrics.report(req.model, rows, base_calls, full))
            out["original_outcomes"] = {r["listing_id"]: decide(r, c, full).outcome
                                        for r, c in zip(rows, base_calls)}
        stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
        tag = "-draft" if req.draft else ""
        evaluate.save(config.RUNS / f"{req.model}{tag}-starter-{stamp}.jsonl", req.model, rows, calls,
                      split="starter", draft=req.draft, questions=qs)
        return out
    return {"job": _job("evaluate", work), "total": len(rows)}


@app.post("/api/jobs/rescore")
def job_rescore() -> dict:
    """Carry your edited questions into the full threshold and test splits (Challenges 3-4)."""
    def work(progress):
        path = evaluate.rescore(RECORDED / "decision-all.jsonl", progress=progress)
        if path is None:
            return {"message": "Your questions match the recorded run, so there is nothing to re-score.", "run": None}
        head, _, _ = evaluate.load(path)
        return {"run": path.name, "changed": head.get("changed", [])}
    return {"job": _job("rescore", work)}


@app.get("/api/jobs/{job_id}")
def job_status(job_id: str) -> dict:
    if job_id not in _jobs:
        raise HTTPException(404, "unknown job")
    return _jobs[job_id]


# --------------------------------------------------------------------------------------------
# Challenge 3: compare runs
# --------------------------------------------------------------------------------------------

@app.get("/api/runs")
def runs() -> list[dict]:
    out = []
    for folder, recorded in ((RECORDED, True), (config.RUNS, False)):
        for f in sorted(folder.glob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=not recorded):
            if f.name.startswith("judge-"):
                continue
            head = json.loads(f.open(encoding="utf-8").readline())
            out.append({"name": f.name, "recorded": recorded, "mode": head.get("mode"), "split": head.get("split"),
                        "draft": bool(head.get("draft")), "changed": head.get("changed", []),
                        "label": MODEL_LABELS.get(head.get("mode"), head.get("mode"))})
    return out


@app.get("/api/compare")
def compare(runs: str, split: str = "test", calibration: bool = True) -> dict:
    t = thresholds()
    t.pieces = None  # compare models on the whole gate
    out = []
    for name in [r for r in runs.split(",") if r]:
        head, rows, calls = evaluate.load(_run_file(name))
        rows, calls = _split(rows, calls, split)
        if not rows:
            continue
        rep = _slim(metrics.report(head["mode"], rows, calls, t, questions=metrics.questions_for(head)))
        if not calibration:
            for m in rep["questions"].values():
                m.get("calibration", {}).pop("table", None)
        out.append({"name": name, "label": MODEL_LABELS.get(head["mode"], head["mode"]), **rep})
    return {"split": split, "reports": out}


# --------------------------------------------------------------------------------------------
# Launch Day: the pieces of the gate, the rehearsal and the business scorecard
# --------------------------------------------------------------------------------------------

def _scorecard(split: str = "threshold", t: Thresholds | None = None, run: str | None = None) -> dict:
    run = run or rehearsal_run()
    head, rows, calls = evaluate.load(_run_file(run))
    rows, calls = _split(rows, calls, split)
    card = launch.scorecard(head["mode"], rows, calls, t or thresholds(), assumptions())
    card["run"] = run
    card["split"] = split
    return card


@app.get("/api/launch")
def launch_status() -> dict:
    """The rehearsal: last week's listings (the threshold split) through the gate as you've built it."""
    return {"pieces": gate_pieces(), "piece_info": PIECES, "tuned": THRESHOLDS_FILE.exists(),
            "questions_edited": list(question_set.overrides()), "scorecard": _scorecard(),
            "by_hand": launch.check_everything_by_hand(assumptions()),
            "empty": _scorecard(t=Thresholds(pieces=[])),
            "monday_opened": _read(EXAMS_FILE, {"count": 0})["count"]}


class Pieces(BaseModel):
    pieces: list[str]


@app.put("/api/launch/pieces")
def set_pieces(p: Pieces) -> dict:
    unknown = set(p.pieces) - set(PIECES)
    if unknown:
        raise HTTPException(400, f"Unknown gate pieces: {', '.join(sorted(unknown))}")
    before = _scorecard()
    with _lock:
        _write(GATE_FILE, {"pieces": [k for k in PIECES if k in p.pieces]})
    return {"pieces": gate_pieces(), "before": before, "after": _scorecard()}


@app.put("/api/launch/assumptions")
def set_assumptions(a: dict) -> dict:
    keep = {k: float(v) for k, v in a.items() if k in launch.ASSUMPTIONS}
    with _lock:
        _write(ASSUMPTIONS_FILE, keep)
    return {"assumptions": assumptions(), "scorecard": _scorecard()}


@app.delete("/api/launch")
def restart_weekend() -> dict:
    """Start again: an empty gate, original questions, default thresholds (keeps your notes)."""
    with _lock:
        for f in (GATE_FILE, THRESHOLDS_FILE, EXAMS_FILE, QUEUE_FILE, REVIEWS_FILE):
            f.unlink(missing_ok=True)
        for f in config.RUNS.glob("decision-mine-*.jsonl"):
            f.unlink()
        question_set.reset()
    return launch_status()


# --------------------------------------------------------------------------------------------
# Challenge 4: thresholds, the test split, the reviewer queue
# --------------------------------------------------------------------------------------------

@app.get("/api/costs")
def default_costs() -> dict:
    return tune.COSTS


class TuneRequest(BaseModel):
    run: str | None = None
    costs: dict[str, dict] | None = None


@app.post("/api/tune")
def do_tune(req: TuneRequest) -> dict:
    """Choose thresholds on the THRESHOLD split only. The test split stays closed."""
    run = req.run or rehearsal_run()
    head, rows, calls = evaluate.load(_run_file(run))
    if head["mode"] == "llm":
        raise HTTPException(400, "The chat model returns no probabilities, so there is nothing to tune.")
    costs = {**tune.COSTS, **{k: {**tune.COSTS.get(k, {}), **v} for k, v in (req.costs or {}).items()}}
    tr_rows, tr_calls = _split(rows, calls, "threshold")
    t, detail = tune.tune(tr_rows, tr_calls, costs)
    t.pieces = gate_pieces()
    default = Thresholds(pieces=gate_pieces())
    before = _slim(metrics.report(head["mode"], tr_rows, tr_calls, default))["gate"]
    after = _slim(metrics.report(head["mode"], tr_rows, tr_calls, t))["gate"]
    return {"thresholds": asdict(t), "detail": detail, "default_on_threshold_split": before,
            "tuned_on_threshold_split": after, "run": run,
            "scorecard_default": _scorecard(t=default, run=run), "scorecard_tuned": _scorecard(t=t, run=run)}


class ApplyThresholds(BaseModel):
    thresholds: dict


class GateRequest(BaseModel):
    run: str | None = None
    thresholds: dict


@app.post("/api/gate")
def gate_with(req: GateRequest) -> dict:
    """The gate on the threshold split with thresholds you set by hand - for the sliders."""
    run = req.run or rehearsal_run()
    head, rows, calls = evaluate.load(_run_file(run))
    rows, calls = _split(rows, calls, "threshold")
    t = Thresholds(**{k: v for k, v in req.thresholds.items() if k != "pieces"}, pieces=gate_pieces())
    return {"gate": _slim(metrics.report(head["mode"], rows, calls, t))["gate"], "scorecard": _scorecard(t=t, run=run)}


@app.post("/api/thresholds")
def apply_thresholds(req: ApplyThresholds) -> dict:
    Thresholds(**{k: v for k, v in req.thresholds.items() if k != "pieces"}).save(THRESHOLDS_FILE)
    return {"thresholds": asdict(thresholds()), "thresholds_file": True}


@app.delete("/api/thresholds")
def reset_thresholds() -> dict:
    THRESHOLDS_FILE.unlink(missing_ok=True)
    return {"thresholds": asdict(thresholds()), "thresholds_file": False}


class ExamRequest(BaseModel):
    run: str | None = None


@app.post("/api/exam")
def final_exam(req: ExamRequest) -> dict:
    """Monday morning: open the test split with the gate you built. Every opening is counted: a
    test set you look at again and again stops telling you how the gate will do on new listings."""
    run = req.run or rehearsal_run()
    head, rows, calls = evaluate.load(_run_file(run))
    rows, calls = _split(rows, calls, "test")
    with _lock:
        exams = _read(EXAMS_FILE, {"count": 0, "history": []})
        exams["count"] += 1
        rep = _slim(metrics.report(head["mode"], rows, calls, thresholds()))
        card = _scorecard("test", run=run)
        exams["history"].append({"at": dt.datetime.now().isoformat(timespec="seconds"), "run": run,
                                 "tuned": THRESHOLDS_FILE.exists(), "pieces": gate_pieces(),
                                 "gate": rep["gate"], "scorecard": card})
        _write(EXAMS_FILE, exams)
    return {"opened": exams["count"], "report": rep, "scorecard": card, "tuned": THRESHOLDS_FILE.exists()}


class BatchRequest(BaseModel):
    model: str = "decision"


@app.post("/api/jobs/queue")
def job_queue(req: BatchRequest) -> dict:
    """Run the gate over the starter set and fill the reviewer queue."""
    rows = evidence.select(split="dev", starter=True)

    def work(progress):
        calls = evaluate.run(req.model, rows, progress=progress)
        t = thresholds()
        queue, outcomes = [], {}
        for row, call in zip(rows, calls):
            d = decide(row, call, t)
            outcomes[d.outcome] = outcomes.get(d.outcome, 0) + 1
            if d.outcome == "review":
                queue.append({"listing_id": row["listing_id"], "title": row["title"], "model": req.model,
                              "reasons": [r["message"] for r in d.to_dict()["reasons"]]})
        with _lock:
            _write(QUEUE_FILE, queue)
            _write(REVIEWS_FILE, {})
        return {"outcomes": outcomes, "queue": len(queue)}
    return {"job": _job("queue", work)}


@app.get("/api/queue")
def queue() -> dict:
    return {"queue": _read(QUEUE_FILE, []), "reviews": _read(REVIEWS_FILE, {})}


class Verdict(BaseModel):
    verdict: str  # publish | auto_fix | reject  (policy section 10: what a reviewer decides)
    note: str = ""


def reviewer_answer(row: dict) -> str:
    """What a reviewer should decide (policy section 10): publish what the gate was only unsure
    about, fix a wrong category, and send everything else back to the seller."""
    exp = row["expected"]["outcome"]
    return exp if exp in ("publish", "auto_fix") else "reject"


@app.post("/api/queue/{listing_id}")
def review(listing_id: str, v: Verdict) -> dict:
    if v.verdict not in ("publish", "auto_fix", "reject"):
        raise HTTPException(400, "Choose publish, auto_fix (fix the category) or reject (send back to the seller).")
    with _lock:
        reviews = _read(REVIEWS_FILE, {})
        row = evidence.listing(listing_id)
        right = reviewer_answer(row)
        reviews[listing_id] = {"verdict": v.verdict, "note": v.note, "answer_key": right,
                               "correct": v.verdict == right, "why": row["expected"]["reasons"],
                               "right_category": row["labels"].get("category")}
        _write(REVIEWS_FILE, reviews)
    return reviews[listing_id]


# --------------------------------------------------------------------------------------------
# Challenge 5: break the gate
# --------------------------------------------------------------------------------------------

class RobustnessRequest(BaseModel):
    kind: str  # shuffle | paraphrase | layout | injection | repeat
    model: str = "decision"
    limit: int | None = None


@app.post("/api/jobs/robustness")
def job_robustness(req: RobustnessRequest) -> dict:
    rows = evidence.select(split="dev", starter=True, limit=req.limit)

    def work(progress):
        t = thresholds()
        t.pieces = None  # stress-test the whole gate
        return perturb.run(req.kind, req.model, rows, t)
    return {"job": _job("robustness", work)}


class SellRequest(BaseModel):
    title: str
    description: str
    seller_category: str
    price_eur: float
    image: str | None = None
    gtin: str | None = None
    goal: str = "other"  # what the attendee tried to sneak past the gate


GOALS = {"prohibited": "a prohibited item", "contact": "off-platform contact", "note": "a note aimed at the gate",
         "claim": "a false or invented claim", "other": "something else"}


@app.post("/api/sell")
def sell(req: SellRequest) -> Any:
    """Red team: submit your own listing and see what the gate does."""
    def run():
        if req.image and req.image not in {p.name for p in (config.DATA / "images").glob("*.jpg")}:
            raise RuntimeError("Pick one of the photos in the list.")
        if req.gtin and req.gtin not in evidence.products_by_gtin():
            raise RuntimeError("Pick a product from the catalogue, or leave the GTIN empty.")
        row = {"listing_id": "MY-LISTING", "split": "mine", "seller": "you", "title": req.title.strip(),
               "description": req.description.strip(), "seller_category": req.seller_category,
               "price_eur": req.price_eur, "image": req.image or None, "gtin": req.gtin or None}
        qs = question_set.active()
        call, _ = evaluate.ask_one("decision", row, qs)
        d = decide(row, call, thresholds())
        got_through = d.outcome in ("publish", "auto_fix") and req.goal != "other"
        with _lock:
            log = _read(REDTEAM_FILE, [])
            log.append({"at": dt.datetime.now().isoformat(timespec="seconds"), "goal": req.goal,
                        "title": req.title[:80], "outcome": d.outcome, "got_through": got_through})
            _write(REDTEAM_FILE, log)
        return {"call": call.to_dict(), "decision": d.to_dict(), "got_through": got_through,
                "goal": GOALS.get(req.goal, req.goal), "scoreboard": _scoreboard(log),
                "code": code_for("decision", row, qs)}
    return guarded(run)


def _scoreboard(log: list[dict]) -> dict:
    tries = [x for x in log if x["goal"] != "other"]
    return {"attempts": len(tries), "caught": sum(not x["got_through"] for x in tries),
            "got_through": sum(x["got_through"] for x in tries), "recent": log[-8:][::-1]}


@app.get("/api/sell/scoreboard")
def scoreboard() -> dict:
    return _scoreboard(_read(REDTEAM_FILE, []))


# --------------------------------------------------------------------------------------------
# Challenge 6: generate, then judge
# --------------------------------------------------------------------------------------------

def _weak_listings() -> list[dict]:
    return [r for r in evidence.listings() if r["split"] == "dev" and r["construction"] == ["poor_quality"] and r.get("gtin")]


@app.get("/api/judge/listings")
def judge_listings() -> list[dict]:
    return [public(r) for r in _weak_listings()[:8]]


@app.get("/api/judge/presets/{listing_id}")
def judge_presets(listing_id: str) -> dict:
    row = evidence.listing(listing_id)
    product = evidence.products_by_gtin().get(row.get("gtin") or "")
    if not product:
        raise HTTPException(400, "This listing has no manufacturer facts to judge against.")
    return {"faithful": judging.faithful_rewrite(product), **judging.bad_rewrites(product),
            "facts": judging.facts_text(product)}


class JudgeRequest(BaseModel):
    listing_id: str
    mode: str = "ai"  # ai | ai_tempt | own
    title: str = ""
    description: str = ""


@app.post("/api/judge")
def do_judge(req: JudgeRequest) -> Any:
    def run():
        row = evidence.listing(req.listing_id)
        if not evidence.products_by_gtin().get(row.get("gtin") or ""):
            raise RuntimeError("This listing has no manufacturer facts to judge against.")
        if req.mode in ("ai", "ai_tempt"):
            new = judging.rewrite(row, tempt=req.mode == "ai_tempt")
        else:
            if not req.title.strip():
                raise RuntimeError("Write a title for your rewrite.")
            new = {"title": req.title.strip(), "description": req.description.strip()}
        result = judging.judge_one(row, new)
        result["judge_deployment"] = config.JUDGE_DEPLOYMENT
        result["code"] = {"python": (
            "from azure.ai.evaluation import GroundednessEvaluator\n"
            "from azure.identity import DefaultAzureCredential\n\n"
            f"judge = {{\"type\": \"decision\", \"azure_endpoint\": \"{config.DECISION_ENDPOINT}\",\n"
            f"         \"azure_deployment\": \"{config.JUDGE_DEPLOYMENT}\"}}\n"
            "groundedness = GroundednessEvaluator(model_config=judge, credential=DefaultAzureCredential())\n"
            "result = groundedness(query=..., context=manufacturer_facts, response=rewrite)\n"
            "print(result[\"groundedness\"], result[\"groundedness_properties\"][\"decision_model\"][\"probabilities\"])"),
            "files": ["gate/judge.py → judge_one(), groundedness_judge()", "gate/judge.py → rewrite()"]}
        return result
    return guarded(run)


# --------------------------------------------------------------------------------------------
# Decision Design Cards and the launch report
# --------------------------------------------------------------------------------------------

class Note(BaseModel):
    """A Decision Design Card: one decision in your own work, designed the way you built the gate."""
    challenge: str
    use_case: str = ""        # the decision in my work
    question: str = ""        # the closed question I'd ask
    kind: str = ""            # yes/no, choice or score
    wrong_yes: str = ""       # what a wrong "yes" would cost
    wrong_no: str = ""        # what a wrong "no" would cost
    unsure: str = ""          # who decides when the model is unsure
    mistake_cost: str = ""    # older cards


@app.get("/api/notes")
def notes() -> dict:
    return _read(NOTES_FILE, {})


@app.put("/api/notes")
def save_note(n: Note) -> dict:
    with _lock:
        data = _read(NOTES_FILE, {})
        data[n.challenge] = n.model_dump(exclude={"challenge"})
        _write(NOTES_FILE, data)
    return data


def _card_lines(card: dict) -> list[str]:
    return [f"| Live within a minute | {card['live_fast_pct']}% |",
            f"| Bad listings live (per 10,000) | {card['bad_live_per_10k']} |",
            f"| In the wrong aisle (per 10,000) | {card['wrong_aisle_per_10k']} |",
            f"| Reviewer hours per day | {card['reviewer_hours_per_day']} |",
            f"| Cost per day (reviewers + AI) | €{card['cost_per_day_eur']:,} |"]


@app.get("/api/summary", response_class=PlainTextResponse)
def summary() -> str:
    """My launch report: the gate I built, its numbers, and the decisions I'd automate at work."""
    a = assumptions()
    lines = ["# My launch report — Zava Listing Gate", "",
             f"_Exported {dt.date.today().isoformat()} from the Zava Launch Day console._", "",
             "## The gate I built", ""]
    on = gate_pieces()
    for k, label in PIECES.items():
        lines.append(f"- {'✅' if k in on else '⬜'} {label}")
    lines += [f"- {'✅' if THRESHOLDS_FILE.exists() else '⬜'} Go-live dial: thresholds chosen from what each mistake costs", ""]
    lines += ["## Launch scorecard", "",
              f"_Assumptions: {int(a['listings_per_day']):,} listings a day, {a['minutes_per_review']:g} minutes per review, "
              f"€{a['eur_per_reviewer_hour']:g} per reviewer hour._", "",
              "| | Rehearsal (last week's listings) |", "|---|---:|", *_card_lines(_scorecard()), ""]
    by_hand = launch.check_everything_by_hand(a)
    lines += [f"Checking everything by hand would take **{by_hand['reviewer_hours_per_day']} reviewer hours** and "
              f"**€{by_hand['cost_per_day_eur']:,}** a day.", ""]
    exams = _read(EXAMS_FILE, {}).get("history", [])
    if exams and exams[-1].get("scorecard"):
        lines += ["### Monday morning (new listings, opened once)", "", "| | Monday |", "|---|---:|",
                  *_card_lines(exams[-1]["scorecard"]), "",
                  f"Unsafe rate among auto-published listings could still be up to "
                  f"{exams[-1]['gate']['unsafe_rate_upper_95']:.1%} (95% upper bound). Opened {len(exams)} time(s).", ""]
    edited = question_set.overrides()
    if edited:
        lines += ["## Questions I improved", ""]
        for name, text in edited.items():
            lines += [f"- **{name}**: {text}"]
        lines.append("")
    cards = [(ch, n) for ch, n in sorted(_read(NOTES_FILE, {}).items()) if any(n.values())]
    if cards:
        lines += ["## Decisions I would automate at work", ""]
        for ch, n in cards:
            lines += [f"### {n.get('use_case') or ch}", "",
                      f"- **Closed question:** {n.get('question', '')}",
                      f"- **Type:** {n.get('kind', '')}",
                      f"- **A wrong yes costs:** {n.get('wrong_yes') or n.get('mistake_cost', '')}",
                      f"- **A wrong no costs:** {n.get('wrong_no', '')}",
                      f"- **When it's unsure:** {n.get('unsure', '')}", f"- _From {ch}_", ""]
    board = _scoreboard(_read(REDTEAM_FILE, []))
    if board["attempts"]:
        lines += ["## Sellers strike back", "", f"- {board['attempts']} attempts, {board['caught']} caught, "
                  f"{board['got_through']} got through", ""]
    lines += ["## The pattern to take home", "",
              "1. **Find the decision** — a small, frequent call people make today.",
              "2. **Ask closed questions** — yes/no, choice or score; one idea per question; exact maths in code.",
              "3. **Set the line from costs** — what does a wrong yes cost, and a wrong no?",
              "4. **Keep a person for the middle** — the model's unsure answers go to someone who decides.",
              "5. **Measure on data you didn't tune on** — and say how bad it could still be.", "",
              "## Learn more", "",
              "- Decision models primer: https://github.com/microsoft-foundry/model-releases/blob/main/3-primers/decision-models.md",
              "- Microsoft-Decision-1.1: https://learn.microsoft.com/azure/foundry/foundry-models/how-to/use-foundry-models-microsoft-decision",
              "- Azure OpenAI Decisions API: https://learn.microsoft.com/azure/foundry/openai/how-to/decisions",
              "- Use a decision model as an evaluation judge: https://learn.microsoft.com/azure/foundry/observability/how-to/decision-model-judge",
              "- No code: decision actions in Azure Logic Apps (preview): https://techcommunity.microsoft.com/blog/integrationsonazureblog/announcing-decision-apis-as-actions-in-azure-logic-apps/4573643", ""]
    return "\n".join(lines)


# --------------------------------------------------------------------------------------------
# Pages
# --------------------------------------------------------------------------------------------

@app.get("/")
def index() -> FileResponse:
    return FileResponse(STATIC / "index.html")


@app.get("/policy", response_class=HTMLResponse)
def policy() -> str:
    md = (config.DATA / "policy.md").read_text(encoding="utf-8")
    return POLICY_PAGE.replace("{body}", markdown_to_html(md))


POLICY_PAGE = """<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Zava Marketplace — Listing Policy</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{font:15px/1.6 "Segoe UI",system-ui,sans-serif;color:#1d2430;background:#f4f6fa;margin:0}
main{max-width:860px;margin:24px auto;background:#fff;border:1px solid #dde3ea;border-radius:12px;padding:20px 32px 32px}
h1{font-size:24px;color:#1f5fa8} h2{font-size:18px;margin-top:28px;border-top:1px solid #eef1f5;padding-top:16px}
table{border-collapse:collapse;width:100%;margin:10px 0} th,td{text-align:left;padding:6px 9px;border-bottom:1px solid #dde3ea;vertical-align:top}
th{font-size:13px;color:#5f6b7a} code{background:#eef1f5;border-radius:4px;padding:1px 5px;font-size:13px} li{margin:4px 0}</style></head>
<body><main>{body}</main></body></html>"""


def markdown_to_html(md: str) -> str:
    """Just enough Markdown for policy.md: headings, paragraphs, lists, tables, **bold**, `code`."""
    import html
    import re

    def inline(s: str) -> str:
        s = html.escape(s, quote=False)
        s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
        return re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", s)

    out, para, items, rows = [], [], [], []

    def flush():
        if para:
            out.append(f"<p>{inline(' '.join(para))}</p>"); para.clear()
        if items:
            out.append("<ul>" + "".join(f"<li>{inline(i)}</li>" for i in items) + "</ul>"); items.clear()
        if rows:
            cells = [[c.strip() for c in r.strip().strip("|").split("|")] for r in rows if not re.match(r"^\|[\s:|-]+\|$", r.strip())]
            head, body = cells[0], cells[1:]
            out.append("<table><tr>" + "".join(f"<th>{inline(c)}</th>" for c in head) + "</tr>" +
                       "".join("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>" for r in body) + "</table>")
            rows.clear()

    for line in md.splitlines():
        s = line.strip()
        if not s:
            flush()
        elif s.startswith("#"):
            flush(); level = len(s) - len(s.lstrip("#"))
            out.append(f"<h{level}>{inline(s[level:].strip())}</h{level}>")
        elif s.startswith("|"):
            if para or items:
                flush()
            rows.append(s)
        elif s.startswith("- "):
            if para or rows:
                flush()
            items.append(s[2:])
        elif items and line.startswith("  "):
            items[-1] += " " + s
        else:
            para.append(s)
    flush()
    return "\n".join(out)


app.mount("/images", StaticFiles(directory=config.DATA / "images"), name="images")
app.mount("/static", StaticFiles(directory=STATIC), name="static")


def _warm_up() -> None:
    """Load the recorded runs once at start-up, so the first page load is quick."""
    try:
        launch_status()
    except Exception:  # noqa: BLE001 - only a warm-up
        pass


threading.Thread(target=_warm_up, daemon=True).start()
