# Challenge 1 - Build the Claims Intake Agent

[Home](../README.md)

**Expected Duration:** 45 minutes

## Overview
In this challenge, you will build the first production-facing agent in the workflow: the Claims Intake Agent.

The Claims Intake Agent must do two things in one flow:

1. Process a claim image using the `mistral-document-ai-2512` deployment.
2. Query Foundry IQ (backed by your crash statements index) to retrieve related statement evidence.

You will first create the agent itself using the Microsoft Foundry SDK, then give it its enterprise need — Foundry IQ grounding — by attaching an MCP tool that points at the knowledge base you create in Task 2. At the end of this challenge, you will have a single JSON intake artifact that combines OCR output plus retrieved crash statement context.

## Foundry IQ

## From Search Indexes to Foundry IQ

Enterprise RAG solutions have traditionally been built on Azure AI Search, where developers were responsible for managing search indexes, document ingestion pipelines, chunking strategies, vector embeddings, indexers, and retrieval logic. While this approach provides maximum flexibility, it also introduces operational complexity and requires significant effort to scale across multiple data sources and AI applications.

Foundry IQ builds on the proven retrieval capabilities of Azure AI Search, introducing a higher-level abstraction through **Knowledge Bases**. Rather than connecting agents directly to individual search indexes, developers can aggregate multiple knowledge sources—including SharePoint, Azure Blob Storage, OneLake, web content, and other enterprise systems—into a single reusable knowledge base. Foundry IQ automatically handles indexing, synchronization, retrieval planning, source selection, grounding, and security enforcement, enabling teams to focus on delivering business value instead of managing retrieval infrastructure.

In essence, Azure AI Search remains the underlying retrieval engine, while Foundry IQ provides the context engineering layer that transforms enterprise knowledge into AI-ready context for agents and applications. This evolution significantly reduces the complexity of building grounded AI solutions while enabling knowledge to be reused consistently across multiple agents and use cases. 

## Prerequisites

- Complete the participant setup in the [root README](../README.md).
- Confirm that the MicroHack platform or your event coach supplied the Azure
  resources and the values required by `.env.example`.
- Ensure your crash statements are indexed in Foundry IQ (for example, through your Azure AI Search index used by Foundry).


## Task 1: Populate the crash statements search index

The Claims Intake Agent's Foundry IQ tool queries an Azure AI Search index named `crash-statements`. [`infrastructure/azuredeploy.json`](../infrastructure/azuredeploy.json) already creates this index for you as part of the lab deployment, so you only need to load it with crash statement content before running the agent.

### The index schema

The `crash-statements` index is created with this schema:

```json
{
  "name": "crash-statements",
  "fields": [
    { "name": "id", "type": "Edm.String", "key": true, "filterable": true },
    { "name": "content", "type": "Edm.String", "searchable": true },
    { "name": "source_file", "type": "Edm.String", "filterable": true },
    { "name": "claimant_name", "type": "Edm.String", "searchable": true, "filterable": true },
    { "name": "policy_number", "type": "Edm.String", "filterable": true }
  ]
}
```

### Upload crash statement documents

Every claim's statement images under [`data/claims/`](../data/claims/) needs to be OCR'd and uploaded as a document so Foundry IQ has evidence for all five crashes, not just one. Run [`docs/index_crash_statements.py`](../docs/index_crash_statements.py) to do this for the whole folder in one pass:

```bash
cd docs
python index_crash_statements.py
```

The script walks every `data/claims/crash{1-5}/raw/statements/*.jpeg` file, runs Mistral Document AI OCR on each one, and uploads the result to the `crash-statements` index using the same `@search.action` upload shape shown below (one document per statement image, keyed by file name, for example `crash1_front`, `crash1_back`, `crash2_front`, and so on):

```json
{
  "value": [
    {
      "@search.action": "mergeOrUpload",
      "id": "crash1_front",
      "content": "Claimant: John Peterson. Policy: C1A8-AU1D-001. Claim date: July 17, 2025. Vehicle: 2004 Honda Accord, VIN 1HGCM56404A123456, plate OH-GHR1984. Incident: On the morning of July 17, 2025, my vehicle was legally parked in a market parking space at 2325 Rain Street, Springfield...",
      "source_file": "crash1_front.jpeg",
      "claimant_name": "John Peterson",
      "policy_number": "C1A8-AU1D-001"
    }
  ]
}
```

### Verify the index is populated

```bash
curl "$FOUNDRY_IQ_SEARCH_ENDPOINT/indexes/crash-statements/docs/\$count?api-version=2023-11-01" \
  -H "api-key: $FOUNDRY_IQ_SEARCH_KEY"
```

This call should return a count of `10` (one document per statement image across all five crashes) before you continue to Task 2.

## Task 2: Understand Foundry IQ knowledge bases, then create one

A raw Azure AI Search index is just a searchable document store. Querying it well — writing filters, choosing a query type, ranking results — is work your application (or the agent) has to do itself every time. Foundry IQ takes a different approach: it puts a managed retrieval layer on top of one or more indexes, so the agent can ask a question in natural language and let Azure AI Search plan and execute the query for it. That managed layer is built from two objects:

- **Knowledge source** — a reusable reference to a data source. In this challenge its kind is `searchIndex`, meaning it wraps the `crash-statements` index you just populated: which fields are searchable, which are returned in results, and which semantic configuration to rank with. A knowledge source doesn't hold data itself; it just describes how to read from something that does.
- **Knowledge base** — the object your agent actually talks to. It references one or more knowledge sources (here, just the one) and exposes a single retrieval endpoint — including an MCP (Model Context Protocol) endpoint — that a Foundry agent can call as a tool. The knowledge base is what turns "search this index" into "ask this knowledge base a question."

In short: **index → knowledge source (wraps the index) → knowledge base (orchestrates retrieval, exposes MCP) → agent tool**. The index still holds your crash statement content; the knowledge base is the new grounding surface the agent will call in Task 4, replacing direct index queries with an MCP-based retrieval tool.

### Create the knowledge source and knowledge base

Run [`docs/create_knowledge_base.py`](../docs/create_knowledge_base.py):

```bash
cd docs
python create_knowledge_base.py
```

This script does three things against the `crash-statements` index:

1. **Makes fields retrievable and adds a semantic configuration.** The index created in Task 1 only marks `id` as retrievable — a knowledge source needs every field it returns (`content`, `source_file`, `claimant_name`, `policy_number`) to be retrievable, and agentic retrieval requires a semantic configuration to rank results. Both attributes can be changed on an existing index without rebuilding it.
2. **Creates a `SearchIndexKnowledgeSource`** named `crash-statements-ks` that wraps the index, using the new semantic configuration and the fields listed above.
3. **Creates a `KnowledgeBase`** named `crash-statements-kb` that references that knowledge source, and prints its MCP endpoint:

   ```text
   https://<your-search-service>.search.windows.net/knowledgebases/crash-statements-kb/mcp?api-version=2026-04-01
   ```

### Verify the knowledge base retrieves crash statements

```bash
curl -X POST "$FOUNDRY_IQ_SEARCH_ENDPOINT/knowledgebases/crash-statements-kb/retrieve?api-version=2026-04-01" \
  -H "api-key: $FOUNDRY_IQ_SEARCH_KEY" -H "Content-Type: application/json" \
  -d '{"intents": [{"type": "semantic", "search": "John Peterson crash statement"}]}'
```

This should return a `response` array whose text content includes crash statement matches for `crash1_front.jpeg` (and any other statement mentioning John Peterson) before you continue to Task 3.

## Task 3: Understand how the agent is created with the Foundry SDK (no action required)

Before giving the agent any enterprise data, look at how it is created. `docs/claims-intake-agent.py` uses the `azure-ai-projects` SDK to register the agent as a first-class Foundry resource, instead of calling a chat completion API directly:

```python
client = AIProjectClient(endpoint=project_endpoint, credential=DefaultAzureCredential(), allow_preview=True)

definition = PromptAgentDefinition(
    model=model_deployment,
    instructions=FOUNDRY_AGENT_INSTRUCTIONS,
)
client.agents.create_version(agent_name=FOUNDRY_AGENT_NAME, definition=definition)
```

Key points:

- `PromptAgentDefinition` describes the agent's model, instructions, and, in Task 4, the tools it uses for grounding.
- `client.agents.create_version(...)` registers the agent in your Foundry project so it can be reused across runs, versioned, and inspected in the Foundry portal.
- `_ensure_foundry_agent()` in the script checks `client.agents.get(FOUNDRY_AGENT_NAME)` first and only creates a new version if the agent doesn't already exist, so re-running the script won't create duplicate agents.
- The agent is invoked through `client.get_openai_client(agent_name=...)`, which returns an OpenAI-compatible client whose `responses.create(...)` call runs the named agent.

At this point the agent can already summarize OCR text using the model alone — it has no grounding in your crash statement evidence yet. That's the enterprise need you'll add next.

## Task 4: Understand how Foundry IQ grounding is added through a knowledge base (no action required)

A generic model has no way to know about your organization's crash statement evidence. This section walks through how the agent is connected to Foundry IQ through the knowledge base you created in Task 2, so its answers are grounded in the index you populated in Task 1.

```python
def _build_foundry_iq_tool(client: AIProjectClient, knowledge_base_name: str) -> MCPTool:
  return MCPTool(
    server_label="knowledge-base",
    server_url=f"{search_endpoint}/knowledgebases/{knowledge_base_name}/mcp?api-version=2026-04-01",
    require_approval="never",
    allowed_tools=["knowledge_base_retrieve"],
    project_connection_id=project_connection_name,
  )
```

Key points:

- The knowledge base exposes an MCP endpoint, and the agent connects to that endpoint through an `MCPTool` instead of querying the search index directly.
- `project_connection_id` points to the Foundry project connection that knows how to reach the knowledge base.
- `allowed_tools=["knowledge_base_retrieve"]` keeps the agent focused on retrieval only.
- The agent's instructions should still tell the model to use the knowledge-base tool before answering, because tool use by an LLM is discretionary by default.

With the tool attached, the agent now retrieves real crash statement evidence from the knowledge base before summarizing each new OCR result — this is the enterprise capability that turns a generic summarizer into a grounded Claims Intake Agent.

## Task 5: Run the Claims Intake Agent

Use an accident statement form image under `data/claims/{claim-id}/raw/statements/`, not the reference photos in `data/claims/{claim-id}/raw/vehicle-damage/`. The `raw/vehicle-damage/*.jpg` files are generic damage photos with no text, so OCR on them produces no usable content and Foundry IQ returns zero matches. The `raw/statements/*_front.jpeg` and `*_back.jpeg` files contain the actual handwritten claim forms that match the indexed crash statement content.

```bash
cd docs
python claims-intake-agent.py ../data/claims/crash1/raw/statements/crash1_front.jpeg
```

Optional output path:

```bash
python claims-intake-agent.py ../data/claims/crash1/raw/statements/crash1_front.jpeg --output ../challenges/intake_result_crash1.json
```

## Task 6: Optional, connect Foundry to the blob storage account

The lab deployment creates a Storage account with a `claims-data` container that can hold claim images and documents for direct processing from Foundry, instead of relying only on local files. If you want to validate the setup in the Foundry portal, connect this Storage account to your Foundry project so agents and tools in the portal can read from it.

1. Open the [Azure AI Foundry portal](https://ai.azure.com) and select your project (for example, `msagthack-aiproject-<suffix>`).
2. In the left navigation, go to **Management Center** > **Connected resources**.
3. Select **+ New connection**.
4. Choose **Azure Blob Storage** as the connection type.
5. Select the Storage account supplied with your lab (named
  `msagthacksa<suffix>` and identified by `AZURE_STORAGE_ACCOUNT_NAME` in the
  platform credentials).
6. Set the authentication method to **Microsoft Entra ID** (recommended) or **API key**, then confirm the connection name (for example, `claims-data-storage`).
7. Select **Add connection** to finish.
8. Verify the connection appears under **Connected resources** with a status of **Connected**.

With this connection in place, Foundry can list and read blobs from the `claims-data` container directly, so you can point future tasks and agents at blob paths instead of copying files locally first. [Challenge 2](./challenge-02.md) builds on this same pattern — creating an agent with the SDK, then giving it an enterprise need — using your Storage account's `policies` container instead of Foundry IQ.

## What the agent does

1. Encodes the claim image and sends it to Mistral Document AI OCR.
2. Extracts OCR text from the API response.
3. Creates (or reuses) the `claims-intake-agent` Foundry agent, with the Foundry IQ tool attached.
4. Runs the agent to query Foundry IQ's crash statements corpus and summarize the match.
5. Produces a combined intake JSON payload:
   - OCR metadata
   - Raw OCR text
   - Top crash statement matches
   - Agent summary, trace metadata, and timestamp

## Expected output shape

```json
{
  "status": "success",
  "image_path": "...",
  "ocr": {
    "model": "mistral-document-ai-2512",
    "character_count": 1234,
    "text": "..."
  },
  "foundry_iq": {
    "index_name": "crash-statements",
    "match_count": 3,
    "matches": [
      {
        "id": "crash3_front",
        "content": "...",
        "score": 0.88
      }
    ]
  },
  "foundry_agent": {
    "name": "claims-intake-agent"
  },
  "agent_summary": "..."
}
```

## Validation checklist

- OCR call succeeds with `status: success`.
- The `claims-intake-agent` agent appears under your Foundry project's agents (visible via the SDK or the Foundry portal).
- At least one crash statement match is returned from Foundry IQ.
- Output JSON is created and contains `ocr`, `foundry_iq`, and `agent_summary` sections.
- The Storage account connection appears under **Connected resources** in the Foundry portal with a status of **Connected**.

## Next step

Continue with [Challenge 2](./challenge-02.md) to expand document processing and vectorized search patterns.

