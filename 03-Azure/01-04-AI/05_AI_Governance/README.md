# Agentic Governance Hub

Welcome to the **Agentic Governance Hub** MicroHack. In this hands-on lab you'll deploy a
**Citadel Agentic Governance Hub** — a centralized Azure API Management gateway that
governs every LLM/agent call in your organization — and drive it through nine guided,
notebook-based exercises covering backend onboarding, access contracts, PII handling,
multi-framework agents, hosted agents, and agent-to-agent / MCP publishing.

- [**Introduction**](#introduction)
- [**Learning objectives**](#learning-objectives)
- [**Scenario**](#scenario)
- [**Requirements**](#requirements)
- [**Challenges**](#challenges)
- [**Repository layout**](#repository-layout)
- [**Contributors**](#contributors)

## Introduction

This MicroHack teaches you how to put **governance in front of AI**: a single Azure API
Management gateway (the **Citadel Governance Hub**) that every model call and every agent
routes through, so an organization gets consistent RBAC, rate-limiting/capacity control,
PII handling, and audit trails — no matter which model, which agent framework, or which
protocol (chat completions, Responses API, A2A, MCP) a team chooses to build with.

Your lab automation ([`labautomation/`](labautomation/)) provisions a dedicated **Hub**
(APIM + a Foundry account for governance) and **Spoke** (a sample Foundry workload) per
attendee. The nine challenges then walk you through the **unchanged Citadel workshop
notebooks** — each one a self-contained, already-documented exercise — in the order the
governance model builds up: onboard a backend, expose it universally, add access
contracts (RBAC + capacity), drive those contracts from real agent frameworks, add PII
processing, unify multiple providers behind one API, then graduate to hosted agents
governed end-to-end, agent-to-agent publishing, and MCP tool publishing.

## Learning objectives

By completing this MicroHack you will be able to:

- Onboard a new LLM backend into a governance gateway and prove it through multiple API
  shapes (Azure OpenAI, Universal LLM API, streaming).
- Provision **Access Contracts** that enforce model-level RBAC and capacity limits, and
  understand how token-bucket throttling behaves under load.
- Drive the same governed access contract from three different agent frameworks
  (Microsoft Agent Framework, Foundry Agent SDK, LangChain).
- Configure PII anonymization/deanonymization and PII blocking at the gateway, with usage
  analytics.
- Compare model-provider access patterns (Azure OpenAI, Foundry inference, Responses API,
  Gemini-compatible) behind one **Unified AI API**.
- Build and deploy a **Foundry Hosted Agent** governed end-to-end by the **Agent
  Governance Toolkit (AGT)**, and read its audit trail in Application Insights.
- Publish a Foundry Agent as a governed **Agent-to-Agent (A2A)** endpoint through APIM.
- Understand how an **MCP server** is published and consumed through APIM, including
  where this lab's automation stops short (Entra app-registration/app-role setup) and
  what a facilitator needs to add to unlock that exercise.

## Scenario

You are onboarding your organization onto a **Citadel Agentic Governance Hub**: a single
Azure API Management gateway that every model call and every agent must pass through, so
platform, security, and compliance teams get one place to see and control AI usage.

Your lab automation deploys:

- A **Hub** resource group containing APIM, a governance Foundry account/project, Log
  Analytics, Application Insights, Cosmos DB (usage tracking), Event Hub, and Key Vault.
- A **Spoke** resource group (folded into the same RG) containing a sample Foundry
  account/project and Azure Container Registry — where you build and deploy the agents
  the later challenges call for.

Each challenge exercises one governance capability against these resources, using the
Citadel workshop's own Jupyter notebooks — unmodified, and already fully documented with
their own numbered sections, so the challenge files here exist to orient you and point
you at the right notebook, not to restate what's already in it.

## Requirements

To complete this MicroHack you'll need:

- Your lab's attendee credentials (`HackboxCredential` values) from the MicroHack
  dashboard — resource group, subscription, and the Spoke Foundry/Key Vault/ACR names.
- `azd` installed, so [`setup-notebook-env.ps1`](labautomation/README.md#notebook-environment-setup)
  can bridge those credentials into a local `azd` environment the (unchanged) workshop
  notebooks read via `azd env get-value`.
- The Azure CLI (`az`), logged in (`az login`) against your lab's subscription/tenant.
- The workshop's Python environment set up (`uv sync` or `pip install -r requirements.txt`
  from the `reference/ai-hub-gateway-solution-accelerator/workshop/` folder).
- Comfort running and reading Jupyter notebooks in VS Code.

> [!TIP]
> **You're ready to start when** you've run `setup-notebook-env.ps1` once with your
> dashboard's credentials (see [Challenge 1, Part A](challenges/challenge-01.md)) and can
> open the first workshop notebook without any `azd env get-value` errors.

## Challenges

This MicroHack is divided into nine challenges. Challenges 1–6 build up the core
governance model (backends → universal API → access contracts → agent frameworks → PII →
unified API); challenges 7–8 graduate to hosted, governed agents and agent-to-agent
publishing; challenge 9 covers MCP publishing and is **optional/instructor-led**, since it
needs infrastructure this lab's automation doesn't provision on its own.

### Challenge structure

Each challenge follows the same anatomy, so you always know where to look:

| Section | Description |
|---------|-------------|
| 🎯 **Objective** | What you'll achieve and why it matters |
| 🧭 **Context** | The Hub/Spoke resources and prerequisites this exercise relies on |
| ✅ **Tasks** | Confirm your notebook bridge, then run the notebook's own sections in order |
| 🏁 **Success criteria** | A checklist to confirm you're done |
| 🛠️ **Troubleshooting** | Common problems and their fixes |
| 🚀 **Go further** | Optional stretch goals if you finish early |
| 📚 **Learning resources** | Docs to go deeper |

### Challenge list

- **Challenge 1**: **[Onboard a New LLM Backend](challenges/challenge-01.md)** *(35 min)* — onboard a backend into the hub and prove it through multiple API shapes.
- **Challenge 2**: **[Universal LLM API Across Every Model](challenges/challenge-02.md)** *(25 min)* — validate `/models` against every model with no RBAC restriction.
- **Challenge 3**: **[Access Contracts: Model RBAC & Capacity](challenges/challenge-03.md)** *(35 min)* — three access contracts enforcing `allowedModels` and capacity limits.
- **Challenge 4**: **[Drive Access Contracts from Agent Frameworks](challenges/challenge-04.md)** *(30 min)* — the same contracts, driven from three different agent frameworks.
- **Challenge 5**: **[PII Anonymization, Blocking & Analytics](challenges/challenge-05.md)** *(35 min)* — mask, block, and analyze PII at the gateway.
- **Challenge 6**: **[Unified AI API Across Providers](challenges/challenge-06.md)** *(35 min)* — one API surface across Azure OpenAI, Foundry inference, Responses API, and Gemini-compatible patterns.
- **Challenge 7**: **[Build a Governed Hosted Agent with AGT](challenges/challenge-07.md)** *(40 min)* — deploy a Foundry Hosted Agent governed end-to-end by the Agent Governance Toolkit.
- **Challenge 8**: **[Publish a Foundry Agent as an A2A Endpoint](challenges/challenge-08.md)** *(35 min)* — publish and call an agent-to-agent endpoint through APIM.
- **Challenge 9** *(optional / instructor-led)*: **[HR MCP via APIM](challenges/challenge-09.md)** *(variable)* — publish and consume an MCP server through APIM; requires facilitator-provisioned infrastructure beyond this lab's automation.

> [!TIP]
> It's tempting to race through, but pause after each challenge and read the notebook's
> own `📊 Results Summary` cell — that's where the "why this matters for governance"
> payoff actually lands.

## Repository layout

```
05_AI_Governance/
  README.md                 This file
  challenges/                Challenge instructions (challenge-01.md … challenge-09.md)
  labautomation/              Platform entry point — provisions the Hub + Spoke per attendee
    deploy-lab.ps1            Called once per attendee by the MicroHack platform
    run-local.ps1              Local-only dry-run wrapper (not used by the platform)
    setup-notebook-env.ps1     Bridges dashboard credentials into a local azd environment
    README.md                  Full provisioning + notebook-environment-setup reference
  reference/
    ai-hub-gateway-solution-accelerator/
      workshop/                 The 9 unchanged Citadel workshop notebooks this MicroHack is built on
```

## Contributors

| Name | Role |
|------|------|
| Alibek Jakupov | Author & maintainer |

## Contributing

This project welcomes contributions and suggestions. Most contributions require you to agree to a
Contributor License Agreement (CLA). For details, visit [https://cla.opensource.microsoft.com](https://cla.opensource.microsoft.com).

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft
trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
