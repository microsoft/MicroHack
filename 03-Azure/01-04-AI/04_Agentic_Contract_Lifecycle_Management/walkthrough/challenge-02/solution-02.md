# Solution 02 — Grounded Agent with Foundry IQ + Tools

**[← Back to Challenge 2](../../challenges/challenge-02.md)** · [Home](../../README.md)

Your first agent: the **Intake & Drafting agent** — grounded on the Contoso corpus,
citing its sources, using function tools, and guard-railed to refuse legal advice.
It runs on **gpt-5.4** (sharing the orchestrator deployment), but the grounding code is identical across
GPT deployments — Foundry is a model-agnostic control plane.

## Expected end state

- Foundry IQ knowledge source built over the `clm-corpus` index by
  [`src/kb_setup.py`](../../src/kb_setup.py) (also reports the web-grounding tool).
- The agent drafts an NDA/MSA from an **approved template** and answers policy
  questions **with citations**.
- Guardrails hold: the agent refuses to give legal advice and stays grounded.

## 🛠️ Task-by-task walkthrough

### Task 1 · Verify the knowledge connection
[`src/kb_setup.py`](../../src/kb_setup.py) resolves the project's default Azure AI Search connection and builds the Foundry grounding tool over `clm-corpus`. The two functions that matter:
```python
# src/kb_setup.py
def get_search_connection_id(project) -> str:
    conn = project.connections.get_default(ConnectionType.AZURE_AI_SEARCH)
    return conn.id

def build_knowledge_tool(*, connection_id=None, project=None):
    # …resolve connection_id if not supplied…
    return FoundryChatClient.get_azure_ai_search_tool(
        index_connection_id=connection_id,
        index_name=settings.search_index,   # clm-corpus
        query_type="semantic",
        top_k=5,
    )
```
```bash
python src/kb_setup.py
```
✅ **You should see** (ids will differ):
```text
✓ Default Azure AI Search connection: /subscriptions/.../connections/clm-search
✓ Index: clm-corpus
✓ Built Foundry Azure AI Search grounding tool (semantic, top_k=5).
```

The demo agent runs **in-process** (`FoundryChatClient`), so it does not appear in portal → Agents/Playground. To get the Playground path, publish it as a persistent Foundry agent: `python src/agents/publish_agent.py` (`--list` / `--delete` to manage). Grounded Q&A/drafting/refusal work in the Playground; `get_contract_status` stays client-side.

> 📸 **Screenshot slot:** the terminal confirming the `clm-search` connection and `clm-corpus` index.
>
> <img src="../../images/challenge-02/steps/01-kb-setup-ok.svg" alt="Screenshot slot: kb_setup OK" width="80%">

### Task 2 · The agent definition (the answer)
The whole agent is ~15 lines — grounding tool **plus** a function tool, with the model as the only deployment-specific line. From [`src/agents/intake_drafting_agent.py`](../../src/agents/intake_drafting_agent.py):
```python
# src/agents/intake_drafting_agent.py
def create_agent(model=None, *, connection_id=None):
    knowledge = build_knowledge_tool(connection_id=connection_id)   # grounding over clm-corpus
    return Agent(
        client=build_chat_client(model or settings.model_drafting),  # ← "gpt-5.4"; swap for another GPT deployment id, nothing else changes
        name=AGENT_NAME,
        instructions=INSTRUCTIONS,                                   # persona + citations + refusal policy
        tools=[knowledge, function_tool(get_contract_status)],       # unstructured grounding + structured lookup
    )
```
The guardrail lives in `INSTRUCTIONS` (prompt layer):
```text
GUARDRAILS (must follow)
- You are NOT a lawyer and must NOT provide legal advice … refuse briefly and
  recommend review by qualified counsel.
GROUNDING & CITATIONS
- Base every substantive answer on retrieved corpus content … ALWAYS cite the source documents.
```

### Task 3 · Run the agent end-to-end
```bash
python src/agents/intake_drafting_agent.py
```
The four built-in prompts cover **draft · cited Q&A · function-tool lookup · refusal**:
```text
✓ Built intake-drafting-agent on model 'gpt-5.4'

USER: Draft a mutual NDA between Contoso Global and Northwind Traders...
AGENT: MUTUAL NON-DISCLOSURE AGREEMENT ... [approved template, no invented terms]

USER: What is our standard limitation-of-liability position?
AGENT: Our standard position caps liability at ... [CL-04] (cited from the clause library)

USER: What's the status of contract CT-4821?
AGENT: CT-4821 (Acme Corp, MSA) is Active, renews 2026-09-01... [from get_contract_status]

USER: Should we accept this indemnity clause? What's your legal opinion?
AGENT: I can't provide legal advice. Please consult qualified counsel... [refusal guardrail]
```

> 📸 **Screenshot slot:** the 4-prompt demo (draft · cited Q&A · tool call · refusal).
>
> <img src="../../images/challenge-02/steps/02-agent-demo.svg" alt="Screenshot slot: 4-prompt demo" width="80%">

### Task 4 · Exercise every capability
Work through [`src/sample_prompts.md`](../../src/sample_prompts.md). The `get_contract_status` tool returns real, structured fields (dates computed relative to today, so yours differ):
```json
{"contract_id": "CT-4821", "counterparty": "Acme Corp", "type": "MSA",
 "status": "Active", "renewal_date": "<~55 days out>", "auto_renew": true,
 "notice_days": 90, "risk": "High", "owner": "legal@contoso.com",
 "_note": "(source: contracts_seed.json)"}
```

> 📸 **Screenshot slot:** the Foundry **Playground** with the agent giving a grounded, cited answer.
>
> <img src="../../images/challenge-02/steps/03-portal-playground.svg" alt="Screenshot slot: Foundry Playground" width="80%">

### Task 5 · (Optional) Content safety
Attach **Prompt Shields / PII** to the agent in the portal — a second, model-independent guardrail layer on top of the prompt-level refusal (built out in Challenge 6).

## Key files

| Path | Role |
|------|------|
| [`src/agents/intake_drafting_agent.py`](../../src/agents/intake_drafting_agent.py) | The grounded, tool-using, guard-railed drafting agent (gpt-5.4) |
| [`src/kb_setup.py`](../../src/kb_setup.py) | Builds the Foundry IQ knowledge source + web-grounding tool over `clm-corpus` |
| [`src/sample_prompts.md`](../../src/sample_prompts.md) | Prompts to exercise drafting, grounded Q&A, and the guardrails |
| [`src/clm_common/`](../../src/clm_common/) | Shared config + Foundry client helpers reused by every agent |

## Run it

```bash
python src/kb_setup.py                       # prints the Search connection id + clm-corpus index
python src/agents/intake_drafting_agent.py   # drafts + answers with citations
```

## Common issues

| Symptom | Cause / fix |
|---------|-------------|
| No citations returned | Confirm the `clm-corpus` index is populated (Challenge 1's `seed_corpus.py`). |
| Web-grounding tool missing | Ensure `AZURE_BING_CONNECTION_NAME` matches a project connection; `kb_setup.py` reports whether it built. |
