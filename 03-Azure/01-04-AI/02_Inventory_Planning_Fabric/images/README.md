# Screenshots

This folder holds the screenshots embedded throughout the challenge guides and walkthroughs. Each image is referenced by the exact filename below, so the guides render end-to-end. Fabric captures are light theme and Foundry portal captures are dark theme, roughly 1200–1600 px wide. Captures come from disposable lab resources; blur or crop anything personal (names, email addresses) before adding a new one.

> **Filenames use the earlier numbering.** `challenge-00-*` belongs to Challenge 1, `challenge-01-*` to Challenge 2, and so on. The **Challenge** column below shows the number used in the lab.

> **Model name in captures is illustrative.** Where a screenshot shows a selected chat model (e.g. `gpt-4o-mini` or `gpt-5.4-mini`), that name reflects only what was deployed when the capture was taken. The model is **swappable** — attendees use whatever their facilitator provisioned. You do **not** need to re-shoot screenshots when the deployed model changes; Challenge 1 tells attendees this explicitly.

> **Re-captured in October 2026** on a freshly provisioned lab, for Challenges 1–5. Still the earlier captures, with layouts that remain valid: `challenge-00-notebook-imported.png`, `challenge-00-attach-lakehouse.png`, `challenge-00-run-all.png`, `challenge-00-no-tables.png` and `architecture.png`. Challenge 5 has no captures of Teams or Microsoft 365 Copilot yet: the test account had no Teams or Copilot licence. Re-capture the rows marked *(earlier capture)* if the portals change again.

| Filename | Challenge | Shows |
|----------|-----------|-------|
| `challenge-00-model-deployments.png` | 1 | Foundry **Models → Deployments** tab with `gpt-5.4-mini`, status **Succeeded**. |
| `challenge-00-playground-what-can-you-do.png` | 1 | The model playground answering *"What can you do?"*. |
| `challenge-00-new-workspace-button.png` | 1 | Fabric **Workspaces** flyout with the **New workspace** button. |
| `challenge-00-create-workspace.png` | 1 | Top of the **Create a workspace** dialog: workspace name entered, **Advanced** expanded. |
| `challenge-00-create-workspace-capacity.png` | 1 | Lower part of the dialog: **Workspace type: Fabric**, the attendee's `invcap…` capacity under **Details**, and **Apply**. |
| `challenge-00-new-lakehouse.png` | 1 | The **New item** panel filtered to *"lake"* with the **Lakehouse** tile. |
| `challenge-00-lakehouse-name.png` | 1 | The **New lakehouse** dialog with the name `InventoryLakehouse` and **Lakehouse schemas** ticked. |
| `challenge-00-lakehouse-upload-files.png` | 1 | Lakehouse Explorer: **Files … → Upload → Upload files**. |
| `challenge-00-lakehouse-upload-files-select.png` | 1 | The **Upload files** panel with the folder button and the file picker showing all seven Parquet files selected. |
| `challenge-00-lakehouse-upload-complete.png` | 1 | The **Current uploads** list with all seven files showing a green check. |
| `challenge-00-lakehouse-load-to-tables.png` | 1 | A Parquet file's **...** menu with **Load to Tables → New table**. |
| `challenge-00-lakehouse-load-table.png` | 1 | The **Load file to new table** dialog: schema `dbo`, table name `demandhistory`. |
| `challenge-00-monitor-cancel-tableload.png` | 1 | **Monitor → Job runs**: a **TableLoad** job still **In progress**, with **Cancel** highlighted (the stalled-load fix). |
| `challenge-00-lakehouse-data-loaded.png` | 1 | Lakehouse Explorer with the seven tables under `dbo`. |
| `challenge-00-new-data-agent.png` | 1 | The **New item** panel filtered to *"agent"* with the **Data agent** item. |
| `challenge-00-create-data-agent-dialog.png` | 1 | The **Create data agent** dialog with the name `inventory-hack-agent`. |
| `challenge-00-agent-add-data.png` | 1 | The new data agent's **Sources** tab with **Add sources → Data source**. |
| `challenge-00-agent-select-source.png` | 1 | The OneLake catalog **Add a data source** dialog, filtered to Lakehouse, listing `InventoryLakehouse` with its Location. |
| `challenge-00-agent-select-tables.png` | 1 | The agent's Explorer with all seven tables under `dbo` ticked. |
| `challenge-00-agent-add-instructions.png` | 1 | **Setup → Agent instructions** containing the Zava grounding instructions. |
| `challenge-00-agent-test.png` | 1 | The **Test the agent's responses** pane answering the Leaf Blower X2 question: Portland 8 and Seattle 6 units, both **CRITICAL**. |
| `challenge-00-agent-publish.png` | 1 | The **Publish data agent** dialog with a description entered; **Also publish to Microsoft Copilot** left off. |
| `challenge-00-agent-url.png` | 1 | The **Settings** gear and the **Model Context Protocol** page with the MCP server URL. |
| `challenge-00-agent-ids.png` | 1 | The MCP server URL with the Workspace ID and Agent ID segments marked. |
| `challenge-00-import-notebook.png` | 1 | The workspace **Import → Notebook → From this computer** menu. |
| `challenge-00-import-upload.png` | 1 | The **Import status** panel with **Upload** and the file picker on `Setup-InventoryDataAgent.ipynb`. |
| `challenge-00-notebook-imported.png` | 1 | *(earlier capture)* The imported notebook with the **Imported successfully** popover. |
| `challenge-00-notebook-add-data-items.png` | 1 | The notebook Explorer with **Add data items → From OneLake catalog**. |
| `challenge-00-attach-lakehouse.png` | 1 | *(earlier capture)* The **OneLake catalog** dialog attaching `InventoryLakehouse` as the notebook's default Lakehouse. |
| `challenge-00-run-all.png` | 1 | *(earlier capture)* The notebook with `InventoryLakehouse` attached and **Run all** highlighted. |
| `challenge-00-notebook-ids.png` | 1 | The notebook's last cell printing `fabricWorkspaceId`, `fabricAgentId` and `lakehouseId`, above the agent's test answer. |
| `challenge-00-no-tables.png` | 1 | *(earlier capture)* Troubleshooting: the data agent with **no tables selected**, replying it *can't access the data source*. |
| `challenge-01-new-agent.png` | 2 | The new `demand-sensing-agent` editor: name, `gpt-5.4-mini`, instructions, **Web search** under **Tools**, version 1. |
| `challenge-01-add-tool.png` | 2 | The **Select a tool** dialog (**Configured** tab) with **Fabric IQ (OneLake Catalog)** selected; the retiring Fabric Data Agent tile is greyed out. |
| `challenge-01-fabric-iq-catalog.png` | 2 | The **OneLake Catalog** dialog with `inventory-hack-agent` selected and its Location visible. |
| `challenge-01-playground.png` | 2 | The playground answer to the heatwave scenario: cited web sources, Fabric stock numbers and a demand assessment, with `inventoryhackagent` and `Web search` chips. |
| `challenge-02-reuse-connection.png` | 3 | The **Select a tool** dialog showing the existing `inventoryhackagent` connection under **Configured**. |
| `challenge-02-recommendation.png` | 3 | The reorder **recommendation table** (SKU / Location / Current Stock / Suggested Reorder Qty / Priority), all rows **CRITICAL**. |
| `challenge-02-trace.png` | 3 | The **Traces** tab's trace detail: an **Invoke Agent** span with its **Execute Tool** (Fabric) and **Chat** spans, and **Input + Output**. |
| `challenge-03-approval-flow.png` | 4 | The `MODIFY 1 50` → `YES` approval exchange and the simulated submission confirmation. |
| `challenge-03-trace.png` | 4 | The conversation trace for the approval run: three **Invoke Agent** spans, with the Fabric unit-cost lookup only in the first. |
| `architecture.png` | Overview | *(earlier capture)* The architecture diagram used in the lab README. |
| `challenge-05-proposal.png` | 5 | The hosted assistant's **PURCHASE ORDER PROPOSAL (simulation only)**: five lines with Fabric unit costs, the total, and the approve, cancel and change commands. |
| `challenge-05-approve-and-replay.png` | 5 | A **SIMULATED submission** at revision 2, then the same approval rejected with *No duplicate submission*. |
| `challenge-05-cancel-status.png` | 5 | An order cancelled with `NO`, then `STATUS` showing it as **CANCELLED**. |
| `challenge-05-trace.png` | 5 | The assistant's trace: `workflow.run` with the three `executor.process` stages (demand, optimisation, replenishment). |
| `challenge-05-publish-dialog.png` | 5 | The **Publish to Teams and Microsoft 365** dialog with the fields filled in. |
| `challenge-05-publish-options.png` | 5 | **Publish options**: **Just you** selected, **People in your organization** needing admin approval. |
| `challenge-05-publish-success.png` | 5 | The **Publish successful** message pointing to the Microsoft 365 Copilot agent store and Teams. |
| `challenge-04-orchestrator.png` | 5 *(archived)* | **Historical.** The retiring `inventory-planning-workflow` canvas: Start → demand-sensing → inventory-optimisation → replenishment-action. Used only in `archive/visual-workflow-exercise.md`; do not re-shoot. |
| `challenge-04-teams.png` | 5 *(archived)* | **Historical.** A prompt agent's **Publish** menu open on **Teams & Microsoft 365 Copilot**. Used only in `archive/visual-workflow-exercise.md`; do not re-shoot. |
