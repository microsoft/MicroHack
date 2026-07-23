# Screenshots

This folder holds the screenshots embedded throughout the challenge guides and walkthroughs. Each image is referenced by the exact filename below, so the guides render end-to-end. All captures are light theme, ~1280–1600px wide, with any real tenant, subscription, email, or GUID values redacted.

> **Model name in captures is illustrative.** Where a screenshot shows a selected chat model (e.g. `gpt-4o-mini` or `gpt-5.4-mini`), that name reflects only what was deployed when the capture was taken. The model is **swappable** — attendees use whatever their facilitator provisioned. You do **not** need to re-shoot screenshots when the deployed model changes; challenge-01 tells attendees this explicitly.

| Filename | Challenge | Shows |
|----------|-----------|-------|
| `challenge-00-model-deployments.png` | 0 | Foundry **Models + endpoints** with `gpt-5.4-mini` deployed, status **Succeeded**. |
| `challenge-00-playground-what-can-you-do.png` | 0 | Agents playground grounding test — *"What can you do?"* and the agent's reply. |
| `challenge-00-new-workspace-button.png` | 0 | Fabric left navigation with **Workspaces** open and the **+ New workspace** button highlighted. |
| `challenge-00-create-workspace.png` | 0 | The Fabric **Create a workspace** dialog: **Advanced** expanded, **Workspace type: Fabric**, and the attendee's `invcap…` F2 capacity selected under **Details**. |
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
| `challenge-01-new-connection.png` | 1 | The **Add tool → Fabric Data Agent** connection dialog (Workspace ID / Artifact ID redacted) named `inventory-hack-agent` — created in Challenge 2. |
| `challenge-01-new-agent.png` | 1 | New agent editor for `demand-sensing-agent`: name, `gpt-5.4-mini` model, and populated instructions. |
| `challenge-01-add-tool.png` | 1 | The tool catalogue in the agent editor with **Web Search** and **Fabric Data Agent** available. |
| `challenge-01-playground.png` | 1 | Playground response with a Fabric inventory result (and a web source if Web Search is on) ending in a demand assessment. |
| `challenge-02-recommendation.png` | 2 | Reorder **recommendation table** (SKU / Warehouse / Current Stock / Suggested Reorder Qty / Priority) with a **CRITICAL** item. |
| `challenge-02-trace.png` | 2 | **Tracing** detail expanded to the model call, Fabric tool call, tool response, and final generation spans. |
| `challenge-03-approval-flow.png` | 3 | The `MODIFY 1 50` → `YES` approval exchange and the simulated submission confirmation. |
| `challenge-03-trace.png` | 3 | Trace of the approval run: model calls plus the Fabric unit-cost lookup across propose → MODIFY → YES. |
| `challenge-04-orchestrator.png` | 4 *(stretch)* | The `inventory-planning-workflow` canvas: Start → demand-sensing → inventory-optimisation → replenishment-action. |
| `challenge-04-teams.png` | 4 *(stretch)* | The workflow's **Publish** menu open on **Teams & Microsoft 365 Copilot** — the "what's next" showcase entry point. |
