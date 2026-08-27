# Finish

[← Solution 09](../walkthrough/challenge-09/solution-09.md) · **[Home](../README.md)**

## Congratulations 🎉

You finished the **AI Governance** MicroHack.

Along the way you turned an ungoverned pile of models into a governed AI platform:

- **Challenge 1–2** — onboarded an LLM backend behind a single gateway and proved one
  Universal LLM API works across every deployed model.
- **Challenge 3–4** — enforced *access contracts*: which caller may use which model, at what
  capacity — then drove those same contracts from three different agent frameworks.
- **Challenge 5** — masked, blocked, and analysed PII **at the gateway**, so governance holds
  no matter which client calls.
- **Challenge 6** — unified Azure OpenAI, Foundry inference, and Responses-style APIs behind
  one contract.
- **Challenge 7–9** *(follow-on)* — built a governed hosted agent with the Agent Governance
  Toolkit, published it as an A2A endpoint, and exposed an MCP server through APIM.

The governance idea worth taking home: **policy belongs at the gateway, not in each app.**
Every control you configured applies identically to a notebook, an SDK agent, and a
third-party tool — because none of them can reach a model any other way.

## Clean up

Your MicroHack resource group is deleted by the platform when the lab expires — no action
needed. If you deployed the workshop yourself outside the MicroHack, delete the resource
group and then purge the soft-deleted resources:

```bash
az group delete --name <your-resource-group> --yes --no-wait
az cognitiveservices account purge --name <foundry-account> --resource-group <rg> --location <region>
az keyvault purge --name <key-vault> --location <region>
```

> [!NOTE]
> API Management and Azure AI Foundry accounts are **soft-deleted**. Without the purge
> commands their names stay reserved and a redeploy in the same subscription fails.

## Keep going

- [Azure API Management — AI gateway capabilities](https://learn.microsoft.com/azure/api-management/genai-gateway-capabilities)
- [Azure AI Foundry documentation](https://learn.microsoft.com/azure/ai-foundry/)
- [Responsible AI in Azure AI Foundry](https://learn.microsoft.com/azure/ai-foundry/responsible-use-of-ai-overview)
- [AI Hub Gateway Solution Accelerator](https://github.com/mohamedsaif/ai-hub-gateway-solution-accelerator) — the upstream project this MicroHack is built on

## Feedback

Found a bug, or something that could be explained better? Please open an issue on this
repository or reach out to the contributors listed in the [module README](../README.md).

Thank you for investing the time — see you at the next MicroHack!
