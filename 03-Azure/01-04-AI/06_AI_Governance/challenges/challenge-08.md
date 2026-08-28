# Challenge 8 — Publish a Foundry Agent as an A2A Endpoint

**[Home](../README.md)** - [← Previous Challenge](challenge-07.md) - [Next Challenge →](challenge-09.md)

## 🎯 Objective

Run an agent on Microsoft Foundry, publish it through the Citadel Governance Hub (APIM)
as a governed **Agent-to-Agent (A2A)** endpoint, and call it end-to-end using nothing but
an APIM subscription key — even while the Foundry account's public network access stays
disabled.

## 🧭 Context

This notebook:

1. Resolves the agent-hosting Foundry account and project from the environment —
   no hardcoded names.
2. Temporarily enables public network access on that account so the notebook can reach
   its data plane.
3. Creates a simple HR **prompt agent** (mocked HR policy data) on `gpt-4.1`.
4. Enables the agent's incoming **A2A endpoint** and verifies its agent card.
5. Re-disables public network access to restore the secure, private-only posture.
6. Publishes the agent through **APIM** as a governed access contract (product +
   subscription) — the same `apimOnboardService.bicep` module used in
   [Challenge 3](challenge-03.md).
7. Calls the agent through APIM with just a subscription key — proving APIM reaches it
   over its private endpoint even with public access disabled.

> [!IMPORTANT]
> Upstream, this notebook finds the agent-hosting account by looking for a backend id
> ending in `-0`. This lab names its Foundry accounts `aif-hub-*` / `aif-spoke-*`, so
> that lookup finds nothing. Set **`A2A_FOUNDRY_ACCOUNT_NAME`** in your
> `challenges/workshop/.env` to the **`A2aFoundryAccountName`** value from your
> dashboard (it's the spoke Foundry account) and the notebook resolves it directly.

## ✅ Tasks

### Part A — Confirm your notebook environment is ready (2 min)

Same prerequisite as every notebook in this MicroHack — see
[Challenge 1, Part A](challenge-01.md#part-a--confirm-your-notebook-environment-is-ready-5-min).

### Part B — Run the A2A publish & consume notebook (35 min)

1. Open
   `workshop/8. publish-and-use-a2a-endpoint.ipynb`
2. Run the notebook's sections in order:
   - `1. Configuration`
   - `2. Helpers`
   - `3. Resolve the Foundry environment from azd`
   - `4. Enable public network access on the agent's Foundry account`
   - `5. Create the HR prompt agent`
   - `6. Enable the incoming A2A endpoint`
   - `7. Resolve the agent card URLs`
   - `8. Verify the v1.0 agent card`
   - `9. Re-disable public network access (restore secure posture)`
   - `10. Expose the agent as an A2A agent through APIM` — sub-steps `10.1` (resolve APIM
     coordinates), `10.2` (create the APIM API), `10.3` (attach the backend-auth policy),
     `10.4` (create the access contract)
   - `11. Call the agent through the APIM A2A endpoint`
3. Read `Notes & troubleshooting`, then optionally run `🧹 Cleanup` — it is **disabled by
   default**; you must set `cleanup_enabled = True` in that cell to remove the A2A access
   contract and API (it does not delete the Foundry agent itself).

## 🏁 Success criteria

- [ ] The HR prompt agent was created on `gpt-4.1` and its A2A endpoint was enabled, with
      the `v1.0` agent card verified (step 8).
- [ ] Public network access on the Foundry account was re-disabled (step 9) **before**
      publishing through APIM.
- [ ] An APIM API, product, and subscription were created (steps `10.1`–`10.4`) fronting
      the agent's A2A JSON-RPC runtime URL.
- [ ] Both calls in step 11 (agent card `GET` and JSON-RPC `message/send` `POST`) succeed
      through APIM using only the subscription key — with the Foundry account still
      privately-networked.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| Setup cell raises a missing-key error | Your `challenges/workshop/.env` is missing that key (or you haven't run the `azd` bridge) — see [Challenge 1, Part A](challenge-01.md#part-a--confirm-your-notebook-environment-is-ready-5-min). |
| `500` — backend "name is valid, but no data of the requested type was found" | A DNS/network error: APIM can't reach the agent's Foundry host. Confirm you're publishing through the APIM in the **same** azd environment as the agent. |
| `500` with a managed-identity error in the trace | APIM had no usable identity — section `10.3` auto-detects system- vs. user-assigned identity; if user-assigned, confirm the `client-id` was pinned. |
| `401`/`403` from the backend | The APIM managed identity lacks an Azure AI role (e.g. **Cognitive Services User**) on the agent's Foundry account — `azd up` grants this by default, but role propagation can take a few minutes. |
| `401` at APIM (before reaching the backend) | Missing/invalid `Ocp-Apim-Subscription-Key`, or the subscription isn't active — re-run section `10.4`. |
| `403 PublicNetworkAccess` when creating the agent (step 5) | The network change from step 4 hasn't propagated yet — the create cell retries; wait a minute and re-run if it still fails. |
| `404` on the agent card | Confirm the agent's A2A endpoint is enabled (steps 6–8) and `BASE_URL` matches your project/agent. |

## 🚀 Go further

- Set `ENABLE_MESSAGE_LOGGING = True` in section 1 before publishing, then inspect the
  `a2a-message-logging` trace records in Application Insights after step 11.
- Change `A2A_AGENT_NAME` (and optionally `A2A_PRODUCT_ID`) and re-run from step 5 to
  publish a second agent under its own access contract.

## 📚 Learning resources

- [Enable an agent-to-agent endpoint](https://learn.microsoft.com/azure/foundry/agents/how-to/enable-agent-to-agent-endpoint?tabs=rest-powershell%2Cverify-bash%2Cconnection-bash)
- [Import an A2A agent API in Azure API Management](https://learn.microsoft.com/azure/api-management/agent-to-agent-api)
