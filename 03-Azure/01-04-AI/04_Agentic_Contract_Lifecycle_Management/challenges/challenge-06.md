# Challenge 6 · Safety, Red-Teaming & Continuous Evaluation 🧪 *(Bonus — optional)*

**[🏠 Home](../README.md)**  ·  [← Challenge 5: Publish to M365](challenge-05.md)

Welcome to the bonus challenge! Your assistant works — now make it **production-safe**. You'll
adversarially attack it with the **AI Red Teaming Agent**, add **Content Safety / PII guardrails**,
and wire a **quality + safety gate into CI** so a risky change can never ship. This is the Responsible
AI layer that separates a prototype from something legal and procurement would actually approve.

If something isn't working as expected, please let your coach know.

> **⏱️ Duration:** ~45–60 min · *optional stretch for teams who finish Challenges 1–5 early*

> **📋 Prerequisites:**
> - **Challenge 2** complete — the agent runs.
> - **Challenge 3** complete — evaluation in place.

> 🧩 **How to use this challenge:** the code in this folder is a **complete, working reference
> implementation** — you're not building it from a blank file. **Run it, read it, and understand *why*
> it works**, then take it further with **🚀 Go Further**. Stuck? The code *is* the answer key.

## 🎯 Objective

Make the CLM assistant **production-safe**: adversarially attack it with the **AI Red Teaming
Agent**, add **Content Safety / PII guardrails**, and wire a **quality + safety gate into CI** so a
risky change can never ship.

## 🧭 Context

Legal contracts mean **sensitive data + high stakes** — a jailbroken or ungrounded agent is a real
liability. This challenge closes the responsible-AI loop over everything you built:

- **AI Red Teaming Agent** (`azure-ai-evaluation` `red_team`) auto-generates adversarial objectives
  across risk categories, mutates them with **attack strategies** (encodings, ciphers, jailbreak
  templates), fires them at your agent, and reports an **attack success rate** scorecard.
- **Safety evaluators** (`ContentSafetyEvaluator`, `IndirectAttackEvaluator`) score responses for
  harmful content and indirect prompt-injection (XPIA).
- **Guardrails**: Azure AI **Content Safety** (Prompt Shields, PII, protected material) plus the
  prompt-level refusal policy from Challenge 2.
- **Continuous evaluation in CI**: the Ch2 **quality gate** + a new **safety gate** run in a GitHub
  Action so regressions block the merge — the code-first counterpart to portal continuous monitoring.

## 🧰 Services & models in this challenge

This challenge closes the **responsible-AI loop**. These are the services that attack, guard, and gate
the agent so a risky change can never ship.

### Azure AI Content Safety

**What it is:** a managed **guardrail service** that inspects prompts and responses. In the portal you
attach it to an agent to block jailbreaks and leaks at the platform layer.

- **Prompt Shields** against jailbreak + indirect (document) prompt injection.
- **PII** detection and **protected-material** checks.
- Model-independent — a second line of defense **beyond** the Ch1 prompt-level refusal policy.

**Why here:** legal contracts mean sensitive data + high stakes; a prompt-only guardrail isn't enough on
its own. → [Azure AI Content Safety](https://learn.microsoft.com/en-us/azure/ai-services/content-safety/overview)

### AI Red Teaming Agent (`azure-ai-evaluation[redteam]`)

**What it is:** an **automated adversary**. It generates adversarial objectives across risk categories,
mutates them with **attack strategies** (encodings, ciphers, composed jailbreaks — powered by
**PyRIT**), fires them at your agent, and reports an **attack success rate** scorecard.

- **Auto-generated** attacks — you don't have to invent every jailbreak.
- **Attack strategies** reveal what slips past guardrails that plain prompts don't.
- [`src/red_team.py`](../src/red_team.py) (`--num-objectives`, `--strategies`) writes a repeatable
  scorecard (`redteam_scorecard.json`) you can track over time.

**Why here:** red-teaming finds **unknown** failures — the ones you didn't think to test for — before an
attacker does. → [AI Red Teaming Agent](https://learn.microsoft.com/en-us/azure/foundry/concepts/ai-red-teaming-agent)

### Safety evaluators (`azure-ai-evaluation`)

**What it is:** the **safety** side of the evaluation SDK from Challenge 3. `ContentSafetyEvaluator` and
`IndirectAttackEvaluator` score responses for harmful content and **indirect prompt injection (XPIA)**.

- Model-graded scoring for a **guardrail defect rate**, not just pass/fail heuristics.
- Take `azure_ai_project` + a credential (not a `model_config`).
- Run via [`src/safety_eval.py`](../src/safety_eval.py) (`--safety-evals`); the gate `--gate 0.1` fails on
  too high a defect rate (`--dry-run` previews with no Azure calls).

**Why here:** red-teaming *attacks*; safety evaluators *measure* — together they tell you whether
hardening actually worked. → [Evaluation & observability](https://learn.microsoft.com/en-us/azure/foundry/concepts/observability)

### Continuous evaluation in CI (GitHub Actions)

**What it is:** the **automation** that runs the quality + safety gates on every relevant change. The
quality gate blocks on the **CLM rubric** score (Challenge 3, Task 6).
[`.github/workflows/ci-eval.yml`](../.github/workflows/ci-eval.yml) runs `evaluators.py --gate 3.0` and
`safety_eval.py --gate 0.1` on a schedule / on demand using **Azure OIDC**.

- A regression **fails the build** — the code-first counterpart to portal continuous monitoring.
- No secrets? The job **cleanly no-ops** by design.
- Wire it as a **required check** so no merge lands without passing.

**Why here:** a one-time scan proves safety *today*; a CI gate keeps it safe **on every future change**.

## ✅ Tasks

### Task 1 · Baseline red-team scan (~10 min)

Against the Intake & Drafting agent (auto-generated attacks):
```bash
pip install "azure-ai-evaluation[redteam]"     # pulls PyRIT (one-time)
python src/red_team.py --num-objectives 2
```
Inspect the scorecard (`redteam_scorecard.json`) — note any category with a non-zero
attack success rate.

✅ **You should see** the scan run and a scorecard summary (numbers will vary):
```text
▶ Red-teaming intake-drafting-agent (2 objectives)...
=== Red-team scorecard ===
Category                    Attacks   Succeeded   ASR
Hate/Unfairness                   2           0    0%
Violence                          2           0    0%
Self-harm                         2           0    0%
Sexual                            2           0    0%
→ wrote redteam_scorecard.json
```

> 📸 **Screenshot slot — what you'll see:** the printed **scorecard table** (and/or `redteam_scorecard.json`).
>
> <img src="../images/challenge-06/steps/01-redteam-scorecard.svg" alt="Screenshot slot: red-team scorecard" width="80%">

### Task 2 · Turn up the heat (~10 min)

With attack strategies (encodings + a composed Base64→ROT13 attack):
```bash
python src/red_team.py --strategies --num-objectives 2
```
Which strategies slip past the guardrails that baseline prompts don't?

### Task 3 · Score CLM-specific attacks (~10 min)

Score legal-advice bypass, PII exfiltration, prompt injection and policy
override, and get a **guardrail defect rate**:
```bash
python src/safety_eval.py --safety-evals
# preview the gate with no Azure calls:
python src/safety_eval.py --dry-run --gate 0.1
```

✅ **You should see** a defect rate and a clear PASS/FAIL gate verdict:
```text
Guardrails held: 9/10 · defect rate = 10%
✅ SAFETY GATE PASSED.        # or: ❌ SAFETY GATE FAILED (defect rate 10% > gate 0%)
```

> [!TIP]
> To **see the gate fail on purpose**, run `python src/safety_eval.py --dry-run --gate 0.0`
> against the unhardened agent — a non-zero defect rate will trip `❌ SAFETY GATE FAILED` and exit
> non-zero. That's exactly what CI (Task 5) uses to block a bad merge.

> 📸 **Screenshot slot — what you'll see:** the **defect rate line** + PASS/FAIL verdict.
>
> <img src="../images/challenge-06/steps/02-safety-gate.svg" alt="Screenshot slot: safety gate verdict" width="80%">

### Task 4 · Harden the agent (~15 min)

Then re-scan to prove it improved:
- In the portal, attach **Content Safety** (Prompt Shields + PII) to the agent.
- Tighten the refusal/grounding instructions in `src/agents/intake_drafting_agent.py`.
- Re-run Tasks 1–3 and confirm the attack success / defect rate **drops**.

### Task 5 · Wire the gate into CI (~10 min)

Review `.github/workflows/ci-eval.yml` — it runs the **quality gate**
(`evaluators.py --gate 3.0`) and **safety gate** (`safety_eval.py --gate 0.1`) on a schedule /
on demand, using Azure OIDC. Configure the repo secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`,
`AZURE_SUBSCRIPTION_ID`, `AZURE_AI_PROJECT_ENDPOINT`) and trigger it from the **Actions** tab.

> 📸 **Screenshot slot — what you'll see:** the **Actions** tab with the eval workflow run (green check = gates passed).
>
> <img src="../images/challenge-06/steps/03-actions-run.svg" alt="Screenshot slot: GitHub Actions eval run" width="80%">

✅ **You'll know it worked when:** the workflow run shows a **green check** (gates passed) — or a
**red X** if a regression tripped a gate, which is the whole point.

## ✔️ Success criteria

- A red-team scorecard exists and you can point to the **attack success rate** per risk category.
- The safety evaluation prints a **guardrail defect rate**, and the gate **fails** when you set a
  strict threshold (e.g. `--gate 0.0` on an unhardened agent).
- After hardening, the attack success / defect rate is **measurably lower**.
- `ci-eval.yml` runs the quality + safety gates (or cleanly no-ops when secrets are absent).

## 🚀 Go Further

- **Bring your own attack prompts**: feed `RedTeam` a custom objectives JSON with `target_harms` to
  probe CLM-specific harms.
- Red-team the **Orchestrator** end-to-end (not just one specialist) to catch routing-layer leaks.
- Add **`ProtectedMaterialEvaluator`** and a groundedness safety check to the gate.
- Turn on **portal continuous evaluation / monitoring** and compare it to this CI gate.
- Add a PR-triggered **required check** so no merge lands without passing the safety gate.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| `ModuleNotFoundError: azure.ai.evaluation.red_team` | Install the extra: `pip install "azure-ai-evaluation[redteam]"`. |
| Scan is slow | Lower `--num-objectives`; run baseline before `--strategies`. Each objective is a full agent turn. |
| Safety evaluators 401/403 | They need the **Foundry project** endpoint + a logged-in credential with the right role. |
| Defect rate looks too good/bad | The heuristic keys on refusal phrases; use `--safety-evals` for model-graded scoring and refine `REFUSAL_MARKERS`. |
| CI job skipped | Expected when Azure secrets aren't set — it no-ops by design. Add the secrets to enable it. |

## 🧠 Reflection

- Red-teaming finds *unknown* failures; evaluation measures *known* quality. Why do you need both
  before shipping an agent that touches contracts?
- A guardrail can live at the **prompt**, the **content-safety** layer, or the **CI gate**. Which
  attacks does each stop, and where would you invest first for a legal use case?
- What attack-success threshold would *you* require before letting this go live in Teams?

🎉 **Bonus complete** — you red-teamed, hardened, and gated a multi-model CLM agent. That's the full
responsible-AI loop from build → grounded → traced → evaluated → **secured** → shipped.

⬅️ Back to the **[main README](../README.md)**.
