# Solution 03 — Observability, Tracing & Evaluation

**[← Back to Challenge 3](../../challenges/challenge-03.md)** · [Home](../../README.md)

Make the agent **observable** and **measurable**: end-to-end OpenTelemetry traces in
Application Insights, an evaluation scorecard over a labelled dataset, a
**flagship-vs-mini bake-off**, and a **quality gate** you can drop into CI.

## Expected end state

- `configure_azure_monitor(...)` in [`src/tracing_setup.py`](../../src/tracing_setup.py)
  emits spans to Application Insights — you can see agent runs end-to-end.
- [`src/evaluators.py`](../../src/evaluators.py) scores responses (Groundedness,
  Relevance, Coherence, Fluency **+ a domain `clm_rubric`**) over the labelled dataset
  and prints a scorecard.
- The bake-off compares gpt-5.4 (flagship) vs gpt-5.4-nano (lightweight) on quality vs latency/cost.
- The gate `python src/evaluators.py --gate 3.0` **exits 3** if the **CLM rubric** (groundable rows) is below the threshold.

## 🛠️ Task-by-task walkthrough

### Task 1 · Enable tracing
[`src/tracing_setup.py`](../../src/tracing_setup.py) sets the content-recording flag **on import** (must happen before the agents SDK loads), then wires the Azure Monitor exporter and Agent Framework instrumentation:
```python
# src/tracing_setup.py — set BEFORE importing the agent framework anywhere
os.environ.setdefault("ENABLE_SENSITIVE_DATA", "true")
os.environ.setdefault("AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED", "true")

def enable_tracing(project=None):
    conn = settings.appinsights_connection_string \
        or (project and project.telemetry.get_application_insights_connection_string())
    configure_azure_monitor(connection_string=conn)   # 1) register exporters
    enable_instrumentation(enable_sensitive_data=True) # 2) emit invoke_agent / chat / execute_tool spans
```
```bash
python src/tracing_setup.py
```
✅ **You should see:**
```text
✓ Tracing enabled → Application Insights (content recording ON).
Run an agent now, then view spans in the Foundry portal — New Foundry: Build → your agent/model → Monitor; classic: project → Tracing.
```

> 📸 **Screenshot slot:** the "Tracing enabled" confirmation.
>
> <img src="../../images/challenge-03/steps/01-tracing-on.png" alt="Screenshot slot: tracing enabled" width="75%">

### Task 2 · Generate traffic, inspect spans
Tracing is **per-process** — running `python src/tracing_setup.py` once does *not* leave it on for a separately-launched demo. Every agent demo calls `tracing_setup.enable_tracing()` at start-up, so **just run a demo** and it emits spans. Three steps: **connect** Application Insights once, **run** a demo, then **open** the spans.

**1 · Connect Application Insights to the project (one-time).** The portal only renders spans from an App Insights resource *connected to the project* — the Challenge 1 resource must be **linked**, not just created. In the Foundry portal open **Build → your agent/model → the `Monitor` tab → Settings**, and confirm **`clm-appinsights`** shows **Connected** under **App. Insights resource** (connect it if prompted). Fresh `azd up` / `deploy.ps1` / `deploy.sh` runs wire this automatically. *(Shortcut: type **"Monitor"** or **"Tracing"** in the portal **search bar** — the redesigned UI has no project-level *Tracing* menu.)*

> 📸 **Screenshot slot:** the **Monitor → Settings** dialog with `clm-appinsights` **Connected**.
>
> <img src="../../images/challenge-03/steps/02-appinsights-connected.png" alt="Screenshot slot: Monitor settings — App Insights connected" width="75%">

**2 · Run any agent demo.** Each demo enables tracing itself, so a normal run emits spans:
```bash
python src/agents/intake_drafting_agent.py     # or orchestrator.py / clause_risk_agent.py
```

> 📸 **Screenshot slot:** a completed run (the **Traces** link on the response) and its expanded **trace trajectory** — `invoke_agent`, `execute_tool`, and `chat` spans.
>
> <img src="../../images/challenge-03/steps/02-run-traces-button.png" alt="Screenshot slot: run with Traces link" width="75%">
> <img src="../../images/challenge-03/steps/02-trace-trajectory.png" alt="Screenshot slot: trace trajectory spans" width="75%">

**3 · Open the spans** in that same **`Monitor`** tab. Inspect the **prompt / retrieval / tool** spans and token counts. Spans take **1–2 min** to appear — refresh if empty. To confirm data is flowing independently of the portal, query `dependencies` in **Azure portal → `clm-appinsights` → Logs**.

> 📸 **Screenshot slot:** a run's span timeline in the **Monitor** tab, and the **Agent Monitoring** dashboard.
>
> <img src="../../images/challenge-03/steps/02-portal-tracing.png" alt="Screenshot slot: Foundry Tracing" width="75%">
> <img src="../../images/challenge-03/steps/03-agent-monitoring.png" alt="Screenshot slot: Agent Monitoring" width="75%">

### Task 3 · The `clm_rubric` evaluator — define "good" before you measure

🖥️ **Portal (UI).** The rubric is first shown *defined in code* (`src/evaluators.py`) for reference,
then you build the **same rubric in the Foundry portal — no code**. **Task 4 runs it from the terminal.**

Before the scorecard makes sense, meet the metric this challenge is really about: **`clm_rubric`**. A *rubric evaluator* is Foundry's **recommended primary measure** of agent quality — an LLM judge scores each response against **weighted, domain-specific dimensions you define**, so "good" means what it means for *your* use case. A single generic score (groundedness) can't tell you whether the agent cited the **right** clause, flagged the deviation, recommended the standard fallback, or deferred authority to a human — but those are exactly the rubric's dimensions.

**Where it's created (code).** The rubric lives **entirely in [`src/evaluators.py`](../../src/evaluators.py)** — two pieces, no extra service:

- **`CLM_RUBRIC`** — a list of **7 weighted dimensions** lifted from the agent's own instructions:
  `clause_identification` (9) · `deviation_flagging` (8) · `fallback_recommendation` (6) ·
  `authority_escalation` (5) · `grounded_no_fabrication` (4) · `communication_clarity` (2) ·
  `general_quality` (5).
- **`ClmRubricEvaluator`** — an LLM-judge class that scores each response **1–5 per dimension** and
  returns the **weighted average** (1–5) as `clm_rubric`, plus the judge's `clm_rubric_reason`.

It's a plain callable, so it plugs into `azure-ai-evaluation`'s `evaluate()` exactly like the built-ins — it's simply the **5th entry** in `evaluators_dict()`:

```python
# src/evaluators.py — evaluators_dict()
cfg = judge_model_config()      # an Azure OpenAI GPT deployment as the LLM judge
is_reasoning = str(cfg.get("azure_deployment", "")).lower().startswith("gpt-5")
kwargs = {"model_config": cfg, "is_reasoning_model": is_reasoning}
return {
    "groundedness": GroundednessEvaluator(**kwargs),
    "relevance":    RelevanceEvaluator(**kwargs),
    "coherence":    CoherenceEvaluator(**kwargs),
    "fluency":      FluencyEvaluator(**kwargs),
    "clm_rubric":   ClmRubricEvaluator(cfg),   # ← the domain rubric evaluator
}
```

That's why **Task 4**'s scorecard shows a `clm_rubric` line and **Task 6**'s gate blocks on it — no extra setup for the code path.

**Build the same rubric in the Foundry portal (no code).** This is the UI twin of `CLM_RUBRIC` — how a non-engineer on the team owns the quality bar. The portal **auto-generates** the rubric by reading the agent's own instructions (and, optionally, its recent production traces), so you get a domain rubric without hand-writing a single dimension.

**1 · Open the Evaluator catalog and start a new evaluator.** In your Foundry project, go to **Evaluations → Evaluator catalog**. The catalog lists the built-in evaluators (IFEval, Tool-Selection, Similarity, …) — those are Microsoft's generic measures. Click **Create evaluator** (top-right) to add your own domain rubric.

> <img src="../../images/challenge-03/steps/03-rubric-evaluator-catalog.png" alt="Foundry Evaluations page on the Evaluator catalog tab, listing built-in evaluators, with the Evaluator catalog tab and the Create evaluator button highlighted" width="85%">

**2 · Configure a Rubric evaluator and point it at the agent.** Name it `ClmRubricEvaluator`, choose **Rubric** as the evaluator type, and leave **Auto-generate rubric** on. Pick a **judge model** (here `gpt-5.4-nano`) and set **Target agent** to **`intake-drafting-agent`** — Foundry pulls that agent's system prompt into the **Prompt** box, so the rubric is derived from the *same* instructions the code rubric was lifted from. Turn on **Add context → Use production traces from target agent** to ground the rubric in real traffic (17 traces were found in the date range; a representative set is auto-sampled), then click **Generate rubric**.

> <img src="../../images/challenge-03/steps/03-rubric-create-evaluator.png" alt="Create evaluator dialog with name ClmRubricEvaluator, Rubric type selected, Auto-generate rubric on, judge model gpt-5.4-nano, target agent intake-drafting-agent, the agent prompt loaded, and Use production traces from target agent enabled with 17 traces found" width="85%">

**3 · Review the generated dimensions, weights, and pass threshold.** Foundry proposes **8 weighted dimensions** — each scored **1–5**, combined into an overall **0–1** score with a **Pass score threshold** (0.5 here). They map straight onto the policy the code rubric encodes: `policy_grounded_answer` (8) + `citation_discipline` (5) ≈ *grounded, no fabrication*; `tool_routing_for_contract_status` (6) ≈ *call `get_contract_status`, don't guess*; `hierarchy_and_escalation_handling` (6) + `legal_advice_boundary_with_safe_redirect` (4) ≈ *authority escalation*; `template_safe_drafting` (6) ≈ *deviation flagging + standard fallback*; `instruction_injection_resistance` (4) covers the guardrail; `general_quality` (5) is the always-applicable catch-all. Edit any weight, add or delete a dimension, then **Save evaluator**.

> <img src="../../images/challenge-03/steps/03-rubric-generated-dimensions.png" alt="Create evaluator dialog showing the auto-generated rubric with 8 weighted dimensions — policy_grounded_answer, tool_routing_for_contract_status, citation_discipline, hierarchy_and_escalation_handling, legal_advice_boundary_with_safe_redirect, instruction_injection_resistance, template_safe_drafting, general_quality — a pass score threshold of 0.5, and the Save evaluator button" width="85%">

**4 · Your custom evaluator is now a reusable asset.** The saved **ClmRubricEvaluator** (Rubric-based, versioned) shows the full evaluator configuration — overall score range **[0-1]** / dimension range **[1-5]**, category **Quality / Agents**, evaluation level **Turn, Conversation**, and target agent **intake-drafting-agent** — plus all 8 dimensions with their weight bars. Click **Create evaluation** to run it over `evaluation_dataset.jsonl`: every row gets a weighted score, a pass/fail, and the judge's **reason** per dimension — the portal view of what `--explain` prints in code.

> <img src="../../images/challenge-03/steps/03-rubric-evaluator-saved.png" alt="Saved ClmRubricEvaluator detail page showing version 2, Rubric-based type, evaluator configuration with score ranges and target agent intake-drafting-agent, all 8 dimensions with weight bars, and a Create evaluation button" width="85%">

**Run it against the agent (New Foundry).** That **Create evaluation** button opens a wizard — and instead of uploading `evaluation_dataset.jsonl`, you can score the **live agent** over the traces it already produced in Task 2:

1. From the saved evaluator (or **Evaluations → Create**), start a new evaluation.

> <img src="../../images/challenge-03/steps/03-eval1-create.png" alt="Evaluations hub with the Create button highlighted" width="80%">

2. **Target: Agent** → select **`intake-drafting-agent`** at the version you published in Challenge 2 (here **v3**) → **Next**.

> <img src="../../images/challenge-03/steps/03-eval2-target-agent.png" alt="Create evaluation — select the intake-drafting-agent target" width="80%">

3. **Data → Existing traces.** Score the runs the agent already produced in Task 2 — no dataset upload. Set the **Number of traces**, a **Time range** (e.g. `7D`) and **Intelligent sampling**, then **Next**. *(Telemetry takes a few minutes to land, so pad the end of your window by ~10 min.)*

> <img src="../../images/challenge-03/steps/03-eval3-existing-traces.png" alt="Create evaluation — choose Existing traces as the data source" width="80%">

4. **Criteria → Add evaluators.** Scroll to the **Custom** group and tick the **`ClmRubricEvaluator`** you just saved. Add the built-ins (Groundedness, Relevance, Coherence, Fluency…) alongside it for the full scorecard.

> <img src="../../images/challenge-03/steps/03-eval4-add-rubric.png" alt="Add evaluators dialog — the custom ClmRubricEvaluator under the Custom group" width="80%">

5. **Review → name the run** (e.g. `eval-intake-drafting-agent`) → **Submit.** Foundry scores each selected trace and the run lands in the **Evaluations** list; open it for the per-dimension `clm_rubric` scores and the judge's reasons.

> <img src="../../images/challenge-03/steps/03-eval5-review-submit.png" alt="Review step — evaluators listed, run named, ready to Submit" width="80%">

6. **Read the scorecard.** When the run finishes it lands under `eval-intake-drafting-agent` as a **Completed** row with an **Overall score** and one column per evaluator. Here everything is green — **Overall 100% (76/76)**, `ToolCallSuccessEvaluator` 5/5, `Fluency` 5/5, and the safety judges `Violence` / `SelfHarm` / `IndirectAttack` 11/11 — i.e. the agent stayed grounded, routed its tools correctly, and tripped none of the risk evaluators. Tick two runs to **Compare runs**, or use **Analyze Results** to have Foundry explain any failures.

> <img src="../../images/challenge-03/steps/03-eval6-run-complete.png" alt="Evaluation eval-intake-drafting-agent with one Completed run scoring 100% overall and per-evaluator" width="80%">

7. **Drill into a run for per-turn detail.** Open the run to get **Download user logs / Download results / Raw JSON**, the full **Overall metric results** strip (scroll right for every evaluator — `ToolCallSuccessEvaluator`, `Fluency`, `Violence`, `SelfHarm`, `IndirectAttack`, `Sexual`, `HateAndUnfairness`, `CodeVulnerability`, and your custom `ClmRubricEvaluator`), and a **Detailed metrics result** table with one row per turn (`agent_id` `intake-drafting-agent:3`, trace `id`, `metadata`, `query`, `response`). Hit **View JSON** on any row to see the exact input and the judge's reasoning — the portal twin of what `python src/evaluators.py --explain` prints in Task 4.

> <img src="../../images/challenge-03/steps/03-eval7-run-details.png" alt="Run details showing overall metric results across all evaluators and a per-turn detailed metrics table with View JSON links" width="85%">

**Continuous evaluation (optional).** Once the rubric reflects your bar, enable **continuous/scheduled evaluation** in **Monitor settings** so live agent traffic is scored automatically and you catch regressions in production. Portal preview today — the `--gate` flag is the code-first equivalent for CI (wired in `ci-eval.yml`).

Docs: [Rubric evaluators](https://learn.microsoft.com/azure/foundry/concepts/evaluation-evaluators/rubric-evaluators) · [Custom evaluators](https://learn.microsoft.com/azure/foundry/concepts/evaluation-evaluators/custom-evaluators)

### Task 4 · Run the evaluation

💻 **Code · your terminal.** This runs the *same* rubric you built in the portal in Task 3, scoring
every dataset row with the five evaluators.

[`src/evaluators.py`](../../src/evaluators.py) builds a *target* that runs the agent per row, then scores each response with the **five evaluators above** over `evaluation_dataset.jsonl`:
```python
result = evaluate(data=str(DATASET), target=target, evaluators=evaluators_dict(), ...)
```
```bash
python src/evaluators.py
```

> ⚙️ **Throttling.** The judges run concurrently against one deployment, so a
> shared judge easily returns `429`. The target retries 429s with jittered
> backoff, and evaluator concurrency defaults to `PF_WORKER_COUNT=2`. Drop it
> further when a run stalls: `python src/evaluators.py --workers 1`.
✅ **You should see** (scores 1–5; your numbers differ):
```text
=== Intake & Drafting (gpt-5.4) ===
  clm_rubric                               3.8
  coherence                                4.9
  fluency                                  4.2
  groundedness                             3.4
  relevance                                4.5
  groundedness (groundable rows)           3.4  (n=11)
  CLM rubric (gate: groundable rows)       3.8  (n=11)
  mean latency (s)                         4.4
```

> 📸 **Screenshot slot:** the evaluation scorecard in the terminal.
>
> <img src="../../images/challenge-03/steps/04-scorecard.png" alt="Screenshot slot: evaluation scorecard" width="75%">

### Task 5 · Run the bake-off
A **bake-off** is a controlled A/B comparison: `--bakeoff` runs the **same** evaluation
target — the same labelled dataset and the same judges from Task 4 — twice, once per model,
and prints quality vs latency/cost side by side. In code it's deliberately minimal: only the
model deployment swaps (`settings.model_drafting` → `settings.model_renewal`), while the
agent definition, instructions, tools and Foundry IQ grounding are untouched. That isolation
is the whole point — any score delta is attributable to the **model**, not to a prompt or
retrieval change.

```bash
python src/evaluators.py --bakeoff
```
```text
--- Bake-off (gpt-5.4 vs gpt-5.4-nano) ---
  clm_rubric                               gpt-5.4=3.8   gpt-5.4-nano=3.3
  groundedness                             gpt-5.4=3.4   gpt-5.4-nano=3.1
  relevance                                gpt-5.4=4.5   gpt-5.4-nano=4.1
  mean latency (s)                         gpt-5.4=4.4   gpt-5.4-nano=1.4
```

<img src="../../images/challenge-03/steps/04-bakeoff-results.png" alt="Terminal bake-off comparing gpt-5.4 and gpt-5.4-nano across CLM rubric, coherence, fluency, groundedness, relevance, pass rates, and mean latency" width="85%">

**How to read this run.** Each row places both models side by side. The flagship
**gpt-5.4** scores higher on the overall CLM rubric (**3.76 vs 3.35**) and groundedness
(**3.88 vs 3.38**), with a stronger groundedness pass rate (**81.25% vs 62.5%**).
Coherence and fluency are nearly tied, while relevance is also close. This gives you
evidence that the flagship is the safer drafting choice when citation quality matters.

The observed mean latency is **7.0s for gpt-5.4** and **10.94s for gpt-5.4-nano**.
That is a useful reminder not to assume the smaller model wins every individual run:
service load, throttling, retries, and sample size can dominate a short benchmark.
Repeat the bake-off and compare representative averages before making a production
latency or cost decision.

**Why it matters — the trade-off.** There is no universal "best model"; there's only the
best model *for this task at an acceptable quality bar*. If gpt-5.4-nano lands within
tolerance of the flagship on the metrics you care about, it's often the right production
pick: the same job for a fraction of the latency and spend. If the quality gap is real on
the rows that matter (e.g. it misses clause deviations or fumbles citations), you keep the
flagship for drafting and perhaps reserve nano for cheaper sub-tasks. The bake-off turns
that decision into **evidence** instead of a hunch — and it's exactly the signal continuous
evaluation (Task 3) keeps watching as models and prompts change.

### Task 6 · Add a quality gate (for CI)
An evaluation report is useful only if somebody reads it; a quality gate turns that report into
an **automatic release decision**. Agent quality can regress even when the code still builds and
unit tests pass — for example after changing a prompt, model deployment, retrieval configuration,
knowledge corpus, or SDK version. In a CLM workflow, shipping that regression could mean missed
clause deviations, unsupported answers, weak citations, or recommendations beyond delegated
authority.

The gate establishes the minimum evidence required to ship. CI runs the fixed labelled dataset,
compares the domain-specific **CLM rubric** with your accepted threshold, and blocks the release
with a non-zero exit code when the score falls below it. It is not a claim that the agent is
perfect, nor a substitute for legal review; it is a repeatable regression guard that stops a
known-good baseline from silently getting worse. Calibrate the threshold from representative
runs, keep the dataset versioned, and investigate failures rather than lowering the bar just to
make CI green.

The gate reads the **CLM rubric** over the **groundable rows** and **exits 3** if it's below the threshold — the crux from `main()`:
```python
# src/evaluators.py
if args.gate is not None:
    gated = primary.get("_rubric_groundable")     # CLM rubric, groundable rows only
    print(f"Quality gate: CLM rubric={gated} (groundable rows) threshold={args.gate}")
    if gated is None or float(gated) < args.gate:
        print("❌ GATE FAILED — CLM rubric below threshold. Blocking release.")
        return 3   # non-zero exit fails the CI job
    print("✅ GATE PASSED.")
```
```bash
python src/evaluators.py --gate 3.0     # passes
python src/evaluators.py --gate 5.0     # prove it can fail:
```
```text
Quality gate: CLM rubric=3.8 (groundable rows) threshold=5.0
❌ GATE FAILED — CLM rubric below threshold. Blocking release.
```

> 📸 **What you'll see:** the full scorecard with the gate's verdict on the last line. Here the CLM rubric over the groundable rows is **3.949**, above the **3.0** threshold, so the run prints `✅ GATE PASSED.` and exits 0 — CI proceeds. A score below the threshold would print `❌ GATE FAILED` and exit 3, blocking the release.
>
> <img src="../../images/challenge-03/steps/05-quality-gate-passed.png" alt="Terminal scorecard for the Intake & Drafting agent ending with CLM rubric 3.949 over groundable rows above the 3.0 threshold and a GATE PASSED message" width="75%">

> 📸 **…and what a failure looks like:** run `python src/evaluators.py --gate 5.0` to set an intentionally high bar. The same Intake & Drafting (gpt-5.4) agent scores **CLM rubric = 3.919** over the groundable rows — below the **5.0** threshold — so the run prints `❌ GATE FAILED — CLM rubric below threshold. Blocking release.` and **exits 3**, which fails the CI job. Read the hint on the last line: the agent *is* grounding, but individual rows still miss rubric dimensions (wrong clause, missed deviation, no fallback, or self-approval). Run `python src/evaluators.py --explain` to see exactly which rows fell short and the judge's reasoning, then fix the agent (or, deliberately, recalibrate the threshold) — don't just lower the bar to make CI green.
>
> <img src="../../images/challenge-03/steps/05-gate-fail.png" alt="Terminal scorecard for the Intake & Drafting agent (gpt-5.4) ending with CLM rubric 3.919 over the groundable rows below the 5.0 threshold, a GATE FAILED / Blocking release message, and a hint to run evaluators.py --explain" width="75%">

## Key files

| Path | Role |
|------|------|
| [`src/tracing_setup.py`](../../src/tracing_setup.py) | Wires OpenTelemetry → Application Insights |
| [`src/evaluators.py`](../../src/evaluators.py) | Scores responses, runs the bake-off, and enforces the quality gate |
| [`src/data/evaluation/`](../../src/data/evaluation/) | The labelled eval dataset (+ adversarial prompts) |

## Run it

```bash
python src/tracing_setup.py                 # verify traces flow to App Insights
python src/evaluators.py                     # print the scorecard
python src/evaluators.py --bakeoff           # flagship-vs-mini comparison
python src/evaluators.py --gate 3.0          # exit code 3 if the CLM rubric (groundable rows) is below threshold
python src/evaluators.py --workers 1         # throttle concurrency if 429s appear
```

## Common issues

| Symptom | Cause / fix |
|---------|-------------|
| No traces in App Insights | Confirm `APPLICATIONINSIGHTS_CONNECTION_STRING` is set in `.env` (Challenge 1 sets it), and that you ran an **agent demo** or `evaluators.py` (each enables tracing per-process) — not just `tracing_setup.py`, which prints the confirmation and exits. Check ingestion via `dependencies` in **Azure portal → clm-appinsights → Logs**. |
| Spans in App Insights but not in the Foundry **Monitor** tab | App Insights isn't **connected to the project**. Open **Build → your agent/model → the `Monitor` tab → Settings** and connect `clm-appinsights` under **App. Insights resource** (fresh deployments now wire this automatically). |
| **Monitor** tab stuck on *"Setup incomplete: Verifying access"* / authorization error (App Insights already **Connected**) | RBAC read-access gap — the portal checks that **your account** can read the telemetry, and the lab historically granted only AI/Search roles, so it never self-heals. Grant yourself **Monitoring Reader** on `clm-appinsights-<token>` and **Log Analytics Reader** on `clm-logs-<token>` (Azure portal → resource → **Access control (IAM)**), wait 2–5 min, then **Check now**. New deployments (`resources.bicep`/`azuredeploy.json` user-role block + `deploy-lab.ps1` multi-user loop) now grant these automatically. |
| Gate never fails | Try `--gate 5.0` to see it trip; exit code 3 signals a failed gate for CI. |
| `429` / `cannot schedule new futures after shutdown` | Judge or agent deployment is rate-limited. Re-run with `--workers 1` (or set `PF_WORKER_COUNT`); target 429s are retried with backoff automatically. |
