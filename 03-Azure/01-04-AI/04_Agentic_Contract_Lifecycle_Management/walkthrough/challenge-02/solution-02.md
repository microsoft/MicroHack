# Solution 02 — Grounded Agent with Foundry IQ + Tools

**[← Back to Challenge 2](../../challenges/challenge-02.md)** · [Home](../../README.md)

Your first agent: the **Intake & Drafting agent** — grounded on the Contoso corpus,
citing its sources, using function tools, and guard-railed to refuse legal advice.
It runs on **gpt-5.4** (sharing the orchestrator deployment), but the grounding code is identical across
GPT deployments — Foundry is a model-agnostic control plane.

## Expected end state

- Foundry IQ MCP grounding tool built over `clm-contracts-kb` by
  [`src/kb_setup.py`](../../src/kb_setup.py) (also reports the web-grounding tool).
- The agent drafts an NDA/MSA from an **approved template** and answers policy
  questions **with citations**.
- Guardrails hold: the agent refuses to give legal advice and stays grounded.

## 🛠️ Task-by-task walkthrough

### Task 1 · Verify the knowledge connection
[`src/kb_setup.py`](../../src/kb_setup.py) builds the Foundry IQ MCP tool. Challenge 1's
`seed_corpus.py` already created `clm-corpus-ks` and `clm-contracts-kb`; the agent is allowed to call
only `knowledge_base_retrieve`:
```python
# src/kb_setup.py
def build_knowledge_tool(*, connection_id=None, project=None):
    if settings.foundry_iq_enabled:
        return MCPTool(**mcp_tool_kwargs())
    # Existing environments without FOUNDRY_IQ_KNOWLEDGE_BASE retain the
    # direct Azure AI Search compatibility path.
```
```bash
python src/kb_setup.py
```
✅ **You should see** (ids will differ):
```text
✓ Index: clm-corpus
✓ Foundry IQ knowledge base: clm-contracts-kb
✓ Built Foundry IQ MCP tool (knowledge_base_retrieve).
```

> 📸 **Screenshot slot:** the terminal confirming the `clm-search` connection and `clm-corpus` index.
>
> <img src="../../images/challenge-02/steps/01-kb-setup-ok.png" alt="Screenshot slot: kb_setup OK" width="80%">

### Task 2 · The agent definition (the answer)
The whole agent is ~15 lines — grounding tool **plus** a function tool, with the model as the only deployment-specific line. From [`src/agents/intake_drafting_agent.py`](../../src/agents/intake_drafting_agent.py):
```python
# src/agents/intake_drafting_agent.py
def create_agent(model=None, *, connection_id=None):
    knowledge = build_knowledge_tool(connection_id=connection_id)   # Foundry IQ over clm-contracts-kb
    return Agent(
        client=build_chat_client(model or settings.model_drafting),  # ← "gpt-5.4"; swap for another GPT deployment id, nothing else changes
        name=AGENT_NAME,
        instructions=INSTRUCTIONS,                                   # persona + citations + refusal policy
        tools=[knowledge, function_tool(get_contract_status)],       # unstructured grounding + structured lookup
    )
```
The guardrail and grounding rules aren't buried in code — they're the **entire `INSTRUCTIONS` block** the agent runs with (the prompt layer *is* the policy). This is the real answer key for "how is it grounded and guard-railed":
```text
You are the Intake & Drafting agent for Contoso Global's Legal & Procurement team.

WHAT YOU DO
- Draft NDAs, MSAs and SOWs using ONLY the approved templates and clause library in your knowledge
  base. Fill placeholders with the details the user provides; never invent legal terms.
- Answer questions about clauses, policies and standards using your knowledge base, and ALWAYS cite
  the source documents you used.
- When asked about a specific contract's status, renewal date, risk or owner, call the
  `get_contract_status` tool. Do not guess these facts.

NEGOTIATION FALLBACKS
- When a requested term deviates from an approved template or standard clause, consult the
  negotiation playbook in your knowledge base and offer the approved fallback positions IN ORDER
  (from the preferred position down to the walk-away position). Always cite the negotiation playbook.

APPROVAL AUTHORITY (delegation of authority)
- When a draft or requested term needs sign-off — e.g. a liability cap above a threshold, a
  non-standard or off-template term, or an unusual commercial commitment — consult the
  delegation-of-authority matrix in your knowledge base and state WHO must approve it by
  role/threshold. Cite the matrix. Never self-approve.

GROUNDING & CITATIONS
- Base every substantive answer on retrieved corpus content. If the corpus does not contain the
  answer, say so plainly rather than speculating.

GUARDRAILS (must follow)
- You are NOT a lawyer and must NOT provide legal advice, legal opinions, or predictions about
  litigation/enforceability. If asked, refuse briefly and recommend review by qualified counsel.
- Do not disclose personal data or content outside the approved corpus.
- Keep a professional, concise tone. Flag anything that deviates from company policy for human review.
```
Every behavior you'll verify below traces to one of these clauses: template-only drafting, mandatory citations, tool calls for contract facts, **ordered** negotiation fallbacks, approval routing via the delegation-of-authority matrix, and the no-legal-advice refusal.

### Task 3 · Run the agent end-to-end — and what "correct" looks like
```bash
python src/agents/intake_drafting_agent.py
```
The demo runs **six prompts in one shared session**, exercising every capability. The model's exact wording changes every run — **the structure and the citations are what matter.** Here is what a *correct* run looks like, and the tell for each:

**1 · Grounded drafting** — NDA from the approved template
```text
MUTUAL NON-DISCLOSURE AGREEMENT
This Agreement is entered into as of [Effective Date] by and between Contoso Global, Inc.
("Contoso") and Acme Corp ("Counterparty").
  1. Definition of Confidential Information …
  3. Term. Two (2) years from the Effective Date …
```
✅ *Tell:* follows the template's **numbered section structure**, leaves `[placeholders]` for the user, and invents no clauses.

**2 · Cited Q&A** — standard limitation-of-liability
```text
Our standard position caps each party's aggregate liability (with the usual carve-outs for
confidentiality, IP infringement and indemnities). [CL-04, clause_library]
```
✅ *Tell:* names a **specific source id** (`[CL-04]`). A plausible answer with **no bracketed citation** means grounding didn't fire.

**3 · Negotiation fallback** — counterparty demands unlimited liability
```text
Per the negotiation playbook, offer these in order:
  1. Preferred  — mutual cap at our standard formula.
  2. Fallback   — a higher multiple for strategic deals.
  3. Walk-away  — never accept unlimited liability beyond the standard carve-outs.  [negotiation_playbook]
```
✅ *Tell:* **ordered** positions (preferred → walk-away), cited to the playbook — not generic advice.

**4 · Approval routing** — a $5M MSA with an above-standard cap
```text
That cap is above the standard threshold, so it needs sign-off. Per the delegation-of-authority
matrix, approval sits with the approver named for that role/threshold — I can't approve it myself;
route it to them. [delegation_of_authority]
```
✅ *Tell:* names **WHO must approve by role/threshold**, cites the matrix, and **never self-approves**.

**5 · Function tool** — CT-4821 status
```text
CT-4821 (Acme Corp, MSA) is Active, renews in ~55 days, auto-renew on, risk High,
owner legal@contoso.com.  [get_contract_status]
```
✅ *Tell:* concrete fields from the **tool call**, not a guessed date (see the raw JSON in Task 4).

**6 · Refusal** — a request for a legal opinion
```text
I can't provide legal advice or predict how a court would rule. Please have qualified counsel
review the matter.
```
✅ *Tell:* **brief refusal + recommends counsel**, with no opinion or litigation prediction offered.

> 📸 **Screenshot slot:** the demo run (draft · cited Q&A · fallback · approval · tool call · refusal).
>
> <img src="../../images/challenge-02/steps/02-agent-demo.png" alt="Screenshot slot: agent demo run" width="80%">

### Task 4 · Exercise every capability
Work through [`src/sample_prompts.md`](../../src/sample_prompts.md). The `get_contract_status` tool returns real, structured fields (dates computed relative to today, so yours differ):
```json
{"contract_id": "CT-4821", "counterparty": "Acme Corp", "type": "MSA",
 "status": "Active", "renewal_date": "<~55 days out>", "auto_renew": true,
 "notice_days": 90, "risk": "High", "owner": "legal@contoso.com",
 "_note": "(source: contracts_seed.json)"}
```

The demo agent runs **in-process** (`FoundryChatClient`), so it does not appear in portal → Agents/Playground. To get the Playground path, publish it as a persistent Foundry agent: `python src/agents/publish_agent.py` (`--list` / `--delete` to manage). Grounded Q&A/drafting/refusal work in the Playground; `get_contract_status` stays client-side.

> 📸 **Screenshot slot:** the Foundry **Playground** with the agent giving a grounded, cited answer.
>
> <img src="../../images/challenge-02/steps/03-portal-playground.png" alt="Screenshot slot: Foundry Playground" width="80%">

### Task 5 · (Optional) Content safety
A **preview** of Challenge 6, not a required step here. Two layers of defense:
- **Prompt layer (done)** — the `INSTRUCTIONS` refusal enforces the no-legal-advice policy; fast, but model-dependent.
- **Content-safety layer** — Azure AI **Content Safety** (Prompt Shields for jailbreak + indirect injection, PII, protected material) inspects prompts/responses **independently of the model**, so it holds even if the prompt guardrail is bypassed.

If you published the portal agents in Task 4, attach it now in the **Foundry portal** ([ai.azure.com](https://ai.azure.com)): **Build → Agents → `intake-drafting-agent` → Guardrails → Manage guardrail** → enable **Prompt Shields** + **PII** (pick ≥ 1 data type) → **Create guardrails**. No portal agent yet? Just discuss where the guardrails would sit.

➡️ Full walkthrough (data-type picks, screenshots, re-testing): **[Challenge 6 · Task 4](../../challenges/challenge-06.md#task-4--harden-the-agent-15-min)**.

## ✅ How to tell each capability truly passed

Use this to judge a participant's run (or your own). The point is distinguishing a **genuinely grounded** answer from a plausible-sounding hallucination:

| Capability | ✅ Pass signal | ❌ Fail signal → fix |
|------------|---------------|----------------------|
| **Grounded drafting** | Output follows the template's numbered sections; `[placeholders]` left for the user; no invented clauses | A free-form contract with clauses not in the template → the model isn't using the corpus. Confirm `clm-corpus` is populated (Challenge 1's `seed_corpus.py`). |
| **Cited Q&A** | Answer carries a **bracketed source** (e.g. `[CL-04]`, a policy/template name) | Confident answer with **no citation** → grounding didn't fire. Re-run `python src/kb_setup.py`; check the index doc count in the portal. |
| **Negotiation fallback** | **Ordered** positions (preferred → walk-away) citing the negotiation playbook | Generic "try to negotiate" advice, no ordered list / no playbook citation → the playbook PDF isn't in the corpus. |
| **Approval routing** | Names **who approves** by role/threshold and cites the delegation-of-authority matrix; never self-approves | Agent says a term is "approved" on its own authority → grounding/guardrail gap; confirm the matrix PDF is in the corpus. |
| **Function tool** | Concrete `CT-4821` fields returned via `get_contract_status` | Model **makes up** a date/owner instead of calling the tool → confirm the tool is in `tools=[...]` with `approval_mode="never_require"`. |
| **Refusal** | Brief refusal + "consult qualified counsel"; no opinion given | Any substantive legal opinion or litigation prediction → guardrail failed; confirm `INSTRUCTIONS` is the one passed to the agent. |

## Key files

| Path | Role |
|------|------|
| [`src/agents/intake_drafting_agent.py`](../../src/agents/intake_drafting_agent.py) | The grounded, tool-using, guard-railed drafting agent (gpt-5.4) |
| [`src/kb_setup.py`](../../src/kb_setup.py) | Builds the Foundry IQ MCP grounding tool + optional web-grounding tool |
| [`src/clm_common/foundry_iq.py`](../../src/clm_common/foundry_iq.py) | Defines and provisions the knowledge source/base |
| [`src/sample_prompts.md`](../../src/sample_prompts.md) | Prompts to exercise drafting, grounded Q&A, and the guardrails |
| [`src/clm_common/`](../../src/clm_common/) | Shared config + Foundry client helpers reused by every agent |

## Run it

```bash
python src/kb_setup.py                       # verifies clm-contracts-kb + knowledge_base_retrieve
python src/agents/intake_drafting_agent.py   # drafts + answers with citations
```

## Common issues

| Symptom | Cause / fix |
|---------|-------------|
| No citations returned | Re-run Challenge 1's `seed_corpus.py`; confirm it populated `clm-corpus` and created `clm-contracts-kb`. |
| Web-grounding tool missing | Ensure `AZURE_BING_CONNECTION_NAME` matches a project connection; `kb_setup.py` reports whether it built. |
