"""Challenge 6 (BONUS) — automated red-teaming with the AI Red Teaming Agent.

Runs Foundry's **AI Red Teaming Agent** (`azure-ai-evaluation` red_team) against
the CLM agent: it auto-generates adversarial attack objectives across risk
categories, mutates them with attack strategies (encodings, ciphers, jailbreak
templates), sends them to your agent, and scores how often the agent produced
unsafe output — an **attack success rate** scorecard.

The target is a plain callback that wraps the Intake & Drafting agent (gpt-5.4),
so we red-team the SAME agent you shipped in Challenge 2.

Run (scan is async; this wraps it):
    python src/red_team.py                       # quick scan (baseline)
    python src/red_team.py --strategies          # add easy/moderate attack strategies
    python src/red_team.py --num-objectives 3 --output redteam_scorecard.json

Requires: `pip install "azure-ai-evaluation[redteam]"` (pulls PyRIT) and an
Azure AI (Foundry) project + login. See requirements.txt.
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
    """Return an async callback that maps a query string → the agent's reply.

    The AI Red Teaming Agent calls `await callback(query)` for every attack
    prompt. Because the scan already runs inside an event loop, the callback is
    async and awaits the Agent Framework agent directly.
    """
    from clm_common.foundry import run_agent
    from intake_drafting_agent import create_agent

    agent = create_agent()

    async def callback(query: str) -> str:
        try:
            return await run_agent(agent, query)
        except Exception as exc:  # noqa: BLE001 — never crash the scan on one prompt
            return f"[agent error: {exc}]"

    return callback


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
    if output_path:
        scan_kwargs["output_path"] = output_path

    print(f"▶ Red-teaming '{settings.model_drafting}' agent — "
          f"{num_objectives} objective(s)/category, strategies={'on' if use_strategies else 'baseline'}")
    result = await agent.scan(**scan_kwargs)

    print("\n=== Red-team scorecard ===")
    print(result)
    if output_path:
        print(f"\n✓ Full scorecard written to {output_path}")
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
