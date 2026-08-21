# Challenge 7 — Build a Governed Hosted Agent with AGT

**[Home](../README.md)** - [← Previous Challenge](challenge-06.md) - [Next Challenge →](challenge-08.md)

## 🎯 Objective

Build a **Foundry Hosted Agent** for a Contoso HR scenario, governed end-to-end with the
**Microsoft Agent Governance Toolkit (AGT)**, deploy it to your spoke Foundry project,
and test it — including a policy that denies SSN disclosure and audits PTO/benefits
questions.

## 🧭 Context

| Component | Detail |
|-----------|--------|
| Agent framework | Microsoft Agent Framework (`agent-framework`) |
| Governance | AGT MAF adapter — policy, capability guard, audit trail, rogue detection |
| Protocol | Responses API (hosted on port 8088) |
| Model | `gpt-4.1` via the APIM BYO Gateway connection (`Hub-HR-ChatAgent-DEV-LLM/gpt-4.1`) created in [Challenge 3](challenge-03.md) |
| Tools | `get_pto_balance`, `get_holiday_schedule`, `get_benefits_summary`, `get_open_enrollment_window` |
| Policy | A bundled YAML policy (`policies/hr-policy.yaml`) — denies SSN disclosure and 3rd-party salary lookups, audits PTO/benefits queries |
| Telemetry | AGT OpenTelemetry → Application Insights (`agt.policy.*` spans, `agt.policy.evaluations`/`denials`/`latency_ms` metrics) |
| Container build | `az acr build` (cloud build — no local Docker required) |

**This notebook requires [Challenge 3](challenge-03.md)** to have created the
`Hub-HR-ChatAgent-DEV-LLM` BYO Gateway connection. Your lab's spoke Foundry resources and
Azure Container Registry are already provisioned — check
[`setup-notebook-env.ps1`](../labautomation/README.md#notebook-environment-setup) has
run so the notebook can resolve them.

## ✅ Tasks

### Part A — Confirm your notebook environment is ready (2 min)

Same prerequisite as every notebook in this MicroHack — see
[Challenge 1, Part A](challenge-01.md#part-a--confirm-your-notebook-environment-is-ready-5-min).

### Part B — Run the hosted agent notebook (40 min)

1. Open
   `../reference/ai-hub-gateway-solution-accelerator/workshop/7. citadel-hosted-agent-with-agt.ipynb`.
2. Run the notebook's sections in order:
   - `0️⃣ Initialize Notebook Variables`
   - `1️⃣ Verify Azure CLI Login`
   - `2️⃣ Generate Hosted Agent Source Files`
   - `3️⃣ Build & Push Container Image`
   - `4️⃣ Deploy Hosted Agent to Foundry`
   - `5️⃣ Wait for Agent to Become Active`
   - `5a. Assign RBAC to Agent Identity`
   - `6️⃣ Invoke the Hosted Agent`
   - `6a. Test AGT Governance Enforcement`
   - `7️⃣ Multi-Turn Conversation`
   - `8️⃣ Streaming Responses`
   - `9️⃣ Cleanup`
3. Read `View AGT audit results in Application Insights` and, if you have access to the
   spoke Application Insights resource, run the provided KQL query against `traces` to
   see policy-violation audit events.

## 🏁 Success criteria

- [ ] The hosted agent container built and pushed via `az acr build`, and the agent
      deployed to your spoke Foundry project.
- [ ] The agent's managed identity received the RBAC it needs (step `5a`) and the agent
      responds to a basic invocation (step `6️⃣`).
- [ ] Step `6a` proves the AGT policy actually enforces governance — an SSN-disclosure or
      3rd-party salary request is denied rather than answered.
- [ ] A multi-turn conversation and a streaming response both work end-to-end.
- [ ] You can find `agt.audit.event` trace records in Application Insights for a denied
      request.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| `azd env get-value` errors | `setup-notebook-env.ps1` hasn't been run — see Part A. |
| Connection `Hub-HR-ChatAgent-DEV-LLM` not found | Run [Challenge 3](challenge-03.md) first — it creates this Foundry connection. |
| Agent stays in a non-active state after step `5️⃣` | Container deployments can take a few minutes to come up; re-run the wait cell rather than assuming failure. |
| Step `6a` doesn't deny the disallowed request | Confirm `policies/hr-policy.yaml` was actually bundled into the container image built in step `3️⃣` — re-run `2️⃣`–`4️⃣` if the source files changed after the last build. |
| No `agt.audit.event` traces show up | AGT telemetry can lag by a minute or two before appearing in Application Insights; also confirm you're querying the **spoke** Application Insights resource, not the hub's. |

## 🚀 Go further

- Edit `policies/hr-policy.yaml` to add a new denial rule, rebuild the container, and
  confirm the new rule is enforced in a fresh `6a` run.

## 📚 Learning resources

- [Microsoft Foundry Agent Service — hosted agents](https://learn.microsoft.com/azure/ai-foundry/agents/overview)
- [Azure Monitor — Kusto Query Language (KQL) quick reference](https://learn.microsoft.com/azure/data-explorer/kql-quick-reference)
