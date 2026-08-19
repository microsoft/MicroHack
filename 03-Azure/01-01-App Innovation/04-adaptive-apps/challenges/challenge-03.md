# Challenge 03 - Build the platform abstractions

[< Previous Challenge](challenge-02.md) - **[Home](../Readme.md)** - [Next Challenge >](challenge-04.md)

Estimated time: 45-75 minutes | Difficulty: intermediate

## Challenge objective

Install the Adaptive Apps capability portfolio, then define the portable contracts that
application developers use in later challenges. Create one resource type manually
before importing and inspecting the complete catalog on both Radius control planes.

The sequence is deliberate:

1. Establish the platform capability baseline.
2. Define and register a resource-type contract.
3. Import the shared contract catalog.
4. Implement the contracts with recipes in Challenge 04.

## Learning goals

- Explain the difference between a resource type and a recipe.
- Install the same capability portfolio across Azure and Local platforms.
- Model developer inputs, read-only outputs, and secrets in a resource type.
- Register resource types independently with each Radius control plane.
- Generate a Bicep extension from a Radius resource-type catalog.

Before the first K3s command, restore the localhost API tunnel after any container
restart:

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
bash resources/prepare-k3s-azure-vm.sh connect
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
```

## Tasks

### Task 1: Install the `core` capability portfolio

Use the Adaptive Apps source pinned by the coach and install the `core` profile on both
platforms.

On AKS:

- Use context `aks-adaptive-apps`.
- Install release `core` in namespace `core`.
- Reuse the AKS managed Istio add-on rather than installing Istio from the portfolio.

On K3s:

- Use the dedicated K3s kubeconfig and context `k3s-azure-vm`.
- Install release `core` in namespace `core`.
- Allow the portfolio to install its own Istio components.

Validate the Helm release, deployments, stateful sets, and pods on each platform. Do
not proceed while a portfolio workload is unhealthy.

### Task 2: Design a portable SQL database contract

Create `iac/sql-databases.yaml` with a resource type named
`Radius.Resources/sqlDatabases`.

The contract must:

- Belong to the `Radius.Resources` namespace.
- Use API version `2025-08-01-preview`.
- Require Radius environment and application identifiers.
- Accept a size input with tiers `S`, `M`, and `L`.
- Return host, port, database, and username as read-only values.
- Return the database password through a read-only `secrets` object.

Before registration, explain which properties an application developer supplies and
which properties a recipe supplies.

### Task 3: Register the custom type on both control planes

Register `iac/sql-databases.yaml` separately:

- In workspace `ws-azure-prod` while targeting AKS
- In workspace `ws-local-prod` while targeting K3s

Inspect `Radius.Resources/sqlDatabases` after each registration and confirm that its
schema matches the intended contract.

### Task 4: Import the shared resource-type catalog

Download the catalog from the pinned Adaptive Apps source, review it, and register it
on both Radius control planes.

The catalog should provide these portable types:

```text
Radius.Resources/agentGuardrails
Radius.Resources/aiModels
Radius.Resources/governance
Radius.Resources/idProviders
Radius.Resources/mqttBrokers
Radius.Resources/postgreSqlDatabases
Radius.Resources/sqlDatabases
Radius.Resources/workloadIdentities
```

Generate a local Bicep extension package at `artifacts/types.tgz` from the same catalog.
This artifact is generated once per workstation.

### Task 5: Explore the contracts

Use the Radius CLI and dashboard on both platforms to inspect:

- Required developer inputs
- Read-only outputs
- Secret properties
- API versions

Prepare a short explanation of how the same resource type can use an Azure-managed
implementation on AKS and an in-cluster implementation on K3s without changing the
application declaration.

## Success criteria

- The `core` Helm release is healthy on AKS and K3s.
- `Radius.Resources/sqlDatabases` exists in both Radius installations.
- The complete Adaptive Apps resource-type catalog exists in both installations.
- The team can distinguish developer inputs, recipe outputs, and secrets.
- `artifacts/types.tgz` is generated successfully.
- The team can explain why a resource type is platform-independent.
- No recipes are registered yet.

## Hints

- A resource type is a versioned schema and contract; it has no implementation by
  itself.
- Use `readOnly` for properties returned by a recipe.
- Keep sensitive output under `secrets` rather than exposing it as an ordinary value.
- Resource types are stored in the selected control plane, so repeat registration in
  both workspaces.
- The Bicep extension package is local to the workstation and does not need to be
  generated once per cluster.
- Verify both Kubernetes context and Radius workspace before every registration.

## Optional automation and platforms

Manual portfolio installation and type registration are the intended learning path.
For setup recovery or an explicit skip, these scripts perform the same sequence for one
environment:

- `resources/configure-resource-types-aks.sh`
- `resources/configure-resource-types-k3s.sh`

If Azure Local or Arc-enabled Kubernetes replaces K3s, register the same
platform-independent schemas with that platform's Radius workspace.

## Learning resources

- [Radius resource types](https://docs.radapp.io/guides/author-apps/custom-resources/)
- [Resource type CLI reference](https://docs.radapp.io/reference/cli/rad_resource-type/)
- [Radius recipes](https://docs.radapp.io/guides/recipes/overview/)
- [Bicep extensions](https://learn.microsoft.com/azure/azure-resource-manager/bicep/bicep-extension)
