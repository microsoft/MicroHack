# Screenshots

This folder holds the screenshots embedded throughout the challenge guides and walkthroughs. Each image is referenced by the exact filename below, so the guides render end-to-end. All captures are light theme, ~1280–1600px wide, with any real tenant, subscription, email, or GUID values redacted.

> **Model name in captures is illustrative.** Where a screenshot shows a selected chat model (e.g. `gpt-4o-mini` or `gpt-5.4-mini`), that name reflects only what was deployed when the capture was taken. The model is **swappable** — attendees use whatever their facilitator provisioned. You do **not** need to re-shoot screenshots when the deployed model changes; challenge-01 tells attendees this explicitly.

> **Portal UI captures pending re-shoot.** The Fabric/Foundry portals changed after some captures were taken; the guide text is already updated for the current UI. Re-capture when convenient: the Data Agent **Settings → Model Context Protocol → MCP server URL** page (replaces the retired *Publishing → Published URL*; used by `challenge-00-agent-settings.png`, `challenge-00-agent-url.png`, `challenge-00-agent-ids.png`). The Foundry captures for Challenges 2-4 (Fabric IQ tool, recommendation, approval flow and traces) were re-taken in October 2026.

| Filename | Challenge | Shows |
|----------|-----------|-------|
| `challenge-00-model-deployments.png` | 0 | Foundry **Models + endpoints** with `gpt-5.4-mini` deployed, status **Succeeded**. |
| `challenge-00-playground-what-can-you-do.png` | 0 | Agents playground grounding test — *"What can you do?"* and the agent's reply. |
| `challenge-00-new-workspace-button.png` | 0 | Fabric left navigation with **Workspaces** open and the **+ New workspace** button highlighted. |
| `challenge-00-create-workspace.png` | 0 | The Fabric **Create a workspace** dialog: **Advanced** expanded, **Workspace type: Fabric**, and the attendee's `invcap…` Fabric capacity selected under **Details**. |
| `challenge-00-new-lakehouse.png` | 0 | The **+ New item** panel filtered to *"lake"* with the **Lakehouse** tile selected, inside the `inventory-hack` workspace. |
| `challenge-00-lakehouse-name.png` | 0 | The **New Lakehouse** dialog with the name **`InventoryLakehouse`** and Location `inventory-hack`. |
| `challenge-00-import-notebook.png` | 0 | The workspace **Import → Notebook → From this computer** menu, for `Setup-InventoryDataAgent.ipynb`. |
| `challenge-00-import-upload.png` | 0 | The **Import status** panel with the **Upload** button to choose the notebook file from the local computer. |
| `challenge-00-notebook-imported.png` | 0 | The imported notebook open with the **Imported successfully** confirmation popover. |
| `challenge-00-attach-lakehouse.png` | 0 | The **OneLake catalog** dialog attaching **`InventoryLakehouse`** (Location `inventory-hack`) as the notebook's default Lakehouse. |
| `challenge-00-run-all.png` | 0 | The notebook with **`InventoryLakehouse`** attached as the default Lakehouse and the **Run all** button highlighted. |
| `challenge-00-notebook-ids.png` | 0 | The setup notebook's final cell output printing the **Workspace ID** and **Data Agent (Agent) ID** (values redacted). |
| `challenge-00-agent-test.png` | 0 | The published data agent's **Test data agent** pane answering the Leaf Blower X2 question with exact **CRITICAL** stock levels for Portland and Seattle (all tables selected). |
| `challenge-00-no-tables.png` | 0 | Troubleshooting: the data agent with **no tables selected** and the agent replying it *can't access the data source*. |
| `challenge-01-fabric-iq-catalog.png` | 1 | The **OneLake Catalog** dialog with `inventory-hack-agent` selected and its Location visible (Challenge 2, Part C). |
| `challenge-01-new-agent.png` | 1 | New agent editor for `demand-sensing-agent`: name, `gpt-5.4-mini` model, instructions and **Web search** under **Tools**. |
| `challenge-01-add-tool.png` | 1 | The **Select a tool** dialog (**Configured** tab) with **Fabric IQ (OneLake Catalog)** selected; the deprecated Fabric Data Agent tile is greyed out. |
| `challenge-01-playground.png` | 1 | Playground answer to the heatwave scenario: cited web sources, Fabric stock numbers and a demand assessment, with `inventoryhackagent` and `Web search` chips. |
| `challenge-02-reuse-connection.png` | 2 | The **Select a tool** dialog showing the existing `inventoryhackagent` connection under **Configured** (Challenges 3 and 4). |
| `challenge-02-recommendation.png` | 2 | Reorder **recommendation table** (SKU / Location / Current Stock / Suggested Reorder Qty / Priority), all rows **CRITICAL**. |
| `challenge-02-trace.png` | 2 | The **Traces** tab's trace detail: an **Invoke Agent** span with its **Execute Tool** (Fabric) and **Chat** spans, and **Input + Output**. |
| `challenge-03-approval-flow.png` | 3 | The `MODIFY 1 50` → `YES` approval exchange and the simulated submission confirmation. |
| `challenge-03-trace.png` | 3 | The conversation trace for the approval run: three **Invoke Agent** spans, with the Fabric unit-cost lookup only in the first. |
| `challenge-04-orchestrator.png` | 4 *(stretch)* | The `inventory-planning-workflow` canvas: Start → demand-sensing → inventory-optimisation → replenishment-action. |
| `challenge-04-teams.png` | 4 *(stretch)* | The workflow's **Publish** menu open on **Teams & Microsoft 365 Copilot** — the "what's next" showcase entry point. |
