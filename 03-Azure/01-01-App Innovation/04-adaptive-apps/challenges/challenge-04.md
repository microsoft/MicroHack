# Challenge 04 - Implement the platform abstractions with recipes

[< Previous Challenge](challenge-03.md) - **[Home](../Readme.md)** - [Next Challenge >](challenge-05.md)

Estimated time: 60-90 minutes | Difficulty: advanced

## Challenge objective

Implement the portable resource-type contracts from Challenge 03. Manually author,
publish, and register an Azure SQL recipe before registering the complete
environment-specific recipe sets for AKS and K3s.

AKS will use Azure-backed implementations where appropriate. K3s will use in-cluster
implementations.

## Learning goals

- Explain how a recipe implements a resource-type contract.
- Use Radius recipe `context` without coupling an application to a platform.
- Return ordinary values, secrets, and managed resource identifiers correctly.
- Publish a Bicep recipe to an OCI registry and register it with an environment.
- Compare recipe mappings for the same types across Azure and Local environments.

## Tasks

### Task 1: Design the custom Azure SQL recipe

Author `iac/recipes/sql-server.bicep` to implement
`Radius.Resources/sqlDatabases`.

Your recipe should:

- Accept the Radius-provided `context` object.
- Read the requested size from `context.resource.properties`.
- Map `S`, `M`, and `L` to appropriate SQL SKU values.
- Create deterministic resource names from the Radius resource ID.
- Use an [Azure Verified Module](https://aka.ms/avm) for Azure SQL.
- Add tags that identify the Radius environment, resource, and application.
- Return the SQL server resource ID in `result.resources`.
- Return host, port, database, and username in `result.values`.
- Return the administrator password in `result.secrets`.

Explain why the application developer does not provide an Azure resource group or
administrator password.

### Task 2: Publish and register the custom recipe on AKS

While targeting AKS and workspace `ws-azure-prod`:

1. Create or select a globally unique, lowercase Azure Container Registry.
2. Authenticate to the registry.
3. Publish `iac/recipes/sql-server.bicep` as version `1.0.0` under
   `recipes/sql-server`.
4. Register it as the default recipe for `Radius.Resources/sqlDatabases` in
   `env-azure-prod`.
5. Verify that the registration refers to the expected OCI artifact.

If Docker is unavailable, use a temporary OCI authentication configuration rather than
putting a registry token in source files.

### Task 3: Register the complete AKS recipe set

Deploy `iac/aks-env.bicep` as environment-as-code for:

- Workspace `ws-azure-prod`
- Group `rg-trading`
- Environment `env-azure-prod`
- Kubernetes namespace `env-azure-prod`

Provide the Azure subscription, lab resource group, managed Istio revision, and custom
SQL recipe path as parameters.

The resulting mappings should include Azure-backed PostgreSQL, MQTT, workload
identity, and AI implementations; in-cluster identity, governance, and guardrail
components; and the custom Azure SQL recipe.

### Task 4: Register the complete K3s recipe set

Switch both the Kubernetes context and Radius workspace to K3s, then deploy
`iac/local-env.bicep` for:

- Workspace `ws-local-prod`
- Group `rg-trading`
- Environment `env-local-prod`
- Kubernetes namespace `env-local-prod`

The Local mappings should use in-cluster implementations for PostgreSQL, MQTT,
identity, workload identity, AI, governance, and agent guardrails.

Registering an AI recipe does not deploy a model. GPU capacity is needed only when the
recipe is exercised in a later challenge.

### Task 5: Validate and compare

List the recipes in `env-azure-prod` and `env-local-prod`, then inspect them in the
dashboard for each control plane.

Prepare a comparison that answers:

- Which types resolve to Azure-managed services on AKS?
- Which types resolve to containers or Kubernetes resources on K3s?
- How do `result.values` and `result.secrets` satisfy the contract from Challenge 03?
- Why can the application declaration remain unchanged?

## Success criteria

- The custom SQL recipe is published to ACR at version `1.0.0`.
- The recipe is registered as the default `Radius.Resources/sqlDatabases`
  implementation in `env-azure-prod`.
- AKS has the expected Azure-backed and in-cluster recipe mappings.
- K3s has the expected in-cluster recipe mappings.
- Both environments expose their recipe registrations through the CLI and dashboard.
- The team can explain `context`, `result.resources`, `result.values`, and
  `result.secrets`.
- No application workload has been deployed yet.

## Hints

- Start from the resource-type schema. Every recipe output must satisfy that contract.
- Radius injects `context`; application developers do not pass it.
- Publishing an artifact and registering a recipe are separate steps. Validate each
  one before continuing.
- ACR names must be globally unique and lowercase.
- Check Kubernetes context, Radius workspace, group, and environment before each
  deployment.
- The Azure environment needs an Azure provider scope; the K3s environment does not.
- Environment-as-code makes a complete mapping repeatable, but author and register the
  custom recipe manually first.

## Optional automation and platforms

Manual authoring, publishing, and registration are the intended learning path. For
setup recovery or an explicit skip, `resources/configure-recipes.sh` can configure AKS,
K3s, or both after its required Azure values are supplied.

If Azure Local or Arc-enabled Kubernetes replaces K3s, start with
`iac/local-env.bicep` for in-cluster implementations unless the platform team
intentionally offers managed services.

## Learning resources

- [Radius recipes](https://docs.radapp.io/guides/recipes/overview/)
- [Author Bicep recipes](https://docs.radapp.io/guides/recipes/author-recipes/bicep/)
- [Azure Verified Modules](https://aka.ms/avm)
- [Publish Bicep to an OCI registry](https://docs.radapp.io/reference/cli/rad_bicep_publish/)
