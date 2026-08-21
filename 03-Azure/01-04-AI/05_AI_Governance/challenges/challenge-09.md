# Challenge 9 — HR MCP via APIM (Optional / Instructor-Led)

**[Home](../README.md)** - [← Previous Challenge](challenge-08.md)

> [!IMPORTANT]
> **This challenge requires infrastructure this lab's automation does not deploy.**
> Unlike Challenges 1–8, the HR MCP backend (Container App, its Entra app registration,
> and the `Mcp.Invoke` app role) is provisioned by scripts under `workshop/mcp-hr/scripts/`
> that `labautomation/deploy-lab.ps1` **never calls**. Attempt this challenge only if your
> facilitator has separately run those scripts and shared the resulting `HR_MCP_*` values
> with you. Otherwise, treat this as a read-through: skim the notebook and this challenge
> to understand the pattern, and move on.

## 🎯 Objective

Validate the HR **Model Context Protocol (MCP)** server through **Azure API Management
only**: exercise the Citadel-style access contract, call MCP protocol/tool operations,
observe the APIM `5 tools/call per 30 seconds` rate limit, and configure a Microsoft
Agent Framework (MAF) hosted agent that calls the APIM-published MCP endpoint using its
own managed identity plus a delegated Entra token and APIM subscription key.

## 🧭 Context

| Prerequisite | Provided by |
|---|---|
| Base HR MCP infrastructure (Container App running the MCP server) | `workshop/mcp-hr/scripts/deploy-hr-mcp.*` — **not** part of `deploy-lab.ps1` |
| APIM access-contract assets (API, product, subscription, policies) | `workshop/mcp-hr/scripts/publish-hr-mcp-apim.*` — **not** part of `deploy-lab.ps1` |
| Entra app registration + `Mcp.Invoke` app role for the HR MCP API | Created by the scripts above — **not** automated by this lab, per its "no attendee-specific Entra app registration" scope |
| A delegated token for `HR_MCP_SCOPE` | `az account get-access-token`, using values only available once the above exists |

Because none of this is created by `setup-notebook-env.ps1` or `deploy-lab.ps1`, the
notebook's own variables (`HR_MCP_APIM_NAME`, `HR_MCP_APIM_RESOURCE_GROUP`,
`HR_MCP_SCOPE`, `HR_MCP_TENANT_ID`, `HR_MCP_AUDIENCE`, `HR_MCP_APP_ROLE_ID`,
`HR_MCP_API_CLIENT_ID`, etc.) will not resolve for you unless your facilitator has
pre-provisioned the HR MCP backend and given you these values directly (e.g. as
environment variables or in your `azd` environment).

## ✅ Tasks

### Part A — Confirm your notebook environment is ready (2 min)

Same prerequisite as every notebook in this MicroHack — see
[Challenge 1, Part A](challenge-01.md#part-a--confirm-your-notebook-environment-is-ready-5-min).

### Part B — Run as far as your environment allows

1. Open
   `../reference/ai-hub-gateway-solution-accelerator/workshop/9. publish-and-use-hr-mcp-via-apim.ipynb`.
2. **If the HR MCP backend has not been provisioned for you**, run only the read-only
   setup sections and stop before acquiring a token:
   - `0️⃣ Initialize notebook variables from azd env and environment variables`
   - `1️⃣ Verify Azure CLI login and subscription`
   - `2️⃣ Resolve APIM MCP endpoint and access-contract settings` (this will show which
     `HR_MCP_*` values are missing)

   Skip section `3️⃣` onward — they require the delegated token and app role that only
   exist once the facilitator's HR MCP deploy/publish scripts have run.
3. **If your facilitator has provisioned the HR MCP backend and shared the `HR_MCP_*`
   values**, set them in your environment, then continue through the rest of the
   notebook:
   - `3️⃣ Acquire participant delegated Entra token without printing it`
   - `4️⃣ Create the Citadel-style APIM access contract` (runs `publish-hr-mcp-apim`; set
     `RUN_APIM_PUBLISH = False` to only validate existing infra)
   - `5️⃣ Resolve APIM subscription key without printing it`
   - `6️⃣ APIM-only MCP JSON-RPC helpers`
   - `7️⃣ Test initialize, tools/list, read tool, and write tool through APIM only`
   - `8️⃣ Demonstrate the APIM tools/call rate limit` (5 calls / 30 s, expects a `429` on
     the excess request)
   - `9️⃣ Inspect APIM request/response body logs`
   - `🔟 Deploy a Foundry hosted agent that uses the HR MCP via APIM` (mirrors
     [Challenge 7](challenge-07.md), but the agent's tools come from the HR MCP server
     via APIM instead of local Python tools)
   - `1️⃣1️⃣ HR workflow through APIM`
4. Read the `✅ Summary` cell.

## 🏁 Success criteria

If you only ran the read-only setup sections:

- [ ] You can explain, from section `2️⃣`'s output, which `HR_MCP_*` values are missing
      and why (the HR MCP backend + Entra app role aren't part of this lab's automation).

If your facilitator provisioned the HR MCP backend and you ran the full notebook:

- [ ] A delegated token was acquired without ever being printed (step `3️⃣`), and the
      APIM access contract was created or validated (step `4️⃣`).
- [ ] MCP `initialize`, `tools/list`, and both a read and a write tool call succeed
      through APIM only (step `7️⃣`).
- [ ] The 6th rapid `tools/call` request within 30 seconds returns `429` (step `8️⃣`).
- [ ] The hosted agent from step `🔟` calls HR MCP tools through APIM using its own
      managed identity, a fresh Entra token, and the APIM subscription key — not a
      participant token.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Missing HR_MCP_*` errors anywhere from section `3️⃣` onward | Expected if the HR MCP backend hasn't been deployed for this lab session — see the callout at the top of this challenge. Ask your facilitator whether it's in scope for today. |
| `Could not acquire delegated token` | Confirm `HR_MCP_SCOPE` (and `HR_MCP_TENANT_ID`, if cross-tenant) were set correctly by your facilitator, and that you're logged in via `az login` against the right tenant. |
| Rate-limit test (step `8️⃣`) never returns `429` | The policy is scoped per participant subscription — confirm you're using your own APIM subscription key, not a shared one, and that requests are sent back-to-back. |
| Hosted agent (step `🔟`) gets `401`/`403` calling HR MCP | Its managed identity needs the `Mcp.Invoke` app role on the HR MCP API — confirm `HR_MCP_APP_ROLE_ID` / `HR_MCP_API_CLIENT_ID` are correct and RBAC/app-role assignment has propagated. |

## 🚀 Go further

- If you have facilitator access to run `workshop/mcp-hr/scripts/deploy-hr-mcp.*` and
  `publish-hr-mcp-apim.*` yourself, provision the HR MCP backend end-to-end and note what
  it would take to fold that into `labautomation/deploy-lab.ps1` for a future cohort.

## 📚 Learning resources

- [Model Context Protocol specification](https://modelcontextprotocol.io/)
- [Publish an MCP server through Azure API Management](https://learn.microsoft.com/azure/api-management/export-rest-mcp-server)
- [Microsoft Agent Framework overview](https://learn.microsoft.com/agent-framework/overview/agent-framework-overview)
