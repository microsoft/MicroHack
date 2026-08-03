#!/usr/bin/env python3
"""Generate placeholder "screenshot slot" SVGs for the challenge walkthroughs.

Each challenge README references screenshots under ``challenge-N/images/steps/``.
Until a real screenshot is dropped in, this script writes a lightweight SVG
placeholder (a dashed slot + caption) so the ``<img>`` tags render instead of
showing a broken image. Replace any ``*.svg`` with a real ``*.png`` (same base
name) and update the README's ``src`` extension — or keep the SVG if you prefer.

Run:  python src/scripts/make_step_placeholders.py
Idempotent — safe to re-run. Existing PNGs are never overwritten.
"""
from __future__ import annotations

import html
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

# (challenge dir, slot filename, short title, "what you'll see" caption)
SLOTS: list[tuple[str, str, str, str]] = [
    # ---- Challenge 1 · Setup ------------------------------------------------
    ("challenge-0", "01-fork", "GitHub · Fork the repo",
     "The GitHub 'Create a new fork' page for glejdis/microhack-aiagents with the green 'Create fork' button."),
    ("challenge-0", "02-create-codespace", "GitHub · Create Codespace",
     "Code button → Codespaces tab → 'Create codespace on main' green button."),
    ("challenge-0", "03-codespace-ready", "Codespace · Ready",
     "The VS Code-in-browser Codespace with a terminal open and 'pip install -r requirements.txt' finished."),
    ("challenge-0", "04-az-login-device", "Azure · Device-code login",
     "The https://microsoft.com/devicelogin page where you paste the code printed by 'az login --use-device-code'."),
    ("challenge-0", "05-azd-up-prompts", "azd up · Prompts",
     "The terminal prompting for an environment name and an Azure region (pick swedencentral)."),
    ("challenge-0", "06-azd-up-success", "azd up · Success",
     "The terminal 'SUCCESS: Your application was provisioned' summary listing the created resources."),
    ("challenge-0", "07-portal-resource-group", "Azure Portal · Resource group",
     "The rg-clm-microhack resource group Overview listing ~7 resources (Foundry, Search, App Insights, Log Analytics...)."),
    ("challenge-0", "08-foundry-deployments", "Foundry Portal · Model deployments",
     "Foundry portal → Models + endpoints showing gpt-5.4, gpt-5.6-sol and gpt-4.1-mini as 'Succeeded'."),
    ("challenge-0", "09-search-index", "Foundry/Search · clm-corpus index",
     "The clm-corpus search index with a non-zero document count after seeding."),
    ("challenge-0", "10-smoke-pass", "Terminal · Smoke test PASS",
     "The 'Smoke test: PASS' output with gpt-5.4, gpt-5.6-sol and gpt-4.1-mini replying OK."),
    ("challenge-0", "11-appreg-create", "Entra Portal · New app registration",
     "Microsoft Entra admin center → App registrations → New registration, naming the app 'CLM Microhack Corpus'."),
    ("challenge-0", "12-api-permissions", "Entra Portal · Graph API permissions",
     "The app's API permissions blade after adding Microsoft Graph APPLICATION permissions Sites.ReadWrite.All and Files.Read.All."),
    ("challenge-0", "13-admin-consent", "Entra Portal · Grant admin consent",
     "The API permissions list showing green 'Granted for <tenant>' checkmarks after clicking 'Grant admin consent'."),
    ("challenge-0", "14-client-secret", "Entra Portal · Client secret",
     "Certificates & secrets → New client secret, with the secret Value visible (copy it now — shown only once)."),

    # ---- Challenge 2 · Grounded agent --------------------------------------
    ("challenge-1", "01-kb-setup-ok", "Terminal · kb_setup OK",
     "kb_setup.py printing the resolved clm-search connection and clm-corpus index."),
    ("challenge-1", "02-agent-demo", "Terminal · 4-prompt demo",
     "intake_drafting_agent.py output: draft, cited Q&A, CT-4821 tool JSON, and the legal-advice refusal."),
    ("challenge-1", "03-portal-playground", "Foundry Portal · Playground",
     "The Foundry Playground with the Intake & Drafting agent selected, showing a grounded answer with citations."),

    # ---- Challenge 3 · Observability ---------------------------------------
    ("challenge-2", "01-tracing-on", "Terminal · Tracing enabled",
     "tracing_setup.py printing 'Tracing enabled -> Application Insights (content recording ON).'"),
    ("challenge-2", "02-portal-tracing", "Foundry Portal · Tracing",
     "Foundry portal → Tracing: a span timeline for one run (prompt → retrieval → tool → response) with token counts."),
    ("challenge-2", "03-agent-monitoring", "Foundry Portal · Agent monitoring",
     "The Agent Monitoring dashboard showing latency, token usage and run counts across the GPT fleet."),
    ("challenge-2", "04-scorecard", "Terminal · Evaluation scorecard",
     "evaluators.py scorecard with groundedness/relevance/coherence/fluency and mean latency."),
    ("challenge-2", "05-gate-fail", "Terminal · Quality gate fails",
     "'GATE FAILED — groundedness below threshold' when running --gate 5.0."),

    # ---- Challenge 4 · Orchestration + MCP ---------------------------------
    ("challenge-3", "01-clause-risk", "Terminal · Clause & Risk",
     "clause_risk_agent.py output: per-draft clause table, flagged deviations, High risk, cited to the clause library."),
    ("challenge-3", "02-orchestrator", "Terminal · Orchestrator thread",
     "orchestrator.py running draft → analyze → status, noting which specialist handled each turn."),
    ("challenge-3", "03-mcp-list", "VS Code · MCP: List Servers",
     "Command Palette → 'MCP: List Servers' with clm-mcp listed and 'Start' available."),
    ("challenge-3", "04-copilot-tool", "VS Code · Copilot tool call",
     "Copilot Chat (Agent mode) invoking #analyze_contract and returning the risk assessment."),

    # ---- Challenge 5 · Publish + alerts ------------------------------------
    ("challenge-4", "01-channels-publish", "Foundry Portal · Publish to Teams",
     "Agent → Channels → 'Teams and Microsoft 365 Copilot' → Publish, provisioning an Azure Bot."),
    ("challenge-4", "02-teams-live", "Teams · Agent answering live",
     "The orchestrator answering a 'draft an NDA' request inside a Teams chat with cited output."),
    ("challenge-4", "03-proactive-alert", "Teams · Proactive alert",
     "A proactive 'CT-4821 renews in 30 days' alert arriving in Teams without the user prompting."),
    ("challenge-4", "04-renewal-summary", "Terminal · Renewal summary",
     "obligation_renewal_agent.py printing the alert-ready renewal summary for the chosen window."),

    # ---- Challenge 6 · Safety ----------------------------------------------
    ("challenge-5", "01-redteam-scorecard", "Terminal · Red-team scorecard",
     "red_team.py printing the attack-success-rate scorecard per risk category."),
    ("challenge-5", "02-safety-gate", "Terminal · Safety gate",
     "safety_eval.py printing the guardrail defect rate and SAFETY GATE PASSED/FAILED."),
    ("challenge-5", "03-actions-run", "GitHub · Actions run",
     "The Actions tab showing the ci-eval workflow running the quality + safety gates."),
]

SVG_TEMPLATE = """<svg xmlns="http://www.w3.org/2000/svg" width="900" height="300" viewBox="0 0 900 300" role="img" aria-label="{aria}">
  <rect x="4" y="4" width="892" height="292" rx="14" fill="#F5F3FA" stroke="#7A4FB5" stroke-width="2" stroke-dasharray="10 8"/>
  <text x="36" y="66" font-family="Segoe UI, Arial, sans-serif" font-size="30">📸</text>
  <text x="80" y="70" font-family="Segoe UI, Arial, sans-serif" font-size="26" font-weight="700" fill="#4A2A82">SCREENSHOT SLOT</text>
  <text x="36" y="120" font-family="Segoe UI, Arial, sans-serif" font-size="22" font-weight="600" fill="#222">{title}</text>
  <foreignObject x="36" y="140" width="828" height="110">
    <div xmlns="http://www.w3.org/1999/xhtml" style="font-family:Segoe UI,Arial,sans-serif;font-size:17px;line-height:1.5;color:#444;">
      {caption}
    </div>
  </foreignObject>
  <text x="36" y="278" font-family="Segoe UI, Arial, sans-serif" font-size="14" fill="#7A4FB5">Replace this file with your own screenshot ({fname}.png), then point the README &lt;img&gt; at the .png.</text>
</svg>
"""


def main() -> int:
    written = 0
    for challenge, fname, title, caption in SLOTS:
        new_challenge = "challenge-%02d" % (int(challenge.split("-")[1]) + 1)
        steps_dir = REPO_ROOT / "images" / new_challenge / "steps"
        steps_dir.mkdir(parents=True, exist_ok=True)
        # Never clobber a real screenshot the user has dropped in.
        if (steps_dir / f"{fname}.png").exists():
            continue
        svg = SVG_TEMPLATE.format(
            aria=html.escape(f"Screenshot slot: {title}"),
            title=html.escape(title),
            caption=html.escape(caption),
            fname=html.escape(fname),
        )
        (steps_dir / f"{fname}.svg").write_text(svg, encoding="utf-8")
        written += 1
    print(f"Wrote {written} placeholder screenshot slot(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
