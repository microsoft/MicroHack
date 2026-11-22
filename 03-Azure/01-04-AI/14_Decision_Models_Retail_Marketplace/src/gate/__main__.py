"""Listing Gate command line. Run from src/:  uv run python -m gate <command> --help

  check        Sign-in and both decision APIs answer (run this first)
  ask          Ask every gate question about one listing and show the decision
  evaluate     Run a model over many listings and save the run
  report       Score a saved run (yours or a recorded one) against the answer key
  compare      Side-by-side table of several saved runs
  rescore      Re-ask only the questions you changed, on the threshold and test splits
  tune         Choose thresholds on the threshold split, then test them once on the test split
  launch       The launch scorecard for a gate, the same as the console's
  robustness   Shuffle options, paraphrase, change layout, inject, or repeat - and see what moves
  judge        Challenge 5: an LLM rewrites a weak listing, a decision model judges the rewrite
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path

import config
from gate import clients, evaluate, evidence, metrics, perturb, tune
from gate.questions import QUESTIONS, active
from gate.rules import Thresholds, decide
from gate.spec import YesNo

RECORDED = config.DATA / "recorded"


def _rows(args) -> list[dict]:
    rows = evidence.select(split=args.split, starter=args.starter, limit=args.limit,
                           ids=args.ids.split(",") if getattr(args, "ids", None) else None)
    if not rows:
        sys.exit("No listings match. Check --split / --starter / --ids.")
    return rows


def _fmt_p(p) -> str:
    return "  -  " if p is None else f"{p:5.2f}"


def cmd_check(args) -> None:
    print("Checking your configuration and sign-in...\n")
    ok = True
    for name, value in (("DECISION_ENDPOINT", config.DECISION_ENDPOINT), ("OPENAI_ENDPOINT", config.OPENAI_ENDPOINT)):
        state = "missing" if not value or "xxxxxxxx" in value else value
        print(f"  {name:18s} {state}")
        ok &= state != "missing"
    if not ok:
        sys.exit("\nFill in src/.env from your Hackbox, then run this again.")
    try:
        import logging
        logging.getLogger("azure.identity").setLevel(logging.CRITICAL)  # the hint below is enough
        clients.token_provider()()
        print("  Entra sign-in      ok")
    except Exception as exc:  # noqa: BLE001
        sys.stdout.flush()
        first = str(exc).strip().splitlines()[0] if str(exc).strip() else type(exc).__name__
        sys.exit(f"  Entra sign-in      not signed in ({first[:120]})\n\n"
                 "Sign in with your lab account, then run this again:\n"
                 "  az login --use-device-code\n"
                 "(Azure Cloud Shell is already signed in; GitHub Codespaces and dev containers are not.)")
    q = [YesNo(name="garden", instructions="Is this a garden product?")]
    ev = evidence.Evidence(state={"seller_listing": {"title": "Garden hose 25 m"}}, photo_b64=None)
    for mode, label in (("decision", "Microsoft-Decision-1.1"), ("luna", "gpt-6-luna Decisions API"),
                        ("llm", "gpt-6-luna Responses API")):
        call = clients.ask(mode, ev, q)
        a = call.answers.get("garden")
        if call.error or not a or a.status != "ok":
            ok = False
            print(f"  {label:26s} FAILED  {call.error or (a and a.detail)}")
        else:
            shown = f"P(yes)={a.probability:.2f}" if a.probability is not None else f"answer={a.value}"
            print(f"  {label:26s} ok      {shown}  ({call.latency_ms:.0f} ms)")
    print("\nAll good - you're ready." if ok else "\nSomething failed - see Challenge 1 troubleshooting.")
    sys.exit(0 if ok else 1)


def cmd_ask(args) -> None:
    row = evidence.listing(args.listing_id)
    t = Thresholds.load(args.thresholds)
    print(f"{row['listing_id']}  [{row['split']}]  seller category: {row['seller_category']}  price: {row['price_eur']} EUR  photo: {row.get('image') or 'none'}")
    print(f"  {row['title']}\n  {row['description'][:300]}\n")
    for mode in args.model:
        call, cached = evaluate.ask_one(mode, row, active(), layout=args.layout, use_cache=not args.no_cache)
        took = "cache" if cached else f"{call.latency_ms:.0f} ms" if call.latency_ms else "-"
        print(f"== {mode}  ({took}, tokens in/out {call.input_tokens}/{call.output_tokens}){'  ERROR ' + call.error if call.error else ''}")
        for q in QUESTIONS:
            a = call.answers.get(q.name)
            if a is None:
                continue
            value = "" if a.value is None else str(a.value)
            print(f"  {q.name:22s} {a.status:9s} p={_fmt_p(a.probability)}  {value}")
        d = decide(row, call, t)
        print(f"  -> {d.outcome.upper()}" + (f"  ({'; '.join(r.message for r in d.reasons)})" if d.reasons else ""))
        print()
    if args.show_answer:
        print(f"Answer key: {row['expected']['outcome']}  {row['expected']['reasons']}  built as {row['construction']}")


def _summary(rep: dict) -> None:
    g, o = rep["gate"], rep["operations"]
    n = g["listings"] if g else o["requests"]
    print(f"\n=== {rep['mode']}: {n} listings")
    print(f"{'question':22s} {'n':>4s} {'cover':>6s} {'acc':>6s} {'brier':>6s} {'ece':>6s}")
    for name, m in rep["questions"].items():
        cal = m.get("calibration", {})
        acc = "-" if m["accuracy"] is None else f"{m['accuracy']:.3f}"
        cov = "-" if m["coverage"] is None else f"{m['coverage']:.2f}"
        print(f"{name:22s} {m['n']:4d} {cov:>6s} {acc:>6s} {cal.get('brier', '-')!s:>6s} {cal.get('ece', '-')!s:>6s}")
    if g is None:
        print("\n(First-draft questions: per-question scores only. The gate's rules need the final questions.)")
        return
    print(f"\nGate outcome accuracy {g['outcome_accuracy']}   review rate {g['review_rate']}   "
          f"false rejects {g['false_rejects']}   auto-fixes {g['auto_fixes']} ({g['auto_fix_correct']} correct)")
    print(f"Auto-published {g['auto_published']}, of which UNSAFE {g['unsafe_published']}"
          + (f"  (rate {g['unsafe_rate_among_auto_published']}, could be up to {g['unsafe_rate_upper_95']} at 95%)" if g['auto_published'] else ""))
    for ex in g["unsafe_examples"]:
        print(f"   unsafe: {ex['listing_id']} expected {ex['expected']} got {ex['got']}  {ex['construction']}")
    print(f"Latency p50 {o['latency_p50_ms']} ms, p95 {o['latency_p95_ms']} ms; queued (pacing + retries, all workers) {o['queued_s']} s; "
          f"errors {o['errors']}; tokens in/out {o['mean_input_tokens']}/{o['mean_output_tokens']}; "
          f"est. ${o['est_cost_per_10k_listings_usd']} per 10,000 listings")


def cmd_evaluate(args) -> None:
    rows = _rows(args)
    t = Thresholds.load(args.thresholds)
    questions = metrics.draft_questions() if args.draft else None
    for mode in args.model:
        print(f"Asking {mode} about {len(rows)} listings ({config.MAX_CONCURRENCY} at a time)"
              f"{' with the FIRST-DRAFT questions' if args.draft else ''}...")
        calls = evaluate.run(mode, rows, questions=questions, layout=args.layout, use_cache=not args.no_cache)
        stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
        tag = "-draft" if args.draft else ""
        out = Path(args.out) if args.out and len(args.model) == 1 else config.RUNS / f"{mode}{tag}-{args.split}-{stamp}.jsonl"
        evaluate.save(out, mode, rows, calls, split=args.split, layout=args.layout, draft=args.draft)
        rep = metrics.report(mode, rows, calls, t, questions=questions)
        _summary(rep)
        print(f"\nSaved run: {out}")


def _load_runs(paths: list[str]) -> list[tuple[dict, list, list]]:
    expanded: list[Path] = []
    for p in paths:
        if p == "latest":  # newest non-draft run of each model in runs/
            for mode in clients.MODES:
                found = sorted((f for f in config.RUNS.glob(f"{mode}-*.jsonl") if "-draft-" not in f.name),
                               key=lambda f: f.stat().st_mtime)
                if found:
                    expanded.append(found[-1])
            continue
        path = Path(p)
        if not path.exists() and (RECORDED / p).exists():
            path = RECORDED / p
        expanded.append(path)
    if not expanded:
        sys.exit("No runs found. Run `python -m gate evaluate` first.")
    return [evaluate.load(path) for path in expanded]


def cmd_report(args) -> None:
    t = Thresholds.load(args.thresholds)
    for head, rows, calls in _load_runs(args.runs):
        if args.split != "all":
            keep = [i for i, r in enumerate(rows) if r["split"] == args.split]
            rows, calls = [rows[i] for i in keep], [calls[i] for i in keep]
        rep = metrics.report(head["mode"], rows, calls, t, questions=metrics.questions_for(head))
        if args.json:
            print(json.dumps(rep, indent=1))
        else:
            _summary(rep)
            if args.calibration:
                for name, m in rep["questions"].items():
                    if "calibration" in m:
                        print(f"\n  reliability: {name}")
                        for b in m["calibration"]["table"]:
                            print(f"    P {b['bin']}  n={b['n']:4d}  mean P={b['mean_p']:.2f}  actually true={b['observed']:.2f}")


def cmd_compare(args) -> None:
    t = Thresholds.load(args.thresholds)
    reps = []
    for head, rows, calls in _load_runs(args.runs):
        if head.get("draft"):
            sys.exit("compare needs runs made with the final questions; use `report` for a --draft run.")
        if args.split != "all":
            keep = [i for i, r in enumerate(rows) if r["split"] == args.split]
            rows, calls = [rows[i] for i in keep], [calls[i] for i in keep]
        reps.append(metrics.report(head["mode"], rows, calls, t))
    names = [r["mode"] for r in reps]
    print(f"{'':36s}" + "".join(f"{n:>14s}" for n in names))
    for q in QUESTIONS:
        print(f"{'acc  ' + q.name:36s}" + "".join(f"{(r['questions'][q.name]['accuracy'] or 0):14.3f}" for r in reps))
    for key in ("outcome_accuracy", "review_rate", "unsafe_published", "false_rejects"):
        print(f"{'gate ' + key:36s}" + "".join(f"{r['gate'][key]!s:>14s}" for r in reps))
    for key in ("latency_p50_ms", "latency_p95_ms", "mean_input_tokens", "mean_output_tokens", "est_cost_per_10k_listings_usd"):
        print(f"{'ops  ' + key:36s}" + "".join(f"{r['operations'][key]!s:>14s}" for r in reps))


def _rehearsal(run: str | None) -> list[str]:
    """The run named on the command line, or the one the console would use."""
    if run:
        return [run]
    path = evaluate.rehearsal_run(RECORDED / "decision-all.jsonl")
    print(f"Run: {path.name} ({'your re-scored questions' if path.parent == config.RUNS else 'recorded, the original questions'})")
    return [str(path)]


def cmd_rescore(args) -> None:
    path = evaluate.rescore(RECORDED / "decision-all.jsonl")
    if path is None:
        print("Your questions match the recorded run, so there is nothing to re-score.")
        return
    head, _, _ = evaluate.load(path)
    print(f"\nRe-asked {', '.join(head['changed'])}; kept every other answer.\nSaved {path.name}. "
          "`python -m gate launch` and `python -m gate tune` now use it.")


def cmd_tune(args) -> None:
    (head, rows, calls), = _load_runs(_rehearsal(args.run))
    tr = [(r, c) for r, c in zip(rows, calls) if r["split"] == "threshold"]
    te = [(r, c) for r, c in zip(rows, calls) if r["split"] == "test"]
    if not tr:
        sys.exit("This run has no listings from the threshold split.")
    t, detail = tune.tune([r for r, _ in tr], [c for _, c in tr])
    print(f"Thresholds chosen on {len(tr)} THRESHOLD-split listings, using the costs in gate/tune.py:\n")
    print(f"{'question':22s} {'thresholds':22s} mistakes on the threshold split")
    for name, d in detail.items():
        if "choice" in d:
            th = f"choice >= {d['choice']:.2f}"
            mis = f"wrong {d['wrong']}, to review {d['review']} (of {d['n']})"
        else:
            th = f"no <= {d['no']:.2f}, yes >= {d['yes']:.2f}"
            mis = f"missed {d['miss']}, false alarms {d['false_alarm']}, to review {d['review']} (of {d['n']})"
        print(f"{name:22s} {th:22s} {mis}")
    if args.save:
        t.save(args.save)
        print(f"\nSaved to {args.save}. Use it with --thresholds, or save it as state/thresholds.json for the console.")
    if te:
        print(f"\n--- Default thresholds on the {len(te)} TEST listings ---")
        _summary(metrics.report(head["mode"], [r for r, _ in te], [c for _, c in te], Thresholds()))
        print(f"\n--- Tuned thresholds on the same {len(te)} TEST listings ---")
        _summary(metrics.report(head["mode"], [r for r, _ in te], [c for _, c in te], t))


def cmd_launch(args) -> None:
    """The launch scorecard, the same as the console's: business numbers for a gate."""
    from gate import launch
    t = Thresholds.load(args.thresholds)
    t.pieces = None if args.pieces == "all" else [p for p in args.pieces.split(",") if p]
    (head, rows, calls), = _load_runs(_rehearsal(args.run))
    keep = [i for i, r in enumerate(rows) if r["split"] == args.split]
    card = launch.scorecard(head["mode"], [rows[i] for i in keep], [calls[i] for i in keep], t)
    print(f"Gate pieces: {', '.join(card['pieces']) or 'none'} - {args.split} split ({card['listings']} listings), "
          f"scaled to {card['assumptions']['listings_per_day']:,} listings a day\n")
    print(f"  live within a minute        {card['live_fast_pct']}%")
    print(f"  bad listings live / 10,000  {card['bad_live_per_10k']}")
    print(f"  wrong aisle / 10,000        {card['wrong_aisle_per_10k']}")
    print(f"  reviewer hours a day        {card['reviewer_hours_per_day']}")
    print(f"  cost a day                  EUR {card['cost_per_day_eur']:,} (AI: EUR {card['model_cost_per_day_eur']})")
    for b in card["bad_live"]:
        print(f"  - {b['count']} x {b['kind']}: {', '.join(e['listing_id'] for e in b['examples'])}")


def cmd_robustness(args) -> None:
    rows = _rows(args)
    t = Thresholds.load(args.thresholds)
    print(f"{args.kind}: {args.model} on {len(rows)} listings...")
    res = perturb.run(args.kind, args.model, rows, t)
    print(f"\nOutcome changed for {res['outcome_changed']} of {res['listings']} listings; "
          f"became LESS SAFE for {res['became_less_safe']}.")
    if "injected_listings" in res:
        print(f"Injected text was sent to review or rejected for {res['injected_caught']} of {res['injected_listings']} listings.")
    print("\nAnswer agreement per question:")
    for name, m in res["answer_agreement"].items():
        if m["n"]:
            print(f"  {name:22s} {m['agreement']:.3f}  (n={m['n']})")
    for ex in res["examples"]:
        print(f"  less safe: {ex['listing_id']} {ex['before']} -> {ex['after']}  {ex['construction']}")


def main(argv=None) -> None:
    p = argparse.ArgumentParser(prog="python -m gate", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    def selection(sp, default_split="dev"):
        sp.add_argument("--split", default=default_split, choices=["dev", "threshold", "test", "all"])
        sp.add_argument("--starter", action="store_true", help="only the 24-listing starter set (dev split)")
        sp.add_argument("--limit", type=int)
        sp.add_argument("--ids", help="comma-separated listing ids")

    sp = sub.add_parser("check")
    sp.set_defaults(fn=cmd_check)

    sp = sub.add_parser("ask")
    sp.add_argument("listing_id")
    sp.add_argument("--model", nargs="+", default=["decision"], choices=clients.MODES)
    sp.add_argument("--layout", default="structured", choices=["structured", "plain"])
    sp.add_argument("--thresholds")
    sp.add_argument("--no-cache", action="store_true")
    sp.add_argument("--show-answer", action="store_true", help="also print the answer key")
    sp.set_defaults(fn=cmd_ask)

    sp = sub.add_parser("evaluate")
    selection(sp)
    sp.add_argument("--model", nargs="+", default=["decision"], choices=clients.MODES)
    sp.add_argument("--layout", default="structured", choices=["structured", "plain"])
    sp.add_argument("--thresholds")
    sp.add_argument("--no-cache", action="store_true")
    sp.add_argument("--draft", action="store_true", help="Challenge 2: use the first-draft claims question")
    sp.add_argument("--out")
    sp.set_defaults(fn=cmd_evaluate)

    sp = sub.add_parser("report")
    sp.add_argument("runs", nargs="+", help="run files, or names in data/recorded/")
    sp.add_argument("--split", default="all", choices=["dev", "threshold", "test", "all"])
    sp.add_argument("--thresholds")
    sp.add_argument("--calibration", action="store_true", help="print reliability tables")
    sp.add_argument("--json", action="store_true")
    sp.set_defaults(fn=cmd_report)

    sp = sub.add_parser("compare")
    sp.add_argument("runs", nargs="+", help="run files, names in data/recorded/, or 'latest'")
    sp.add_argument("--split", default="all", choices=["dev", "threshold", "test", "all"])
    sp.add_argument("--thresholds")
    sp.set_defaults(fn=cmd_compare)

    sp = sub.add_parser("rescore", help="re-ask only the questions you changed on the threshold and test splits")
    sp.set_defaults(fn=cmd_rescore)

    sp = sub.add_parser("tune")
    sp.add_argument("run", nargs="?", help="a run covering the threshold and test splits (default: your re-scored run, else the recorded one)")
    sp.add_argument("--save", help="write thresholds to this JSON file")
    sp.set_defaults(fn=cmd_tune)

    sp = sub.add_parser("launch", help="the launch scorecard for a gate")
    sp.add_argument("run", nargs="?", help="default: your re-scored run, else the recorded one")
    sp.add_argument("--pieces", default="all", help="comma-separated: safety,truth,shelf (default: all)")
    sp.add_argument("--split", default="threshold", choices=["dev", "threshold", "test"])
    sp.add_argument("--thresholds")
    sp.set_defaults(fn=cmd_launch)

    sp = sub.add_parser("robustness")
    selection(sp)
    sp.add_argument("kind", choices=["shuffle", "paraphrase", "layout", "injection", "repeat"])
    sp.add_argument("--model", default="decision", choices=clients.MODES)
    sp.add_argument("--thresholds")
    sp.set_defaults(fn=cmd_robustness)

    sp = sub.add_parser("judge")
    sp.add_argument("listing_id", nargs="?", help="a listing with a known GTIN (default: a few weak dev listings)")
    sp.add_argument("--limit", type=int, default=3)
    sp.add_argument("--tempt", action="store_true", help="ask the writer to 'make it more appealing'")
    sp.add_argument("--title", help="judge your own rewrite instead of generating one (needs listing_id)")
    sp.add_argument("--description", help="description for --title")
    sp.set_defaults(fn=lambda a: __import__("gate.judge", fromlist=["main"]).main(a))

    # Model output can contain characters a Windows console code page cannot show.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    args = p.parse_args(argv)
    args.fn(args)


if __name__ == "__main__":
    main()
