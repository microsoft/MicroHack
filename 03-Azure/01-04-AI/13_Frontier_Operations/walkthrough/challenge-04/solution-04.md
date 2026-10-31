# Challenge 4 solution: Connect your system of record

**[← Previous Solution](../challenge-03/solution-03.md)** - [Home](../../README.md) - [Challenge](../../challenges/challenge-04.md) - [Next Solution →](../challenge-05/solution-05.md)

**Duration:** 40 minutes

## Expected tool calls

For one partner, with the skill and the ERP tool and no ledger export attached:

1. `getCompany`: company, currency, **tolerance** and period (the agent may skip it if the skill already gives the tolerance).
2. `listPartners` (optional) to find the partner's ID, then `getLedger` with `partner_id`.
3. Workspace and **skill** steps, as in Challenge 2.
4. `addLedgerNote` once per exception: five for a partner, because the within-tolerance line isn't an exception. The body has `reference` and `note`, for example `{"reference": "INV-41007", "note": "Amount mismatch: statement 2,354.87 vs ledger 2,342.37 (12.50). Action: Raise price dispute."}`.

The notes appear on the activity page (`BackOfficeUrl`) as *agent (ERP API) · ledger note*. `lookupReference` normalises references the way the handbook does, so `inv 41007`, `IN-41007` and `INV-041007` all find `INV-41007`.

Without a key, `<BackOfficeUrl>/erp/partners` returns **401** *Missing or wrong API key. Send it in the x-api-key header.* `/openapi.json` doesn't need a key, so the tool's schema can be fetched.

## Points to discuss

- **Where the key lives.** The lab automation generated the key, stored it in the Functions app setting `ERP_API_KEY` and in the project connection `erp` (category *Custom keys*, header `x-api-key`), and never output it. Participants never see it, and it doesn't appear in instructions, chats or traces.
- **Read and write.** The agent now writes to a system of record. A real ERP API has far more operations: publish only the ones the agent needs in its OpenAPI document. A smaller schema is also a better schema for the model.
- **Exports versus live data.** The agent's result is now based on the ledger at the moment it ran, and the notes leave an audit trail in the system people already use.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Tool calls return 401 | The tool isn't using the `erp` connection. Edit the OpenAPI tool and set **Authentication method** to **API key** with **Connection** `erp`. |
| Tool calls return 409 *No industry pack is selected* | Run the Challenge 1 `setup` command again. |
| The agent says it has no ERP tool, or *tools could not be initialized* | The toolbox isn't attached to the agent, or the agent's identity can't reach the toolbox. Check the agent's **Tools** list shows `ops-tools`, that `grant-agent` was run for this agent, and start a new chat. If it still fails, add the OpenAPI tool directly to the agent instead (**Add**, **Add tools**, **Custom**, **OpenAPI tool**, API key with the `erp` connection). In our portal run the toolbox route worked first time: a quick ERP question took 7 seconds, shown as `managed_tools`. |
| The schema won't save | Paste the JSON from `/openapi.json`, not the URL. |
| The agent reads the attached file instead of the ERP | Check the new sentence is in the instructions and remove attached ledger exports from the chat. |
| The first call times out | The Functions app is cold-starting. Ask again after 30 seconds. |
