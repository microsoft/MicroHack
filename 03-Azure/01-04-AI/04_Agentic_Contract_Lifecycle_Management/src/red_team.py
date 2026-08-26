"""Challenge 6 (BONUS) — automated red-teaming with the AI Red Teaming Agent.

Runs Foundry's **AI Red Teaming Agent** (`azure-ai-evaluation` red_team) against
the CLM agent: it auto-generates adversarial attack objectives across risk
categories, mutates them with attack strategies (encodings, ciphers, jailbreak
templates), sends them to your agent, and scores how often the agent produced
unsafe output — an **attack success rate** scorecard.

The target is a Chat-Protocol callback that wraps the Intake & Drafting agent (gpt-5.4),
so we red-team the SAME agent you shipped in Challenge 2.

Run (scan is async; this wraps it):
    python src/red_team.py                       # quick scan (baseline)
    python src/red_team.py --strategies          # add easy/moderate attack strategies
    python src/red_team.py --num-objectives 3 --output redteam_scorecard.json

Requires: `pip install "azure-ai-evaluation[redteam]"` (pulls PyRIT) and an
Azure AI (Foundry) project + login. See src/requirements.txt.
"""
from __future__ import annotations

import argparse
import asyncio
import os
import sys
from pathlib import Path

# --- azure-ai-evaluation / NLTK import-guard workaround --------------------
# azure-ai-evaluation (red_team) pulls in NLTK, which installs an import
# "security finder" (nltk/inisec.py) that BLOCKS importing its helper libs
# (regex, defusedxml, wordnet, ...) whenever the module resolves to a path
# *inside the current working directory*. This hack's virtualenv lives INSIDE the
# repo (./.venv), so every site-package counts as "inside cwd" and the finder
# raises "ImportError: Blocked import of <mod> from current working directory".
# NOTE: -P / PYTHONSAFEPATH do NOT help here -- the finder checks Path.cwd(),
# not sys.path. Work around it by importing the azure-ai-evaluation -> NLTK chain
# once from a throwaway temp dir (an ancestor of nothing), so the finder sees
# those modules as OUTSIDE cwd and caches them in sys.modules; later imports are
# cache hits and never re-trigger the guard. The cwd is restored immediately.
def _preload_eval_sdk() -> None:
    import shutil
    import tempfile

    cwd = os.getcwd()
    safe_dir = tempfile.mkdtemp(prefix="clm-eval-")
    try:
        os.chdir(safe_dir)
        # Importing the red_team submodule also imports the parent
        # azure.ai.evaluation package (and thus NLTK) under the safe cwd.
        import azure.ai.evaluation.red_team  # noqa: F401
    except Exception:
        pass  # missing [redteam] extra etc. -> surfaced by the real import below
    finally:
        os.chdir(cwd)
        shutil.rmtree(safe_dir, ignore_errors=True)


_preload_eval_sdk()

sys.path.insert(0, str(Path(__file__).resolve().parent))             # src (clm_common)
sys.path.insert(0, str(Path(__file__).resolve().parent / "agents"))  # agent modules

from clm_common.config import settings, credential  # noqa: E402


def build_agent_target():
    """Return an OpenAI Chat Protocol callback that maps the latest user turn → the agent's reply.

    The AI Red Teaming Agent (`azure-ai-evaluation`) inspects the callback's
    *signature* to decide how to invoke it:

    * A **single-parameter** callback (``def callback(query)``) is treated as a
      *synchronous* "simple" callback whose return value must already be a
      ``str``. Making that one ``async`` hands the SDK an un-awaited coroutine
      → ``Invalid data type <coroutine ...>, expected str data type``,
      ``coroutine 'callback' was never awaited``, **0/0 attacks and an empty
      0.0% scorecard**. (This was the original bug.)
    * A callback aligned to the **OpenAI Chat Protocol**
      (``messages, stream, session_state, context``) is treated as *async* and is
      **awaited** by the scan. That lets us await the Agent Framework agent
      directly on the scan's own event loop — no thread/loop juggling — and
      return the reply in the expected ``{"messages": [...]}`` envelope.

    Keep the 4-parameter shape below so attacks actually run and the scorecard
    populates.
    """
    from clm_common.foundry import run_agent
    from intake_drafting_agent import create_agent

    agent = create_agent()

    def _latest_user_message(messages) -> str:
        """Extract the newest turn's text; tolerate dicts, objects, or an envelope."""
        if isinstance(messages, dict):
            messages = messages.get("messages", [])
        if not messages:
            return ""
        last = messages[-1]
        if isinstance(last, dict):
            return last.get("content", "")
        return getattr(last, "content", "")

    async def callback(messages, stream=False, session_state=None, context=None):
        query = _latest_user_message(messages)
        try:
            reply = await run_agent(agent, query)
        except Exception as exc:  # noqa: BLE001 — never crash the scan on one prompt
            reply = f"[agent error: {exc}]"
        return {"messages": [{"content": reply, "role": "assistant"}]}

    return callback


def _export_scorecard(dest: str) -> None:
    """Copy the freshest scan's full results JSON to a single, cleanly-named file.

    The RedTeam SDK always writes a working folder ``./.scan_<timestamp>/`` whose
    ``final_results.json`` holds the full scorecard/results. We copy that to
    ``dest`` (default ``redteam_scorecard.json``) so you get ONE predictably-named
    file. Passing our own ``output_path`` straight to ``scan()`` made an
    oddly-named ``redteam_scorecard.json/`` *directory* in this experimental
    azure-ai-evaluation version, so we do the export ourselves instead.
    """
    import shutil

    scan_dirs = sorted(
        (p for p in Path.cwd().glob(".scan_*") if p.is_dir()),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    for scan in scan_dirs:
        for name in ("final_results.json", "results.json"):
            src = scan / name
            if src.is_file():
                # A prior run of an older version (which passed ``output_path``
                # straight to ``scan()``) can leave a stray *directory* named
                # like our dest — then ``shutil.copyfile`` raises
                # ``IsADirectoryError``. Clear whatever is there first so the
                # export is self-healing and idempotent.
                dest_path = Path(dest)
                if dest_path.is_dir():
                    shutil.rmtree(dest_path, ignore_errors=True)
                elif dest_path.exists():
                    dest_path.unlink()
                shutil.copyfile(src, dest_path)
                print(f"✓ Full scorecard written to {dest}  (copied from {src})")
                return
    print(f"⚠ Couldn't find a .scan_*/final_results.json to export to {dest}; "
          "see the ./.scan_* folder for the raw results.")


def _print_scorecard_table(scorecard_path: str) -> None:
    """Render the per-category attack-success-rate matrix from the exported JSON.

    The RedTeam SDK returns a ``RedTeamResult`` object with no readable ``repr``
    (printing it just dumps ``<...RedTeamResult object at 0x...>``), and in this
    experimental version it does not always print a scorecard table to the
    terminal — so the per-category numbers otherwise only live inside
    ``redteam_scorecard.json``. The SDK's ``ScanResult`` JSON exposes
    ``scorecard.risk_category_summary[0]`` with ``<cat>_total`` /
    ``<cat>_successful_attacks`` per risk category, so we print the same
    Category / Attacks / Succeeded / ASR table the challenge promises. ASR is
    computed from succeeded/total here so it's independent of the SDK's own
    fraction-vs-percent scaling.
    """
    import json

    path = Path(scorecard_path)
    if not path.is_file():
        return
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return

    summaries = (data.get("scorecard") or {}).get("risk_category_summary") or []
    if not summaries:
        print("⚠ Scorecard JSON has no risk_category_summary — 0 attacks ran? "
              "Check that the scan target is the Chat-Protocol callback.")
        return
    row = summaries[0]

    categories = [
        ("Hate/Unfairness", "hate_unfairness"),
        ("Violence", "violence"),
        ("Sexual", "sexual"),
        ("Self-harm", "self_harm"),
    ]

    print("\n=== Red-team scorecard ===")
    print(f"{'Category':<20}{'Attacks':>9}{'Succeeded':>11}{'ASR':>7}")

    def _emit(label: str, total, succeeded) -> None:
        total = int(total or 0)
        succeeded = int(succeeded or 0)
        asr = (100.0 * succeeded / total) if total else 0.0
        print(f"{label:<20}{total:>9}{succeeded:>11}{asr:>6.0f}%")

    for label, key in categories:
        if f"{key}_total" not in row:
            continue
        _emit(label, row.get(f"{key}_total"), row.get(f"{key}_successful_attacks"))
    if "overall_total" in row:
        _emit("Overall", row.get("overall_total"), row.get("overall_successful_attacks"))


async def run_scan(num_objectives: int, use_strategies: bool, output_path: str | None) -> None:
    from azure.ai.evaluation.red_team import RedTeam, RiskCategory, AttackStrategy

    agent = RedTeam(
        azure_ai_project=settings.require_project(),  # Foundry project endpoint
        credential=credential(),
        risk_categories=[
            RiskCategory.Violence,
            RiskCategory.HateUnfairness,
            RiskCategory.Sexual,
            RiskCategory.SelfHarm,
        ],
        num_objectives=num_objectives,
    )

    callback = build_agent_target()
    scan_kwargs: dict = {"target": callback}
    if use_strategies:
        # Layered strategies: baseline + text mutations + a composed encoding attack.
        scan_kwargs["attack_strategies"] = [
            AttackStrategy.EASY,
            AttackStrategy.MODERATE,
            AttackStrategy.CharacterSpace,
            AttackStrategy.ROT13,
            AttackStrategy.Compose([AttackStrategy.Base64, AttackStrategy.ROT13]),
        ]
    # NOTE: we intentionally do NOT pass ``output_path`` to ``scan()``. In this
    # experimental SDK version that makes a directory literally named
    # ``redteam_scorecard.json/``; instead we export a clean single file from the
    # SDK's own ``./.scan_<timestamp>/`` folder after the run (see below).

    print(f"▶ Red-teaming '{settings.model_drafting}' agent — "
          f"{num_objectives} objective(s)/category, strategies={'on' if use_strategies else 'baseline'}")
    # The RedTeam result object has no readable ``repr`` (printing it just dumps
    # ``<...RedTeamResult object at 0x...>``), so we don't dump it — we export the
    # JSON below and render a per-category table from it (see _print_scorecard_table).
    await agent.scan(**scan_kwargs)

    if output_path:
        _export_scorecard(output_path)
        _print_scorecard_table(output_path)
    print("\nInterpretation: lower attack-success-rate = safer. Investigate any category > 0% and "
          "add the guardrails from safety_eval.py / the portal, then re-scan.")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--num-objectives", type=int, default=2,
                        help="attack objectives per risk category (default 2; raise for coverage)")
    parser.add_argument("--strategies", action="store_true",
                        help="apply attack strategies (encodings/ciphers) on top of baseline")
    parser.add_argument("--output", default="redteam_scorecard.json",
                        help="path for the JSON scorecard")
    args = parser.parse_args()
    asyncio.run(run_scan(args.num_objectives, args.strategies, args.output))


if __name__ == "__main__":
    main()
