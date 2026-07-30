# Challenge 2 · Grounded Agent with Foundry IQ + Tools

**[🏠 Home](../README.md)**  ·  [← Challenge 1: Setup](challenge-01.md)  ·  [Challenge 3: Observability →](challenge-03.md)

Welcome to your first agent! In Challenge 1 you provisioned Microsoft Foundry and seeded the
**Contoso Global** contract corpus. Now you'll turn that corpus into a working assistant: the
**Intake & Drafting agent** — a grounded, cited, tool-enabled, guard-railed agent that drafts
contracts from approved templates and answers policy questions **with sources**. It runs on
**Anthropic Claude Opus 4.8**, and the twist you'll internalize here is that grounding it on Claude
takes the *exact same code* as grounding it on GPT — because Foundry is a **model-agnostic control
plane**.

If something isn't working as expected, please let your coach know.

> **⏱️ Duration:** ~60 min

> **📋 Prerequisites:**
> - **Challenge 1 complete** — `.env` populated, corpus seeded into Azure AI Search, smoke test green.
> - A model deployment for **`claude-opus-4-8`** (created in Challenge 1) reachable from your project.

> 🧩 **How to use this challenge:** the code in this folder is a **complete, working reference
> implementation** — you're not building it from a blank file. **Run it, read it, and understand *why*
> it works**, then take it further with **🚀 Go Further**. Stuck? The code *is* the answer key.

---

## 🎯 Objective

Build the **Intake & Drafting agent** on **Anthropic Claude Opus 4.8** and make it:

- **Grounded** — every substantive answer is drawn from the CLM corpus via **Foundry IQ**, not the
  model's parametric memory.
- **Cited** — answers reference the source documents they came from.
- **Tool-enabled** — a **function tool** (`get_contract_status`) performs structured lookups the model
  must not guess.
- **Guard-railed** — the agent **refuses** to give legal advice and flags policy deviations for human
  review.

## 🧩 What you'll build

| Component | What it is | Where it lives |
|-----------|-----------|----------------|
| **Knowledge tool (Foundry IQ)** | An `AzureAISearchTool` over the `clm-corpus` index — grounds the agent on Contoso's templates, clauses, policy and contracts | [`kb_setup.py`](../src/kb_setup.py) → `build_knowledge_tool()` |
| **Function tool** | `get_contract_status(contract_id)` — deterministic lookup of status, renewal date, risk and owner (Azure SQL, falling back to seed JSON) | [`src/clm_common/tools.py`](../src/clm_common/tools.py) |
| **Guard-railed persona** | Instructions that force citations, forbid invented terms, and refuse legal advice | `INSTRUCTIONS` in [`agents/intake_drafting_agent.py`](../src/agents/intake_drafting_agent.py) |
| **Claude-backed agent** | The same Agent Framework API as GPT, with `model` pointed at the Claude deployment | `create_agent()` in [`agents/intake_drafting_agent.py`](../src/agents/intake_drafting_agent.py) |
| **A repeatable demo** | Builds the agent, runs four prompts (draft · cited Q&A · tool call · refusal) in one session | `main()` in [`agents/intake_drafting_agent.py`](../src/agents/intake_drafting_agent.py) |

## 🧭 Context and Background

### How grounding works — the Foundry IQ chain

**Foundry IQ** is how you ground an agent on *your* knowledge. You never hand the model a pile of
documents; instead you attach a **knowledge base** as a **tool**, and the agent performs **agentic
retrieval** — it plans sub-queries, searches, reranks, and returns **cited** passages — during a run.

![Foundry IQ architecture — knowledge sources feed the Foundry IQ grounding layer (knowledge sources, access rules, retrieval logic, agentic retrieval), which an AI agent/Copilot queries to produce grounded, cited, permission-checked responses](../images/diagrams/foundry-iq-architecture.png)

*The general Foundry IQ picture: trusted enterprise knowledge → the grounding layer → an agent → a grounded, cited answer. The diagram below shows how **this microhack** instantiates that chain for contracts.*

```mermaid
flowchart TB
  A["Corpus in SharePoint library<br/>templates · clauses · policy · contracts"] --> B["Azure AI Search index · clm-corpus<br/>semantic · separate service (backing store)"]
  B --> D
  subgraph IQ["Foundry IQ — knowledge grounding"]
    D["AzureAISearchTool<br/>agentic retrieval: plan → search → rerank → cite<br/>kb_setup.py"]
  end
  D --> E["Intake &amp; Drafting agent<br/>Claude Opus 4.8"]
  F["get_contract_status<br/>function tool"] --> E
  E --> G["Cited draft / answer<br/>+ tool results"]
  style D fill:#FCEBDD,stroke:#E8590C,stroke-width:2px,color:#1A1A1A
  style E fill:#EDE4F5,stroke:#7A4FB5,stroke-width:2px,color:#1A1A1A
  style F fill:#FCEBDD,stroke:#E8590C,stroke-width:2px,color:#1A1A1A
```

The index itself was built in **Challenge 1** by `src/scripts/seed_corpus.py`. In this challenge you
simply **attach it** as a tool and let the agent retrieve from it.

### Two kinds of tools

An agent grounds and acts through **tools**. This agent has both flavors:

- **Knowledge tool** (`AzureAISearchTool`) — for *unstructured* knowledge: "what does our standard
  limitation-of-liability clause say?" Answered from the corpus, **with citations**.
- **Function tool** (`get_contract_status`) — for *structured* facts the model must never hallucinate:
  "what's the renewal date of `CT-4821`?" The Agent Framework generates the tool's JSON schema **from the
  Python type hints + docstring**, and `function_tool(...)` (`approval_mode="never_require"`) runs the
  function automatically mid-run.

> [!NOTE]
> Because the schema is derived from the function signature and docstring, **keeping good type hints
> and a clear docstring is not optional** — they *are* the tool contract the model sees.

### Why Claude here — and why the API doesn't change

Drafting rewards strong instruction-following and long-context legal reasoning, so the Intake &
Drafting agent runs on **Claude Opus 4.8** (`MODEL_DRAFTING`). The whole point of Foundry as a
control plane is that you get there by pointing `model` at the Claude deployment — **the
agent/tool/grounding API is identical across providers**. The same `Agent(client=..., tools=[...]) →
run` shape hosts a GPT agent (you'll see that in Challenge 4's orchestrator) with no other changes.

### Guardrails at the prompt layer

The `INSTRUCTIONS` block encodes Contoso's policy: never invent legal terms, always cite, call the
tool for contract facts, and **refuse legal advice** (recommend qualified counsel instead). That's
the first line of defense; content-safety policies (Challenge 6) add a second, independent one.

### The knowledge base — what actually grounds the agent

Everything the agent "knows" comes from the corpus you seeded in Challenge 1:

| Corpus source | Contents | Role in Challenge 2 |
|---------------|----------|---------------------|
| [`src/data/contract_templates/`](../src/data/contract_templates/) | Approved **NDA / MSA / SOW** templates (PDF) | Drafting source — the agent fills placeholders, never invents terms |
| [`src/data/clause_library/`](../src/data/clause_library/) | Enterprise-standard positions **CL-01…CL-12** (PDF) | Cited answers about standard clauses (e.g. the liability cap) |
| [`src/data/policies/`](../src/data/policies/) | Approval thresholds + the **no-legal-advice** rule (plus a delegation-of-authority matrix) | Grounds policy answers; reinforces the guardrail |
| [`src/data/policies/delegation_of_authority.pdf`](../src/data/policies/delegation_of_authority.pdf) | **Approval thresholds / signature-authority matrix** | States **who must approve** a term/draft by role/threshold — the agent never self-approves |
| [`src/data/playbooks/negotiation_playbook.pdf`](../src/data/playbooks/negotiation_playbook.pdf) | **Fallback / escalation positions** | Supplies the approved **fallback positions** to offer, in order, when a term deviates from standard |
| [`src/data/contracts/`](../src/data/contracts/) | **5 executed contract PDFs** (text-extractable) | Grounding + narrative basis for status lookups |
| [`src/data/contracts_seed.json`](../src/data/contracts_seed.json) | Structured metadata for the same 5 contracts | Backs `get_contract_status` (SQL fallback) |

### Files in this challenge

| File | What it does |
|------|--------------|
| [`kb_setup.py`](../src/kb_setup.py) | Resolves the project's **default Azure AI Search connection** and builds the `AzureAISearchTool` (the Foundry IQ knowledge base). Run it standalone to verify grounding is wired up. |
| [`agents/intake_drafting_agent.py`](../src/agents/intake_drafting_agent.py) | Defines the agent (persona, guardrails, knowledge + function tools) and runs a four-prompt demo. Agents are built in-process — nothing persists server-side. |
| [`sample_prompts.md`](../src/sample_prompts.md) | Curated prompts that exercise every capability: grounded drafting, cited Q&A, the function tool, and the refusal guardrail. |

## 🧰 Services & models in this challenge

This agent is small, but every line stands on a concrete resource — the exact ones `azd up` provisioned in
Challenge 1 ([`labautomation/infra/resources.bicep`](../labautomation/infra/resources.bicep)). Here's **what
each is**, the **specifics wired into this repo**, and **why it's in the architecture**.

### Microsoft Foundry — AI Services account + model runtime

**What it is:** the managed **control plane + model runtime**. Challenge 1 creates one
`Microsoft.CognitiveServices` account (`kind: AIServices`, SKU `S0`) holding a project **`clm-project`**;
your `.env` reaches it through `AZURE_AI_PROJECT_ENDPOINT`
(`https://<account>.services.ai.azure.com/api/projects/clm-project`).

- **All four models deploy onto that one account** — `gpt-5.4`, `gpt-5.6-sol`, `gpt-5-mini`, `claude-opus-4-8` — so a
  single `get_project_client()` ([`src/clm_common/foundry.py`](../src/clm_common/foundry.py)) reaches each.
- The **Microsoft Agent Framework** (`Agent(client=FoundryChatClient(...))`) runs the agent loop **in your
  process** — planning, tool-calls and retrieval — calling Foundry for model inference.
- The project also owns the grounding **`clm-search` connection** and the RBAC that makes retrieval keyless.

**Why here:** you build a grounded, tool-using **Claude** agent in ~15 lines, and moving to GPT is a
one-argument change (`model=`). → [Microsoft Agent Framework](https://learn.microsoft.com/agent-framework/overview/agent-framework-overview)

### Foundry IQ — agentic retrieval (`AzureAISearchTool`)

**What it is:** the **grounding layer**. [`kb_setup.py`](../src/kb_setup.py) resolves the project's default Search
connection and builds `AzureAISearchTool(index_name="clm-corpus", query_type=SEMANTIC, top_k=5)`; you attach
it as a tool and the agent runs **plan → search → rerank → cite** during a run.

- Rides the project → Search connection **`clm-search`** (`category: CognitiveSearch`, **AAD** auth, shared).
- The Foundry **account _and_ project** managed identities each hold **Search Index Data Reader** (query) +
  **Search Service Contributor** (read the index / semantic-config), so retrieval needs no keys.
- Returns the **top 5** semantically-reranked passages **with citations** — not one raw similarity hit.

**Why here:** it's what makes answers come from **Contoso's corpus, with sources**, not model memory.
→ [Agentic retrieval](https://learn.microsoft.com/azure/search/search-agentic-retrieval-concept)

### Azure AI Search — the `clm-corpus` index

**What it is:** the **retrieval engine** behind Foundry IQ. Challenge 1 provisions a **`basic`** search
service (1 partition · 1 replica, `semanticSearch: free`), and `src/scripts/seed_corpus.py` creates a
**SharePoint Online indexer** that crawls the corpus library and populates the index (no manual upload).

- Index **`clm-corpus`**, semantic config **`clm-semantic`**, fields `id` · `title` · `content` · `source`.
- **Full-text + semantic (L2) re-ranking** over **one document per file** (`content` = the extracted PDF text).
- Built once in Ch0 — here you only **attach** and query it.

**Why here:** it's the searchable store that turns "the model guesses" into "the agent cites `CL-04`".
→ [Azure AI Search](https://learn.microsoft.com/azure/search/)

### SharePoint — corpus source of truth

**What it is:** the **document library** the original contract PDFs live in (Microsoft 365). It's the
system of record; the corpus is authored/managed there, not copied into Azure.

- `seed_corpus.py` creates an Azure AI Search **SharePoint Online data source + indexer** that crawls
  the library into `clm-corpus` (app-only Microsoft Entra auth via a prerequisite app registration).
- The indexer extracts each PDF's text + metadata; re-running it re-crawls for changes.

**Why here:** it holds the templates, clause library, policy and executed-contract PDFs that Search indexes —
and keeps them where the business already curates them. → [Index SharePoint content](https://learn.microsoft.com/azure/search/search-howto-index-sharepoint-online)

### Model — Anthropic Claude Opus 4.8

**What it is:** this agent's LLM — deployment **`claude-opus-4-8`** (`format: Anthropic`, **version `2`** =
Azure-hosted, SKU `GlobalStandard`, capacity 20), read from `settings.model_drafting` (`MODEL_DRAFTING`).

- Strong **instruction-following** + **long-context** reasoning — ideal for careful legal drafting.
- Called through the **same Agents API** as the GPT deployments; only the deployment name differs.

**Why here:** drafting goes to Claude; routing/tool-calling to **`gpt-5.4`** (Ch3) and the renewal scan to
**`gpt-5-mini`** (Ch4) — right model per job, one platform. → [Models in Microsoft Foundry](https://learn.microsoft.com/azure/ai-foundry/)

### Function tools — `get_contract_status`

**What it is:** plain Python in [`src/clm_common/tools.py`](../src/clm_common/tools.py) exposed as a tool.
`get_contract_status(contract_id: str) -> str` returns a JSON string; the Agent Framework derives the tool's
schema from the **type hints + docstring**, and `function_tool(...)` runs it automatically mid-run.

- **Prefers Azure SQL** (`SELECT … FROM dbo.contracts` via pyodbc) when `AZURE_SQL_CONNECTION_STRING` is set,
  else falls back to [`src/data/contracts_seed.json`](../src/data/contracts_seed.json) — the
  reply's `_note` tells you which source answered.
- Ships a second tool, `list_upcoming_renewals(within_days=90)`, ready for the **🚀 Go Further** step.

**Why here:** structured facts (status, renewal date, risk, owner) come from a **lookup**, never a guess —
the knowledge tool grounds *unstructured* answers, this grounds *structured* ones.
→ [Function calling with Foundry agents](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/tools/function-calling)

## ✅ Tasks

### Task 1 · Verify the knowledge connection (~10 min)

Confirm the default Azure AI Search connection resolves and the index is present:

```bash
python src/kb_setup.py
```

Expected output (ids will differ):

```text
✓ Default Azure AI Search connection: /subscriptions/.../connections/clm-search
✓ Index: clm-corpus
✓ Built Foundry Azure AI Search grounding tool (semantic, top_k=5).
```

> 📸 **Screenshot slot — what you'll see:** the terminal confirming the `clm-search` connection and `clm-corpus` index.
>
> <img src="../images/challenge-02/steps/01-kb-setup-ok.svg" alt="Screenshot slot: kb_setup OK" width="80%">

> [!TIP]
> If the connection doesn't resolve, it's almost always a Challenge 1 gap — see **Troubleshooting**.

### Task 2 · Read the agent definition (~15 min)

Open [`agents/intake_drafting_agent.py`](../src/agents/intake_drafting_agent.py) and trace how it's wired:

- `model=settings.model_drafting` → **Claude Opus 4.8** (the only line that would change for GPT).
- The persona + **refusal** instructions in `INSTRUCTIONS`.
- Grounding via `build_knowledge_tool(...)` **plus** the `get_contract_status` **function tool**,
  passed together in the Agent's `tools=[...]`.
- `function_tool(...)` wraps the function with `approval_mode="never_require"` so it auto-executes during a run.

<details>
<summary><strong>🔬 Anatomy of the agent</strong> — the wiring in ~15 lines</summary>

```python
from agent_framework import Agent
from clm_common.foundry import build_chat_client, function_tool
from kb_setup import build_knowledge_tool
from clm_common.tools import get_contract_status

knowledge = build_knowledge_tool(connection_id=connection_id)   # Azure AI Search grounding over clm-corpus

agent = Agent(
    client=build_chat_client(settings.model_drafting),          # ← "claude-opus-4-8"; swap for a GPT id, nothing else changes
    name="intake-drafting-agent",
    instructions=INSTRUCTIONS,                                  # persona + citations + refusal policy
    tools=[
        knowledge,                                              # unstructured grounding (Foundry IQ)
        function_tool(get_contract_status),                     # structured lookups, approval_mode="never_require"
    ],
)
```

A single run then does: `agent.run(prompt, session=session)` — the agent plans, retrieves,
optionally calls `get_contract_status`, and drafts — then returns the assistant's text. The
`run_agent` / `run_prompt` helpers live in [`src/clm_common/foundry.py`](../src/clm_common/foundry.py).
</details>

### Task 3 · Run the agent end-to-end (~10 min)

This builds the agent and runs four demo prompts in one shared session:

```bash
python src/agents/intake_drafting_agent.py
```

The four built-in prompts deliberately cover all four behaviors — a **draft**, a **cited** clause
Q&A, a **`CT-4821` status** lookup (function tool), and a **legal-advice** prompt that must be
**refused**.

✅ **You should see** (the model's wording varies — the **structure** is what matters):

```text
✓ Built intake-drafting-agent on model 'claude-opus-4-8'

――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
USER: Draft a mutual NDA between Contoso Global and Northwind Traders...
AGENT: MUTUAL NON-DISCLOSURE AGREEMENT ... [uses the approved template, no invented terms]

――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
USER: What is our standard limitation-of-liability position?
AGENT: Our standard position caps liability at ... [CL-04] (cited from the clause library)

――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
USER: What's the status of contract CT-4821?
AGENT: CT-4821 (Acme Corp, MSA) is Active, renews 2026-09-01... [from get_contract_status]

――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
USER: Should we accept this indemnity clause? What's your legal opinion?
AGENT: I can't provide legal advice. Please consult qualified counsel... [refusal guardrail]
```

> 📸 **Screenshot slot — what you'll see:** the 4-prompt demo (draft · cited Q&A · tool call · refusal).
>
> <img src="../images/challenge-02/steps/02-agent-demo.svg" alt="Screenshot slot: 4-prompt demo" width="80%">

> [!NOTE]
> The agent is built in-process each run via the Microsoft Agent Framework — there's no server-side
> agent id to manage or clean up. Later challenges simply call `create_agent(...)` again.

### Task 4 · Exercise every capability (~15 min)

Work through [`sample_prompts.md`](../src/sample_prompts.md) — via the demo script, the portal **Playground**,
or your own thread. Each section maps to one capability, and the file's *"What good looks like"* table
tells you the expected behavior:

> 📸 **Screenshot slot — what you'll see:** the Foundry **Playground** with the agent giving a grounded, cited answer.
>
> <img src="../images/challenge-02/steps/03-portal-playground.svg" alt="Screenshot slot: Foundry Playground" width="80%">

| Prompt type | Expected behavior |
|-------------|-------------------|
| **Drafting** | Uses the approved template structure; fills only provided details; **no invented terms** |
| **Cited Q&A** | Answer grounded in the corpus **with citations**; says "not in corpus" if unknown |
| **Function tool** | Calls `get_contract_status`; returns **real fields** for `CT-4821` |
| **Legal advice** | **Brief refusal** + recommends qualified counsel |

For the tool call, `CT-4821` should come back with concrete, structured data. The
`renewal_date`/`effective_date` are **computed relative to today** (the seed stores
day-offsets so "upcoming renewals" demos never go stale), so your dates will differ:

```json
{"contract_id": "CT-4821", "counterparty": "Acme Corp", "type": "MSA",
 "status": "Active", "renewal_date": "<~55 days out>", "auto_renew": true,
 "notice_days": 90, "risk": "High", "owner": "legal@contoso.com",
 "_note": "(source: contracts_seed.json)"}
```

### Task 5 · (Optional) Add content safety (~10 min)

In the portal, attach **Prompt Shields / PII** guardrails to the agent, or discuss where they'd sit.
The refusal instructions already enforce the no-legal-advice policy at the prompt layer — content
safety adds a second, model-independent layer (previewed here, built in **Challenge 6**).

### ⚙️ Claude fallback (if Foundry can't serve Claude via the chat client in your region)

The **preferred** path is `model="claude-opus-4-8"` on `build_chat_client(...)`, exactly like GPT. If that
run fails because Foundry doesn't yet serve Anthropic models through the chat client in your region, call
Claude **directly** through Foundry with the Anthropic SDK and keep grounding/tools in your own code:

```python
from anthropic import AnthropicFoundry           # pip: anthropic (already in requirements.txt)
from clm_common.config import settings, credential

token = credential().get_token("https://cognitiveservices.azure.com/.default").token
client = AnthropicFoundry(
    base_url=settings.project_endpoint.split("/api/projects")[0],   # the AI Services endpoint
    api_key=token,                                                  # Entra token as bearer
)
msg = client.messages.create(
    model=settings.model_drafting,
    max_tokens=1024,
    messages=[{"role": "user", "content": "Draft a mutual NDA…"}],
)
print(msg.content[0].text)
```

You'd then do retrieval (Azure AI Search) and the contract-status lookup yourself and pass the results
into the prompt. Prefer the native agent path when available — this is only a safety net.

## ✔️ Success criteria

You're done when:

- [ ] `python src/kb_setup.py` prints the Search connection id **and** the `clm-corpus` index.
- [ ] Cited answers are drawn from the corpus (you can see the source documents).
- [ ] The `get_contract_status` tool is invoked for `CT-4821` and returns real fields.
- [ ] The legal-advice prompt is **refused** with a recommendation to consult counsel.
- [ ] The agent is running on the **Claude** deployment (confirm the model name in the portal).

## 🚀 Go Further

- Add a **Web IQ (Bing)** grounding tool for external / regulatory lookups.
- Add a second knowledge base scoped to a single contract type and compare retrieval quality.
- Tighten the persona so every draft includes a **"⚠️ requires human review"** banner.
- Add a second function tool (e.g. `list_upcoming_renewals`, already in `clm_common.tools`) and watch
  the model choose between tools.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| `get_default(AZURE_AI_SEARCH)` returns nothing | Ensure Challenge 1 created the Search resource and connected it to the project (**portal → Connected resources**). Set `AZURE_SEARCH_CONNECTION_NAME` in `.env`. |
| No citations returned | Confirm `src/scripts/seed_corpus.py` populated the index and the semantic config exists; try raising `top_k` in `build_knowledge_tool`. |
| Function tool never called | Keep the docstring + type hints (the schema comes from them); ensure it's wrapped with `function_tool(...)` and passed in the Agent's `tools=[...]`, and the prompt actually asks for a specific contract. |
| `get_contract_status` says "not found" | Use a known id (`CT-4821`, `CT-3390`, `CT-5102`, `CT-2765`, `CT-6033`) — the error message lists them. |
| `TypeError: Object of type AzureAISearchToolResource is not JSON serializable` | The Foundry tool factory returns an SDK model, not a plain dict. `build_knowledge_tool` / `build_web_search_tool` now normalize it via `.as_dict()` before attaching — pull the latest `src/kb_setup.py`. |
| `400 tool_user_error … Access denied, check managed identity access to search service` | The Foundry **account _and_ project** managed identities each need **Search Index Data Reader** + **Search Service Contributor** on the Search service. The infra grants both now — re-run `labautomation/deploy-lab.ps1` (idempotent) or add the roles in the portal (Search service → Access control). |
| `429 rate_limit_exceeded` on `gpt-5.4` mid-demo | Deployment throughput throttling. The demo now retries with exponential backoff and isolates each prompt (`run_agent_with_retry`), so it rides through and continues. If it persists, raise the deployment capacity or space out prompts. |
| Run fails on Claude | Foundry may not serve Anthropic models via the chat client in your region yet — use the **Claude fallback** above. |
| `Missing required environment variable 'AZURE_AI_PROJECT_ENDPOINT'` | Re-run Challenge 1's deploy (which writes `.env`) or copy `.env.example` → `.env` and fill it in. |

## 🎯 What you accomplished

You built your first **grounded, cited, tool-using, guard-railed agent** — and did it on **Claude**
with the same API you'll use for GPT.

**Key achievements:**

- **Grounded on your corpus** — attached the Foundry IQ knowledge base as a tool so answers come from
  Contoso's documents, with citations, not model memory.
- **Mixed knowledge + function tools** — combined unstructured retrieval with a deterministic
  `get_contract_status` lookup in the Agent's `tools=[...]`, auto-invoked mid-run.
- **Enforced guardrails** — the agent refuses legal advice and flags policy deviations for a human.
- **Proved model-agnosticism** — ran the whole thing on Claude Opus 4.8 by changing a single
  `model` argument.

This agent becomes a building block later: the **orchestrator** (Challenge 4) will delegate drafting
to it, and everything it does will be **traced and evaluated** in Challenge 3.

## 📚 Learn more

- [Microsoft Foundry](https://learn.microsoft.com/azure/ai-foundry/)
- [Microsoft Agent Framework](https://learn.microsoft.com/agent-framework/overview/agent-framework-overview)
- [Function calling with Foundry agents](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/tools/function-calling)
- [Foundry IQ / agentic retrieval](https://learn.microsoft.com/azure/search/search-agentic-retrieval-concept)
- [Azure AI Search](https://learn.microsoft.com/azure/search/)

## 🧠 Reflection

- Why put **drafting** on Claude and **routing** on GPT? (Instruction-following & long-context legal
  reasoning vs. fast, deterministic tool-calling.)
- Where should guardrails live — in the prompt, as a content-safety policy, or both? What does each
  catch that the other misses?
- When should a fact come from a **function tool** vs. **retrieval**? What breaks if you let the model
  guess contract metadata?

---

⬅️ Back: **[Challenge 1 — Setup & Foundry Foundations](challenge-01.md)** ·
➡️ Next: **[Challenge 3 — Observability, Tracing & Evaluation](challenge-03.md)**
