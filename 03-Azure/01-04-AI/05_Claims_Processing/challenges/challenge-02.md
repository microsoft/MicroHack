# Challenge 2 - Build the Claims Intake Agent

[Home](../README.md)

**Expected Duration:** 45 minutes

## Overview
In this challenge, you will build the first production-facing agent in the workflow: the Claims Intake Agent.

The Claims Intake Agent must do two things in one flow:

1. Process a claim image using the `mistral-document-ai-2512` deployment.
2. Query Foundry IQ (backed by your crash statements index) to retrieve related statement evidence.

You will first create the agent itself using the Microsoft Foundry SDK, then give it its enterprise need — Foundry IQ grounding — by attaching an MCP tool that points at the knowledge base you create in Task 2. At the end of this challenge, you will have a single JSON intake artifact that combines OCR output plus retrieved crash statement context.

### Foundry IQ: From search indexes to knowledge bases

Enterprise RAG solutions have traditionally been built on Azure AI Search, where developers were responsible for managing search indexes, document ingestion pipelines, chunking strategies, vector embeddings, indexers, and retrieval logic. While this approach provides maximum flexibility, it also introduces operational complexity and requires significant effort to scale across multiple data sources and AI applications.

Foundry IQ builds on the proven retrieval capabilities of Azure AI Search, introducing a higher-level abstraction through **Knowledge Bases**. Rather than connecting agents directly to individual search indexes, developers can aggregate multiple knowledge sources—including SharePoint, Azure Blob Storage, OneLake, web content, and other enterprise systems—into a single reusable knowledge base. Foundry IQ automatically handles indexing, synchronization, retrieval planning, source selection, grounding, and security enforcement, enabling teams to focus on delivering business value instead of managing retrieval infrastructure.

In essence, Azure AI Search remains the underlying retrieval engine, while Foundry IQ provides the context engineering layer that transforms enterprise knowledge into AI-ready context for agents and applications. This evolution significantly reduces the complexity of building grounded AI solutions while enabling knowledge to be reused consistently across multiple agents and use cases.

## Prerequisites

- Complete the participant setup in the [root README](../README.md).
- Confirm that the MicroHack platform or your event coach supplied the Azure
  resources and the values required by `.env.example`.
- Ensure your crash statements are indexed in Foundry IQ (for example, through your Azure AI Search index used by Foundry).
- Have your Github Codespaces up and running.

## Tasks

### Task 1: Populate the crash statements search index

The Claims Intake Agent's Foundry IQ tool queries an Azure AI Search index named `crash-statements`. [`labautomation/azuredeploy.json`](../labautomation/azuredeploy.json) already creates this index for you as part of the lab deployment, so you only need to load it with crash statement content before running the agent.

#### The index schema

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

#### Upload crash statement documents

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
You should get the answer of `Done. Indexed 10 statement documents`.

### Task 2: Understand Foundry IQ knowledge bases, then create one

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

1. Sign in to the [Azure portal](https://portal.azure.com) using the account and
  tenant provided for the lab.
2. In the portal search bar, search for **Azure AI Search**, and then open the
  search service created for your lab. You can identify the correct service by
  matching its name to the host in `AZURE_SEARCH_ENDPOINT`. 
3. In the search service menu, expand **Agentic retrieval**, and then select
  **Knowledge bases**. This area is the Azure AI Search surface that supports
  Foundry IQ knowledge bases.
4. Confirm that `crash-statements-kb` appears in the list, and then select it to
  open its chat playground.
5. Check that the knowledge base references the `crash-statements-ks` knowledge
  source. If the knowledge source is missing, return to **Agentic retrieval** >
  **Knowledge sources** and confirm that `crash-statements-ks` exists and wraps
  the `crash-statements` index.
6. On this new pane:

   1. Select a **Reasoning Effort** option under **Retrieval**.
   2. Select an **Output Mode** option under **Output Configurations**.
   3. In the knowledge base chat box, enter a question that should match one of
      the indexed statements. For example:

      ```text
      Find the crash statement for policy COMM-AUTO-001. Summarize the claimant,  vehicle, incident location, and whether the retrieved evidence is consistent.
      ```

7. Submit the question and verify that the response cites content from
  `crash-statements-ks`, including John Peterson and policy
  `C1A8-AU1D-001`. Selecting Minimal as Reasoning Effort and Extractive data as Output Mode, you will find an answer such as the following:

![Searching on a vecto databases](/challenges/images/demo_retrievaldone.png)

Before continuing, experiment with these two settings:

**Reasoning Effort** controls how much LLM processing Azure AI Search uses to
plan retrieval. **Minimal** sends the query directly to the knowledge source
for the lowest latency and cost. **Low** performs one LLM-planned retrieval
pass. **Medium** can perform a deeper follow-up search when the first results
are insufficient, which can improve completeness but increase latency and
cost. **Auto**, when available, selects the depth for each request.

**Extractive data** returns the most relevant passages from the source
documents instead of generating a synthesized natural-language answer. This
mode helps you inspect the retrieved evidence directly and is required when
**Minimal** reasoning effort is selected.

Run the same question with **Minimal** and **Low** reasoning effort. Where
available, also try **Medium** or **Auto**. Compare the returned passages,
citations, response time, and activity log. Then switch between **Extractive
data** and **Answer synthesis** to observe the difference between raw grounding
evidence and a generated, citation-backed answer.

8. Select the debug or activity icon underneath the response. Confirm that the
  activity log shows a retrieval operation against `crash-statements-ks` and a
  nonzero result count. The log also shows the generated search query, elapsed
  time, and answer-synthesis activity.

If `crash-statements-kb` doesn't appear, refresh the page and verify that you
opened the search service whose endpoint was used when you ran
[`docs/create_knowledge_base.py`](../docs/create_knowledge_base.py). Also confirm
that the script completed without an error and printed the MCP endpoint for
`crash-statements-kb`.

For more information about this portal experience, see the
[Azure AI Search agentic retrieval quickstart](https://learn.microsoft.com/azure/search/get-started-portal-agentic-retrieval).


### Task 3: Understand how the agent is created with the Foundry SDK (no action required)

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

### Task 4: Understand how Foundry IQ grounding is added through a knowledge base (no action required)

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

### Task 5: Run the Claims Intake Agent

Use an accident statement form image under `data/claims/{claim-id}/raw/statements/`, not the reference photos in `data/claims/{claim-id}/raw/vehicle-damage/`. The `raw/vehicle-damage/*.jpg` files are generic damage photos with no text, so OCR on them produces no usable content and Foundry IQ returns zero matches. The `raw/statements/*_front.jpeg` and `*_back.jpeg` files contain the actual handwritten claim forms that match the indexed crash statement content.

```bash
cd docs
python claims-intake-agent.py ../data/claims/crash1/raw/statements/crash1_front.jpeg
```

Optional output path:

```bash
python claims-intake-agent.py ../data/claims/crash1/raw/statements/crash1_front.jpeg --output ../challenges/intake_result_crash1.json
```
### Task 6: Test your Agent in the Portal

1. On the Microsoft Foundry Portal, find the Build Section

![alt text](challenges/images/chal2_3.png)

2. On Agents, select your previously created Claims Intake Agent.
3. In this section, you will see the agent you created. Review its main settings:

  * **Model** selects the deployed model that runs the agent.
  * **Instructions** define the agent's role, behavior, and response rules.
  * **Tools** connect capabilities such as Foundry IQ, MCP, or custom functions.
  * **Parameters** tune response behavior, including creativity and reasoning effort when supported by the model.
  * **Versions** preserve published configurations so changes can be tracked or rolled back.

![alt text](/challenges/images/chal2_4.png)
4. Test your Agent on the Portal
  ```text
  Find the crash statement for policy COMM-AUTO-001. Summarize the claimant,
  vehicle, incident location, and whether the retrieved evidence is consistent.
  ```

  Confirm that the response identifies John Peterson and uses the knowledge-base
  tool before answering.

### Task 7: Optional, connect Foundry to the blob storage account

The lab deployment creates a Storage account with a `claims-data` container that can hold claim images and documents for direct processing from Foundry, instead of relying only on local files. If you want to validate the setup in the Foundry portal, connect this Storage account to your Foundry project so agents and tools in the portal can read from it.

1. Open the [Microsoft Foundry portal](https://ai.azure.com)

2. On the top bar, go to **Manage** >**Project details** > **Connected resources**.

![alt text](/challenges/images/chal2_1.png)

3. Select **Add connection**.
4. In the agent playground, enter this prompt and select **Send**:
4. Choose **Azure Blob Storage** as the connection type.



![alt text](/challenges/images/chal2_2.png)

5. Select the Storage account supplied with your lab.
6. Set the authentication method to **API key**, then confirm the connection name (for example, `claims-data-storage`).
7. Select **Add connection** to finish.
8. Verify the connection appears under **Connected resources** with a status of **Connected**.

With this connection in place, Foundry can list and read blobs from the `claims-data` container directly, so you can point future tasks and agents at blob paths instead of copying files locally first. [Challenge 3](./challenge-03.md) builds on this same pattern — creating an agent with the SDK, then giving it an enterprise need — using your Storage account's `policies` container instead of Foundry IQ.


## Validation checklist

- OCR call succeeds with `status: success`.
- The `claims-intake-agent` agent appears under your Foundry project's agents (visible via the SDK or the Foundry portal).
- At least one crash statement match is returned from Foundry IQ.
- Output JSON is created and contains `ocr`, `foundry_iq`, and `agent_summary` sections.
- (Optional) The Storage account connection appears under **Connected resources** in the Foundry portal with a status of **Connected**.

## Next step

Continue with [Challenge 3](./challenge-03.md) to ground coverage decisions in
enterprise policy documents.

