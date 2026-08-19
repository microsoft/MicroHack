# Challenge 08 - Adapt AI Services

[< Previous Challenge](challenge-07.md) - **[Home](../Readme.md)** - [Next Challenge >](challenge-09.md)

Estimated time: 60-90 minutes | Difficulty: advanced

## Challenge objective

Add an AI-advice capability to the trading application without coupling its application
model to one model host. Declare one `Radius.Resources/aiModels` contract and deploy the
same additive AI model to both targets:

- `ws-local-prod` uses a small CPU-hosted model on the private K3s cluster.
- `ws-azure-prod` references an approved Azure OpenAI deployment from AKS.

Only the environment recipe and identity parameters may vary. The agent, application
connection, capability contract, and request path remain invariant.

## Scenario

Traders want the application to summarize market context, but platform constraints
differ. The private K3s site has four CPU cores and no GPU. The connected AKS platform
can use an existing Azure OpenAI deployment, subject to region, quota, and governance
approval. The application team needs one contract rather than provider-specific code and
API keys.

The platform team will provide two implementations of the same AI capability. The K3s
recipe uses a compact Ollama model that is practical for the workshop VM. The AKS recipe
returns an Azure OpenAI endpoint and deployment name, while the pod authenticates with
Microsoft Entra workload identity.

## Learning goals

- Separate AI application intent from model hosting and provider configuration.
- Publish and register target-specific Radius recipes without changing the application
  contract.
- Distinguish an Azure OpenAI deployment name from its underlying model name and version.
- Reuse AKS workload identity for keyless model access.
- Compare performance, cost, availability, and operational ownership across AI
  implementations.
- Validate graph, resource, workload, and inference behavior without overstating model
  quality or local-disconnected capability.

## Fixed target map

| Platform | Kubernetes context | Radius workspace | Environment | Radius group |
| --- | --- | --- | --- | --- |
| Private K3s through Bastion | `k3s-azure-vm` | `ws-local-prod` | `env-local-prod` | `rg-trading` |
| AKS | `aks-adaptive-apps` | `ws-azure-prod` | `env-azure-prod` | `rg-trading` |

These are independent Radius control planes. Each needs its own recipe registry, recipe
registration, `trading-ai` resource, and `ai-agent` workload.

## Additional prerequisites

- Challenges 00-06 completed and the Challenge 05/06 application present on both
  targets.
- The `Radius.Resources/aiModels@2025-08-01-preview` contract from Challenge 03.
- Permission to create workloads and service accounts in both application namespaces.
- Outbound HTTPS from K3s to pull the Ollama image and `qwen2.5:0.5b` model.
- For the AKS path, an existing approved Azure OpenAI account and deployment in a
  supported region with available quota. This challenge does not create either resource.
- For the AKS path, permission to create a user-assigned managed identity and federated
  credential, and to assign **Cognitive Services OpenAI User** at the Azure OpenAI
  account scope.

## Portability boundary

The application addition is `iac/ai.bicep`. It declares:

- An existing Radius application named `adaptive-apps`.
- A portable AI resource named `trading-ai`.
- An `ai-agent` container connected to that resource.
- Optional Kubernetes service-account and workload-identity metadata.

The file does not declare Ollama, Kaito, an Azure OpenAI account, a deployment SKU, an
API key, or a GPU. Those are platform concerns.

## Constraints

- Deploy the same `iac/ai.bicep` file to both targets.
- Keep AI disabled in `iac/app.bicep`; Challenge 08 is an additive deployment and must
  not erase the Challenge 06 OIDC configuration.
- Explicitly select and verify Kubernetes context, Radius workspace, group, and
  environment before every target stage.
- After a restart, reconnect K3s with
  `bash resources/prepare-k3s-azure-vm.sh connect` and use
  `~/.kube/adaptive-apps-k3s.yaml`.
- Do not expose the K3s VM or its Kubernetes API publicly. The API remains behind the
  localhost Azure Bastion tunnel.
- Do not require Kaito or a GPU on the default `Standard_D4s_v5` VM.
- Do not put Azure OpenAI keys, access tokens, credentials, or model responses containing
  sensitive data in source or evidence. The AKS core path must be keyless.
- Assign **Cognitive Services OpenAI User** only at the selected Azure OpenAI account
  scope. Do not grant `Contributor`, subscription-wide access, or a service-principal
  client secret.
- Treat model output as untrusted, non-deterministic workshop output, not financial
  advice.
- Keep Challenge 07 service-mesh and authorization-policy work out of this challenge.
- Use the workshop-scoped, ClusterIP-only OCI registry for recipe publication. It is
  intentionally ephemeral and unauthenticated inside the cluster; do not expose it
  externally or reuse that design for production.

## Tasks

### Task 1: Define the stable AI contract

Review `iac/ai.bicep` and the `Radius.Resources/aiModels` contract. Identify:

- The application-owned model intent and `ai-agent` connection.
- Values injected by the recipe.
- Identity metadata needed only on AKS.
- Hosting, availability, quota, and cost choices owned by each platform team.

Draw both request paths and mark what remains invariant:

1. Frontend -> AI agent -> local OpenAI-compatible endpoint -> CPU model.
2. Frontend -> AI agent -> Azure OpenAI endpoint -> approved deployment.

### Task 2: Implement and prove the K3s recipe

Reconnect the Bastion tunnel and select `k3s-azure-vm`, `ws-local-prod`, `rg-trading`,
and `env-local-prod`.

On K3s:

- Deploy the local ClusterIP recipe registry.
- Publish `iac/recipes/ai-model-local-cpu.bicep` and register it as the default
  `Radius.Resources/aiModels` recipe.
- Deploy `iac/ai.bicep` with `qwen2.5:0.5b`.
- Observe model download and startup without assuming GPU acceleration.
- Inspect the Radius graph and backing Kubernetes resources.
- Expose the AI agent through the active Radius control plane and call `/health` and
  `/advice`.

Record first-start latency, CPU/memory limits, model persistence behavior, and why this
Azure-hosted K3s VM is neither AKS nor a disconnected edge device.

### Task 3: Implement keyless Azure OpenAI access on AKS

Stop K3s exposure and registry forwarding before changing targets. Select
`aks-adaptive-apps`, `ws-azure-prod`, `rg-trading`, and `env-azure-prod`.

Before deployment:

- Verify the Azure OpenAI account, endpoint, deployment name, underlying model/version,
  SKU, and capacity.
- Confirm AKS OIDC issuer and workload identity are enabled.
- Deploy the target's local recipe registry.
- Publish `iac/recipes/ai-model-azure-existing.bicep` and register it with the approved
  endpoint and deployment name.
- Create or reuse a user-assigned managed identity.
- Create one federated credential for the exact `ai-agent` service-account subject in
  the actual application namespace.
- Assign **Cognitive Services OpenAI User** at the account scope.
- Create and annotate the `ai-agent` Kubernetes service account.

Deploy the same `iac/ai.bicep` with workload identity enabled. Verify the pod label,
service account, projected token, federated credential, and narrow role assignment.
Then validate `/health` and `/advice` without printing a token or key.

### Task 4: Compare evidence, failure handling, and ownership

Capture non-secret evidence from each target:

- Four-part target selection.
- The same Radius application graph and AI contract.
- Different recipe registrations and backing resources.
- Provider, endpoint host, and model/deployment identifier from `/health`.
- Successful `/advice` response and a deliberate bad-request response.
- K3s pod resources and model-ready probe.
- AKS workload-identity label, service account, federated subject, and role scope.

Create a comparison covering:

- Model quality and latency.
- Resource persistence and restart behavior.
- Network dependency and disconnected-operation claims.
- Azure quota, region, throughput, and per-token cost.
- Application-team and platform-team ownership.
- How a recipe rollback differs from an application rollback.

## Success criteria

- One `Radius.Resources/aiModels` contract and one `iac/ai.bicep` model are used on both
  platforms.
- K3s runs `qwen2.5:0.5b` on CPU within the default workshop VM limits; no Kaito or GPU
  success is claimed.
- AKS calls an existing Azure OpenAI deployment through an exact service-account
  federation and **Cognitive Services OpenAI User** at account scope.
- No API key, service-principal secret, access token, or credential appears in source,
  parameters, screenshots, or evidence.
- `rad app graph`, `rad resource list`, Kubernetes health, `/health`, and `/advice`
  demonstrate both implementations.
- The application state, recipe registry, and model implementation are recognized as
  independent on the two Radius control planes.
- The team can explain endpoint versus deployment-name versus model-name/version.
- Cost, quota, model quality, model-download persistence, and network limitations are
  documented honestly.

## Progressive hints

### Contract and recipes

1. The connection injects provider, endpoint, and model values into `ai-agent`.
2. A `RecipeNotFoundFailure` means the active environment lacks a matching recipe; do
   not add Ollama or Azure declarations to `iac/ai.bicep`.
3. Recipe OCI artifacts must be published into the registry on the same cluster as the
   selected Radius control plane.

### K3s

1. The default VM has no GPU; a small quantized model can still prove the contract on
   CPU.
2. The first startup includes an outbound model download and can take several minutes.
3. The workshop recipe uses ephemeral model storage, so pod replacement triggers another
   download.

### AKS identity

1. The federated subject has the form
   `system:serviceaccount:<application-namespace>:ai-agent`.
2. The service account needs the managed identity client ID; the pod needs
   `azure.workload.identity/use=true`.
3. A correct federation can still return `403` until the role assignment propagates.
4. A deployment name is the string sent to the Azure OpenAI API; it need not equal the
   underlying model name.

### Runtime validation

1. `/health` proves configuration and process health, not successful inference.
2. `/advice` proves the model call; expect different text and latency across providers.
3. A `502` usually points to endpoint, identity, quota, model readiness, or network
   failure. Inspect those layers before changing the app contract.

## Learning resources

- [Radius recipes](https://docs.radapp.io/guides/recipes/overview/)
- [Radius connections](https://docs.radapp.io/guides/author-apps/containers/overview/#connections)
- [AKS workload identity](https://learn.microsoft.com/azure/aks/workload-identity-overview)
- [Azure OpenAI role-based access control](https://learn.microsoft.com/azure/ai-services/openai/how-to/role-based-access-control)
- [Azure OpenAI deployment types](https://learn.microsoft.com/azure/ai-services/openai/how-to/deployment-types)
- [Azure OpenAI quotas and limits](https://learn.microsoft.com/azure/ai-services/openai/quotas-limits)
- [Ollama model library](https://ollama.com/library/qwen2.5)
- [Kubernetes resource management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

## Optional GPU extension

Kaito is an optional extension only when a target has a supported GPU node, drivers,
device plugin, storage, and sufficient capacity. Record those prerequisites and costs
before selecting the source Kaito recipe. Do not resize the default VM or deploy a GPU
merely to complete the core challenge.
