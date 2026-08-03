# Coach & Facilitator Guide

Everything you need to **run** the *Agentic AI Hacks · Contract Lifecycle Management (CLM)* microhack —
timings, per-challenge coaching notes, common blockers, what "done" looks like, and reset/recovery
tips. Participants never see this file; it's for the people running the room.

> **TL;DR for coaches:** the challenge code **is** the reference solution. Every script runs
> end-to-end. Your job is to keep teams unblocked on **environment** issues (region/model
> availability, RBAC propagation, `.env`) so they spend their time on **agent** concepts, not YAML.

---

## 1. Who this is for

- **Lead coach** — owns the tech talk, timing, and go/no-go on Challenge 1.
- **Floating coaches** — 1 per 2–3 teams, unblock environment issues, run the checkpoints below.
- Assumes coaches have done a **full dry-run** end-to-end at least once in the target region.

---

## 2. Before the event (do this a week out)

| Task | Why it matters |
|------|----------------|
| **Pick a region with all three model deployments** (`gpt-5.4`, `gpt-4.1-mini`, `gpt-5.6-sol`). `swedencentral` is a good default. | Challenge 1 dies here if a model isn't offered. **Verify in the Foundry model catalog for your exact subscription.** Model versions drift — the repo tracks non-deprecating pins; if you re-pin, avoid versions with a near/past `deprecation.inference` date (`az cognitiveservices model list`). |
| **Check quota** — Basic Azure AI Search + the model SKUs (TPM for each deployment). Request increases early. | Quota denials are the #1 day-of blocker and can take hours to approve. |
| **Decide the subscription model** — one sub per team (cleanest) vs a shared sub with per-team resource groups / env names. | `azd up` uses an environment name as the RG suffix; shared subs need unique names per team. |
| **Do a full dry-run** in the target region, including `azd up` **and** `labautomation/deploy.sh`. | You'll hit the region/quota issues before the participants do. |
| **Pre-provision (optional but recommended)** a subscription per team the night before. | Saves ~20 of Challenge 1's 30 min; teams start on agents, not provisioning. |
| **Cost check** — models are pay-per-token; Search Basic + App Insights are the fixed cost. Tear down with `azd down` / delete the RG after. | Budget approval + a reminder to delete afterwards. |
| **Teams/M365 tenant** — confirm you (or the participants) can **sideload a custom Teams app** and publish to M365 Copilot. | Challenge 5's publish step needs sideload rights; many corp tenants block it. Have a coach-owned tenant as fallback. |

### Pre-flight checklist (per team, morning of)

- [ ] Team has an **Azure subscription** with Owner/Contributor + rights to create role assignments.
- [ ] Region confirmed to offer all three model deployments.
- [ ] They can **fork** the repo and **open a Codespace** (or have the devcontainer locally).
- [ ] `Microsoft.BotService` provider registered (needed in Ch5): `az provider register --namespace Microsoft.BotService`.

---

## 3. Run of show (4.5 h)

| Time | Block | Coach cadence |
|------|-------|---------------|
| 09:00 – 10:00 | **Tech talk** — the CLM story, the agentic architecture, multi-model GPT fleet, Foundry IQ, tracing/eval, MCP, publish. | Show the [architecture diagram](../images/architecture.png). Set the "human always signs" guardrail expectation. |
| 10:00 – 12:30 | **Hacking — Challenges 1, 2, 3** | **Gate at Ch1:** no team moves on until `smoke_test.py` is green. Float hard here. |
| 12:30 – 13:30 | Lunch | — |
| 13:30 – 15:30 | **Hacking — Challenges 4, 5** | Ch5 builds on a working Ch4 orchestrator — make sure Ch4 runs cleanly first. Remind teams before lunch. |
| 15:30 – 16:00 | **Wrap-up / demos** | Each team demos one thing: a cited draft, a bake-off result, an MCP call, or a live Teams alert. |
| *Overflow* | **Challenge 6 (bonus)** — Safety, Red-Teaming & CI gate | For fast finishers or as a follow-up; does **not** fit inside 4.5 h. |

**Pace check:** a team should finish **Ch1 by ~10:30**, **Ch2 by ~11:30**, **Ch3 by ~12:30**. If a
team is 20+ min behind at a checkpoint, hand them a hint (below) rather than let them grind.

---

## 4. Per-challenge coaching notes

Each challenge README has the full participant instructions. Below is the **coach layer**: the point
of the challenge, what "done" looks like, where teams get stuck, and the hint to give.

### Challenge 1 · Setup & Foundry Foundations *(30 min · setup)*

- **Point:** stand up the whole Foundry environment + seed the corpus with **zero local install**.
- **Done when:** `python src/scripts/smoke_test.py` prints `✅ PASS` (a tiny agent verifies
  `gpt-5.4`, `gpt-5.6-sol`, and `gpt-4.1-mini`; drafting shares the Orchestrator's `gpt-5.4`) and the `clm-corpus` index shows documents in the portal.
- **Coach prep (before the event):** essentially **none** for the corpus. Each participant is an
  **admin of their own sandbox tenant**, so Task 6 has them run a single script —
  **`python src/scripts/setup_sharepoint_corpus.py`** — that does the *entire* SharePoint path inside
  their own tenant: registers the Entra app, **self-grants admin consent** (they're the admin, so the
  greyed-out "Grant admin consent" wall never applies), provisions a SharePoint site, uploads the 14
  corpus PDFs, and builds the `clm-corpus` indexer. It's **idempotent** and needs only `az login` plus a
  completed Task 4 deploy (`.env` with `AZURE_SEARCH_ENDPOINT`). Nothing shared to pre-stage.
- **Not an admin / no SPO license? (fallback):** teams leave the `SHAREPOINT_*` values blank and run
  `python src/scripts/seed_corpus.py`, which extracts the local `src/data/**/*.pdf` corpus straight into
  the `clm-corpus` index (needs the Search Index Data Contributor role, granted by `azd up`). Same
  grounding outcome, no SharePoint. The older `setup_sharepoint_app.sh` / `upload_corpus_to_sharepoint.py`
  helpers still exist if you ever want a **shared** library, but the per-participant one-command path is
  the default.
- **Provisioning paths** — all produce the same resources and `.env`: **`azd up`** (Bicep in
  `labautomation/infra/`), **`labautomation/deploy.sh`** (`.ps1` on Windows), or the one-click **Deploy to
  Azure** button / `az deployment sub create` on `infra/azuredeploy.json` (then
  `python src/scripts/write_env.py --deployment <name>` for `.env`). Let teams pick one; don't mix.
  - *Optional add-ons* (all paths, off by default): Azure SQL for the renewal tool
    (`DEPLOY_SQL`/`--with-sql`/`-WithSql`) and **Grounding with Bing Search** for the Clause & Risk
    agent's optional web lookup (`DEPLOY_BING`/`--with-bing`/`-WithBing`). Bing data leaves the Azure
    compliance boundary — only suggest it for the Challenge 4 "Go Further" web-grounding track.
- **Watch for:**
  - *Model deploy fails* → the model/version isn't in their region. Switch region (`eastus2`/`westus3`)
    or adjust the version in `deploy.sh`. **This is the single most common Ch1 blocker.**
  - *`account project create` unavailable* → the CLI project command is preview. Create the project in
    the **portal**, then set `AZURE_AI_PROJECT_ENDPOINT` in `.env` by hand.
  - *`az login` in Codespaces* → must use `az login --use-device-code`.
  - *RBAC not propagated* → role assignments can take a few minutes; a retry usually fixes "auth" errors
    right after `azd up`.
- **Coach hint if stuck on region:** "Open the Foundry model catalog filtered to *your* subscription and
  pick a region that lists the three deployments — don't trust a blog's default."

### Challenge 2 · Grounded Agent with Foundry IQ + Tools *(60 min · grounding · tools · guardrails)*

- **Point:** build the **Intake & Drafting agent on GPT-5.4** — grounded, cited, tool-enabled,
  and guard-railed (refuses legal advice). Establishes the pattern reused in Ch4/5.
- **Done when:** answers are **cited** from the corpus; `get_contract_status` fires for **CT-4821**; the
  legal-advice prompt is **refused**; the model shown in the portal is the **GPT-5.4** deployment shared with the Orchestrator.
- **Key teaching moment:** the agent/tool/grounding API is **identical** as you swap GPT deployments —
  that's the whole point of Foundry as a model-agnostic control plane.
- **Agents are built in-process:** with the Microsoft Agent Framework each run builds its agent against
  the Foundry chat client — nothing persists server-side, so there's no `--keep` and nothing to clean up.
- **Watch for:**
  - *No citations* → confirm `seed_corpus.py` populated the index + the semantic config exists; raise `top_k`.
  - *Function tool never called* → keep the docstring + type hints (the schema is derived from them) and
    ensure it's wrapped with `function_tool(...)` and passed in `tools=[...]`.
  - *Search connection returns nothing* → set `AZURE_SEARCH_CONNECTION_NAME` in `.env`; check portal →
    Connected resources.
- **Coach hint:** "Run `sample_prompts.md` top to bottom — it deliberately exercises draft → cited Q&A →
  status lookup → refusal, one per capability."

### Challenge 3 · Observability, Tracing & Evaluation *(60 min · tracing · eval)*

- **Point:** make the agent **observable** (OTel traces → App Insights) and **measurable** (evaluation
  scorecard + a **flagship-vs-mini bake-off** + a **quality gate**).
- **Done when:** prompt/retrieval/tool spans are visible for the agent runs; a scorecard prints
  (groundedness/relevance/coherence/fluency); the **bake-off** captures quality vs latency/cost; `--gate`
  fails when the threshold is set above the measured score.
- **The "aha":** tracing shows *what happened*; evaluation shows *how good it was*. The bake-off is the
  concrete payoff of a model-agnostic platform: compare GPT deployments without rewriting agent code.
- **Watch for:**
  - *No spans* → `APPLICATIONINSIGHTS_CONNECTION_STRING` must be set, the content-recording flag must be
    set **before** the agents SDK import (`tracing_setup` does this on import — import it first), and
    ingestion lags **1–2 min**. Tell teams to wait, not thrash.
  - *Evaluator auth error* → the judge is an **Azure OpenAI** deployment; set `AZURE_OPENAI_ENDPOINT` /
    `AZURE_OPENAI_DEPLOYMENT` or rely on the derived project endpoint + AAD.
  - *`groundedness` key not found by the gate* → SDK versions name it `groundedness` vs
    `groundedness.groundedness`; print `result["metrics"]`.
  - *Bake-off is slow* → it runs the dataset **twice** (once per model). Trim the JSONL while iterating.
- **Commands worth demoing:** `evaluators.py --bakeoff` and `evaluators.py --gate 5.0` (watch it fail
  on purpose — exit code 3).

### Challenge 4 · Orchestration + MCP Server *(60 min · orchestration · MCP)*

- **Point:** add the **Clause & Risk** specialist (GPT-5.6 Sol), stand up a **GPT-5.4 Orchestrator** that
  routes to both specialists via the **agent-as-tool pattern**, and expose the workflow as an **MCP server**.
- **Done when:** one orchestrator thread runs **draft → extract → risk** by delegating; the Clause & Risk
  agent returns a structured, cited risk assessment; the **MCP server is discoverable + callable** from
  VS Code / Copilot Chat (`#draft_contract`, `#analyze_contract`, `#get_contract_status`).
- **Ch5 builds on this orchestrator:** it publishes the Ch4 orchestrator pattern — make sure it runs cleanly.
  Call this out loudly before lunch.
- **Watch for:**
  - *Orchestrator routes wrong* → sharpen `INSTRUCTIONS` routing rules and make each specialist's
    `as_tool(description=...)` specific.
  - *`agent_framework` import error* → `pip install agent-framework-core agent-framework-foundry` (see requirements.txt).
  - *MCP server not listed in VS Code* → ensure the MCP feature is on and `src/.vscode/mcp.json`
    is picked up; confirm the server starts standalone first (`python src/mcp_server/server.py`).
  - *MCP call times out* → each call spins up + tears down a Foundry agent (a few seconds); keep test
    drafts short.
- **Sample draft is rigged:** the Clause & Risk sample has deliberate red flags (uncapped liability,
  60-day auto-renew) so a **High** risk result is the expected, demo-able outcome.
- **Go Further — agent as MCP client:** `src/orchestrator_mcp.py` runs the *same* GPT-5.4
  Orchestrator but consumes the workflow over MCP (`MCPStdioTool`) instead of in-process `as_tool()`.
  Great "aha" for the portability point — the tools serve editors **and** agents. Note the only
  non-circular consumer is the Orchestrator: a specialist consuming the server (`analyze_contract` =
  Clause & Risk) would call itself. It spawns the stdio server automatically; teams don't start it
  separately. Slower than the in-process orchestrator (each MCP call spins up a fresh Foundry agent in
  the subprocess) — fine for a demo.

### Challenge 5 · Publish to M365 Copilot & Teams + Proactive Alerts *(60 min ≈ 30 publish + 30 alerts)*

- **Point:** ship the orchestrator to **Teams / M365 Copilot** (conversational, no bot code) **and**
  push **proactive** renewal/risk alerts into Teams (needs a saved conversation reference).
- **Done when:** the orchestrator answers **live in Teams and M365 Copilot** with grounded, cited
  responses; **and** a proactive alert (e.g. the CT-4821 message) appears **without** the user prompting.
- **The distinction to teach:** conversational = **pull** (auto Azure Bot Service channel); proactive =
  **push** (save `TurnContext.get_conversation_reference` on first inbound, then
  `ADAPTER.continue_conversation(...)`).
- **Watch for:**
  - *Publish option missing* → `Microsoft.BotService` not registered, or no rights to create an Azure Bot.
  - *Works in Teams but not Copilot* → the app must be **approved for M365 Copilot** and manifest scopes
    must include it.
  - *`continue_conversation` 401/403* → check `MICROSOFT_APP_ID` / `MICROSOFT_APP_PASSWORD`; the bot must
    own the saved conversation reference.
  - *Alert never arrives* → `TEAMS_SERVICE_URL` + `TEAMS_CONVERSATION_ID` must come from a **real inbound**
    message to *this* bot.
- **No-tenant fallback:** everything alert-related runs with `--dry-run` to print the exact text without
  sending — teams blocked on sideload rights can still complete the *logic*. The manifest template +
  **branded placeholder icons** live in `src/manifest/` (regenerate via
  `python src/scripts/make_icons.py`), so zipping the app package needs no design work.

### Challenge 6 · Safety, Red-Teaming & Continuous Eval 🧪 *(bonus · optional · ~45–60 min)*

- **Point:** close the responsible-AI loop — attack the agent with the **AI Red Teaming Agent**, add
  **Content Safety / PII** guardrails, and wire a **quality + safety gate into CI**.
- **Done when:** a red-team scorecard exists with a per-category **attack success rate**; the safety eval
  prints a **guardrail defect rate**; the gate **fails** on a strict threshold; and after **hardening**
  the rate is **measurably lower**.
- **Watch for:**
  - *`ModuleNotFoundError: azure.ai.evaluation.red_team`* → install the extra: `pip install "azure-ai-evaluation[redteam]"` (pulls PyRIT, one-time).
  - *Scan is slow* → lower `--num-objectives`; run baseline before `--strategies` (each objective is a
    full agent turn).
  - *Safety evaluators 401/403* → they need the **Foundry project** endpoint + a logged-in credential.
- **Zero-Azure preview:** `safety_eval.py --dry-run --gate 0.1` shows the gate mechanics with no Azure
  calls — good for teaching CI behaviour even if they're out of time/quota.

---

## 5. Reset & recovery playbook

| Situation | Fix |
|-----------|-----|
| **`.env` looks wrong / half-populated** | Re-run the provision path (`azd up` re-runs the `write_env.py` hook), or hand-set the missing keys from the portal (project endpoint under **Overview → Endpoint**). |
| **Corpus / index empty** | Re-run `python src/scripts/seed_corpus.py` (idempotent — recreates the SharePoint indexer and re-crawls the library). Check the indexer run status + that the SharePoint library is populated. |
| **Legacy agents in the project** | The Microsoft Agent Framework builds agents in-process against the Foundry chat client — it registers **no** persistent server-side agents, so there's nothing to clean up. Delete any stragglers from earlier Agent-Service runs in **portal → Agents** if you like. |
| **Auth / 403 right after provisioning** | RBAC propagation lag — wait 2–3 min and retry before debugging anything else. |
| **Everything is wedged, start clean** | `azd down` (or delete the resource group), then `azd up` again. Budget ~15 min. |
| **Cross-challenge script `ModuleNotFoundError`** | Should not happen — the shared-module import paths are fixed and CI byte-compiles all six challenges. If it does, confirm the team didn't move files between folders. |

---

## 6. Facilitation tips

- **Gate Challenge 1.** Nobody advances on a red smoke test — a broken env poisons every later challenge.
- **Hint, don't solve.** Give the *smallest* nudge from the tables above; let teams keep ownership.
- **Protect the "aha" moments.** Make sure every team sees at least: a **cited** answer (Ch2), the
  **bake-off** (Ch3), a **routed** orchestrator turn (Ch4), and a **live Teams** response or alert (Ch5).
- **The code is the answer key.** If a team is truly stuck, read the relevant script *with* them — it's
  the reference implementation, fully commented.
- **Time-box the fallbacks.** No-tenant fallbacks exist precisely so one environment
  gap doesn't cost a team the whole afternoon. Reach for them early.
- **Bank Challenge 6** for the one or two teams who fly — it's a great "take it home" extension.

---

## 7. Cross-cutting gotchas (memorize these)

1. **Region + model availability** decides everything — validate against the *actual* subscription.
2. **Tracing lag** is 1–2 min; the content-recording flag must be set **before** the SDK import.
3. **RBAC propagation** lag causes false "auth" failures right after provisioning — retry first.
4. **Agents are built in-process** with the Microsoft Agent Framework — nothing persists server-side, so each challenge rebuilds its agent (no `--keep`).
5. **Sideload rights** in the M365 tenant are the Ch5 wildcard — have a coach tenant on standby.

---

➡️ Participant docs start at the **[main README](../README.md)** and **[Challenge 1](../challenges/challenge-01.md)**.
