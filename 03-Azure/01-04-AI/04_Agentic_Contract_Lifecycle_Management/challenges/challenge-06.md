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
> it works**. Stuck? The code *is* the answer key.

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

This challenge closes the **responsible-AI loop** — services that attack, guard, and gate the agent so a risky change can never ship:

| Service | What it is | Why it's here |
|---|---|---|
| **Azure AI Content Safety** | A managed guardrail service that inspects prompts & responses — **Prompt Shields** (jailbreak + indirect injection), **PII** and protected-material checks — attached to an agent in the portal. | Legal contracts = sensitive data + high stakes; a prompt-only guardrail isn't enough on its own. → [Content Safety](https://learn.microsoft.com/en-us/azure/ai-services/content-safety/overview) |
| **AI Red Teaming Agent** (`azure-ai-evaluation[redteam]`) | An automated adversary: generates adversarial objectives, mutates them with **attack strategies** (encodings, ciphers, composed jailbreaks via **PyRIT**), fires them at your agent, and reports an attack-success-rate scorecard. [`red_team.py`](../src/red_team.py) writes a repeatable `redteam_scorecard.json`. | Finds **unknown** failures — the ones you didn't think to test — before an attacker does. → [AI Red Teaming Agent](https://learn.microsoft.com/en-us/azure/foundry/concepts/ai-red-teaming-agent) |
| **Safety evaluators** (`azure-ai-evaluation`) | The safety side of the Challenge 3 eval SDK: `ContentSafetyEvaluator` + `IndirectAttackEvaluator` score responses for harmful content and **indirect prompt injection (XPIA)**. Run via [`safety_eval.py`](../src/safety_eval.py); gate `--gate 0.1` fails on too high a defect rate. | Red-teaming *attacks*; safety evaluators *measure* — together they tell you whether hardening actually worked. → [Evaluation](https://learn.microsoft.com/en-us/azure/foundry/concepts/observability) |
| **Continuous evaluation in CI** (GitHub Actions) | [`ci-eval.yml`](../.github/workflows/ci-eval.yml) runs `evaluators.py --gate 3.0` + `safety_eval.py --gate 0.1` on schedule / on demand via **Azure OIDC**; a regression **fails the build**, and it cleanly no-ops without secrets. | A one-time scan proves safety *today*; a CI gate keeps it safe **on every future change**. |

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
> <img src="../images/challenge-06/steps/01-redteam-scorecard.png" alt="Baseline red-team scan scorecard with 0% overall attack success rate" width="80%">

### Task 2 · Turn up the heat (~10 min)

With attack strategies (encodings + a composed Base64→ROT13 attack):
```bash
python src/red_team.py --strategies --num-objectives 2
```
Which strategies slip past the guardrails that baseline prompts don't?

> 📸 **Screenshot slot — what you'll see:** the printed **scorecard table** (and/or `redteam_scorecard.json`).
>
> <img src="../images/challenge-06/steps/02-redteam-scorecard.png" alt="Red-team scorecard table showing attack success rates by risk category and complexity" width="80%">

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
> <img src="../images/challenge-06/steps/03-guardrails.png" alt="Guardrail evaluation defect rates and passing safety gate verdict" width="80%">

### Task 4 · Harden the agent (~15 min)

Task 4 hardens **two different agents** — keep them straight:
- **Code agent (`intake-drafting-agent`)** — tighten the refusal/grounding instructions in `src/agents/intake_drafting_agent.py`. This is the in-process agent the red-team scan targets, so this is what drops the defect rate.
- **Portal agent (`clm-contract-agent`)** — in the portal, attach **Content Safety** (Prompt Shields + PII) to your **existing** MCP-backed agent from **Ch4 Task 4 Part B** (published to Teams in Ch5). Defense-in-depth for the production/Teams surface — **don't create a new agent**.

**Attach Content Safety (portal):** go to **Build → Agents → `clm-contract-agent`**, expand **Guardrails** in the playground's left pane, then **Manage guardrail** and enable:
- **Content filters** — keep **Hate / Sexual / Self-harm / Violence** at **Medium** (default).
- **Prompt Shields** — turn on both **jailbreak** and **indirect (XPIA) prompt injection** — the injection attacks the red team throws.
- **Set each guardrail's Action to `Block`, not `Annotate`.** Ticking the checkbox only turns on *detection*; the **Action** dropdown decides *enforcement*. **Annotate** lets the content through with a severity label (the attack can still succeed, so the defect rate won't drop) — it's monitor-only. **Block** stops the response so the guardrail actually holds and the attack-success / defect rate falls.
- **Protected materials** — this control shows **two checkboxes**; tick **both**:
  - **Protected material for text** — blocks the agent from reproducing copyrighted text (song lyrics, articles, recipes…).
  - **Protected material for code** — blocks regurgitation of licensed source code (with its GitHub-repo citation).
  For **each** box set **Intervention point = `Output`** (the risk is in what the agent *emits*, not the user's prompt) and **Action = `Block`**. The header should then read **Protected materials (2)** — the *(2)* confirms both are on.
- **Sensitive data leakage → PII (Preview)** — you **must pick at least one** data type or the wizard blocks you (*"Please select at least one PII data type"*). For legal contracts:
  - **User information:** Name, Email, Phone number, Address — party/contact PII in NDAs & MSAs.
  - **Financial information:** Credit card, IBAN, SWIFT code, and the bank-account types for your regions (US / EU / Canada / Australia) — payment & banking clauses.
  - *Optional (defense-in-depth):* the **Azure / Database** connection-string & key types stop the agent ever echoing infra secrets — or just **Select All** for max coverage.

Then click **Next** to reach **Select agents and models** (step 2 of 3):
- **Pick at least one agent** — for this hack tick **`clm-contract-agent`** (your MCP-backed portal/Teams agent from Ch4 Task 4 Part B). That's the production surface this guardrail protects.
- *Optional:* you can also tick **`intake-drafting-agent`**, but the **Task 1 red-team scan won't reflect it** — `red_team.py` builds that agent **in-process** via `create_agent()`, so it never hits the portal deployment. The code agent's defect rate moves by tightening its **instructions**, not this portal guardrail.
- **Leave the Models list unchecked** — the guardrail rides on the *agent*; only check a raw model deployment if you want to guard a bare endpoint with no agent.
- Heads-up: **applying the guardrail creates a new *version* of the selected agent(s)** (the wizard says so) — expected; your Teams-published agent simply picks up the new version.

Then **Next → Review → Create guardrails**, **re-run Tasks 1–3**, and confirm the attack success / defect rate **drops**.

> 📸 **What you'll see:** the Guardrails wizard — content filters plus **PII (Preview)** with its data-type picker (pick at least one).
>
> <img src="../images/challenge-06/steps/04-guardrails-pii.png" alt="Foundry Guardrails wizard: content filters, Protected materials, and PII (Preview) data-type picker (User / Azure / Database / Financial information)" width="80%">

### Task 5 · Wire the gate into CI (~5 min + optional OIDC)

**Why this task:** a one-time scan proves your agent is safe *today*; a **CI gate keeps it safe on every future change**. [`.github/workflows/ci-eval.yml`](../.github/workflows/ci-eval.yml) re-runs the Challenge 3 **quality gate** (`evaluators.py --gate 3.0`) and the Challenge 6 **safety gate** (`safety_eval.py --gate 0.1 --safety-evals`) **automatically** — **nightly** (weekdays 06:00 UTC) and **on demand** — so a regression **fails the build** before it can merge. It runs on **GitHub-hosted runners** (not your Codespace), logs into Azure with **OIDC** (no stored passwords), and cleanly **no-ops** if the Azure secrets aren't set.

**Required — enable + trigger (works for *every* fork, ~2 min):**
1. **Enable the workflow.** Scheduled workflows are **disabled by default in forks**, so open the **Actions** tab → select **ci-eval** → click **Enable workflow** (the yellow banner). Until you do, it never runs — schedule *or* manual.
2. **Trigger it:** on the **ci-eval** workflow click **Run workflow** (`workflow_dispatch`), or wait for the nightly schedule. **With no Azure secrets set, the job runs and cleanly no-ops (a green check)** — that already satisfies the success criterion below, so *you're done*. Adding the secrets (optional stretch) makes the gates run for real.

<details>
<summary>🔓 <b>Optional stretch — make the gates actually call Azure (OIDC)</b></summary>

> ⚠️ **This is tenant/org-dependent — skip it if you're blocked; the two required steps above already pass.** Running the gates *for real* needs rights to create a **managed identity + federated credential + role assignment**, and some GitHub orgs enforce **immutable OIDC subjects** (see Troubleshooting → `AADSTS700213`). Without the secrets the job simply **no-ops** (still green).

**Add the four repo secrets** — **Settings → Secrets and variables → Actions → New repository secret**. Add each one **separately**: put the variable **name** in the **Name** box and paste **only the value** in the **Secret** box — **no `NAME=` prefix and no quotes** (e.g. Name = `AZURE_TENANT_ID`, Secret = `72f988bf-…`). Where to get each (run in the Codespace terminal, where you're already `az login`'d from Challenge 1):

| Secret | How to get the value |
|--------|----------------------|
| `AZURE_SUBSCRIPTION_ID` | `az account show --query id -o tsv` |
| `AZURE_TENANT_ID` | `az account show --query tenantId -o tsv` |
| `AZURE_AI_PROJECT_ENDPOINT` | already in your `.env` from Challenge 1 → `grep AZURE_AI_PROJECT_ENDPOINT .env` (or `azd env get-values`, or Foundry portal **Overview → Endpoint**) |
| `AZURE_CLIENT_ID` | the **client (application) ID** of the identity the workflow signs in as — **see the note below** (it's *not* just any app registration) |

**Grab them in two commands:**
```bash
azd env get-values                         # dumps the azd-provisioned values, incl. AZURE_SUBSCRIPTION_ID + AZURE_AI_PROJECT_ENDPOINT
az account show --query tenantId -o tsv     # AZURE_TENANT_ID (not stored in the azd env)
```

> ⚠️ **`AZURE_CLIENT_ID` must be an OIDC-enabled identity — not just any app registration.** In particular **don't reuse the Challenge 1 SharePoint app** ("CLM Microhack Corpus") — it signs in with a client *secret* and has no federation, so CI login fails with **`AADSTS70025: … has no configured federated identity credentials`**. `azure/login@v2` uses **federated** login (no stored secret), so the app behind `AZURE_CLIENT_ID` needs **(a)** a **federated credential** trusting this repo **and (b)** an RBAC role on the Foundry project. Set it up either way:
>   - **One-shot (recommended):** `azd pipeline config --provider github` (run once in the Codespace) — creates the identity, adds the federated credential, assigns the roles, **and** sets the `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID` GitHub secrets automatically. Then just add `AZURE_AI_PROJECT_ENDPOINT` by hand. *(It also generates a stray `azure-dev.yml` deploy pipeline — not part of this hack; ignore or delete it. If login then fails with `AADSTS700213`, your org uses immutable subjects — see Troubleshooting.)*
>   - **Manual:** add the credential in **Entra ID → App registrations → *your app* → Certificates & secrets → Federated credentials → Add credential → GitHub Actions**, **Entity = Branch**, **Branch = `main`** (subject `repo:<owner>/<repo>:ref:refs/heads/main`, audience `api://AzureADTokenExchange`) — CLI: `az ad app federated-credential create --id <AZURE_CLIENT_ID> --parameters '{"name":"gh-ci-eval-main","issuer":"https://token.actions.githubusercontent.com","subject":"repo:<owner>/<repo>:ref:refs/heads/main","audiences":["api://AzureADTokenExchange"]}'`. Then grant the app the **Azure AI Developer** role (or **Cognitive Services User**) on the Foundry project, or the eval steps 401/403 after login succeeds.

Then **re-run ci-eval** — with the secrets present it runs the gates for real instead of no-opping.

</details>

> 💡 **"Should I run it in the Codespace instead?"** No — the **GitHub Action runs on GitHub's runners**, triggered from the **Actions** tab. You *can* dry-run the very same gates locally to check the logic — e.g. `python src/safety_eval.py --gate 0.1 --safety-evals` (add `--dry-run` to skip live calls) in the Codespace terminal — but that's a **local check**, not the continuous gate. Task 5 is specifically about the **automated** CI run.

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

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| `ModuleNotFoundError: azure.ai.evaluation.red_team` | Install the extra: `pip install "azure-ai-evaluation[redteam]"`. |
| Empty scorecard — `Invalid data type <coroutine ...>, expected str data type`, `coroutine 'callback' was never awaited`, **0/0 attacks / 0.0% ASR** | The scan target must match a supported shape. A **single-arg** callback (`def callback(query)`) is treated as a *sync* callback that must return a `str`; an OpenAI **Chat-Protocol** callback (`async def callback(messages, stream=False, session_state=None, context=None)` returning `{"messages": [...]}`) is *awaited*. `src/red_team.py` uses the Chat-Protocol form — if you customized it, don't make a single-arg callback `async`. |
| Scan is slow | Lower `--num-objectives`; run baseline before `--strategies`. Each objective is a full agent turn. |
| Safety evaluators 401/403 | They need the **Foundry project** endpoint + a logged-in credential with the right role. |
| `ValueError: 'ContentFiltered' is not a valid ContentFilterCodes` from `safety_eval.py --safety-evals` | **Not a bug in your agent — the guardrail worked.** Your adversarial prompt tripped Azure's content filter / Prompt Shields (common once Task 4 attaches Content Safety), so the platform blocked it upstream. A client-library enum doesn't recognise the server's `ContentFiltered` code, so the block used to surface as this `ValueError` and crash the run. `safety_eval.py` now catches it, counts the prompt as **held** (⛔ content filter), and keeps going — `git pull` if you still see the crash. |
| Guardrail wizard **Next / Create** fails with `Error updating guardrail …: "Policy does not have necessary permission to override base policy. Please check aka.ms/oai/rai/exceptions"` | Applying a guardrail writes a **complete content-filter (RAI) policy** to the deployment, and Azure only accepts one that is **as strict or stricter** than Microsoft's base policy. The error means your config is **looser** somewhere. **Two things loosen it:** (1) an **Action = `Annotate`** (monitor-only) on any control — set **every** control's **Action = `Block`**; and (2) **⚠️ counter-intuitively, the severity slider — `High` is the *loosest*, not the strictest.** The slider sets *what gets filtered*: **`Low, medium, high`** = strictest (blocks all three), **`Medium, high`** = default, **`High`** = **loosest** (low **and medium pass**, only high blocked → looser than base → rejected). **Fix:** drag every category's severity to **`Low` (i.e. "Low, medium, high" = strictest)**, or just leave it at the **default (Medium)** — **never `High`** — and keep **Action = `Block`**. `Low` is guaranteed to be accepted because it can't be looser than base. If it *still* fails with everything on `Block` at `Low`/default severity, your subscription/tenant has a **locked base RAI policy** you lack RBAC to override — that needs an org admin exception ([aka.ms/oai/rai/exceptions](https://aka.ms/oai/rai/exceptions)) and is **out of scope** here. Either way you're not blocked: the guardrail is optional hardening — Tasks 1–3 run without it. |
| Defect rate looks too good/bad | The heuristic keys on refusal phrases; use `--safety-evals` for model-graded scoring and refine `REFUSAL_MARKERS`. |
| CI job skipped | Expected when Azure secrets aren't set — it no-ops by design. Add the secrets to enable it. |
| `ci-eval` shows **0 workflow runs** / never triggers in your fork | GitHub **disables scheduled workflows by default in forks**. Open **Actions → ci-eval → Enable workflow** (yellow banner), then use **Run workflow** or wait for the schedule. |
| Workflow fails at **Azure login** with `AADSTS70025: The client '…' has no configured federated identity credentials` | Your `AZURE_CLIENT_ID` app has **no GitHub OIDC federated credential** — usually because it's the Challenge 1 **SharePoint app** (secret auth). Set up the federated identity as described in **Task 5 → Optional stretch** (`azd pipeline config --provider github`, or add the credential + **Azure AI Developer** role by hand). |
| Workflow fails at **Azure login** with `AADSTS700213: No matching federated identity record found for presented assertion subject 'repo:<owner-id>/<repo-id>@…:ref:refs/heads/main'` | Your org enforces **immutable OIDC subjects** (numeric owner/repo IDs), but the federated credential was created with the *plain* `repo:<owner>/<repo>:ref:…` subject, so they don't match. **Copy the exact `subject` string from the failed run log** and add a matching federated credential: `az identity federated-credential create --name gh-main-immutable --identity-name <msi> --resource-group <rg> --issuer "https://token.actions.githubusercontent.com" --subject "<paste immutable subject verbatim>" --audiences "api://AzureADTokenExchange"` (or, for an app registration, `az ad app federated-credential create`). This is the **optional stretch** only — the required no-op run is unaffected. |
| A second workflow **`azure-dev.yml` / "Configure Azure Developer Pipeline"** appears and fails | That's **not part of this hack** — `azd pipeline config` auto-generates it to run `azd provision/deploy`. Ignore it, disable it in **Actions**, or delete `.github/workflows/azure-dev.yml`. Only **`ci-eval`** is the lab gate. |

## 🔗 How this fits

**You built** the safety net — an **AI Red Teaming** scan, **Content Safety / PII** guardrails, and a
**quality + safety gate wired into CI** so a risky change can never ship.

- **Builds on** the entire system — it attacks and guards everything from Challenges 2–5, reusing
  Challenge 3's gate pattern.
- **Feeds** nothing after it — this is the production-readiness capstone.

*In the arc → this is **"make it safe"**: the Responsible-AI layer that separates a prototype from something legal and procurement would approve.*

## 🧠 Reflection

- Red-teaming finds *unknown* failures; evaluation measures *known* quality. Why do you need both
  before shipping an agent that touches contracts?
- A guardrail can live at the **prompt**, the **content-safety** layer, or the **CI gate**. Which
  attacks does each stop, and where would you invest first for a legal use case?
- What attack-success threshold would *you* require before letting this go live in Teams?

🎉 **Bonus complete** — you red-teamed, hardened, and gated a multi-model CLM agent. That's the full
responsible-AI loop from build → grounded → traced → evaluated → **secured** → shipped.

⬅️ Back to the **[main README](../README.md)**.
