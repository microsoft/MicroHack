# Challenge 05 - Port the App Across Environments

[< Previous Challenge](challenge-04.md) - **[Home](../Readme.md)** - [Next Challenge >](challenge-06.md)

Estimated time: 45-75 minutes | Difficulty: intermediate to advanced

## Challenge objective

Prove that the same application model can be deployed to the private K3s platform and
AKS without embedding either platform's implementation details in the application.
Only the selected target, environment parameters, and platform-managed recipes may
change.

## Learning goals

- Define the portability boundary between application and platform concerns.
- Prevent deployment drift by checking Kubernetes context, Radius workspace, group,
  and environment together.
- Deploy one application model through two independent Radius control planes.
- Compare application graphs, resource implementations, and runtime outcomes.
- Distinguish deployment portability from complete runtime parity.

## Fixed target map

Use the exact target map established in Challenges 01-04:

| Platform | Kubernetes context | Radius workspace | Environment | Radius group |
| --- | --- | --- | --- | --- |
| Private K3s through Bastion | `k3s-azure-vm` | `ws-local-prod` | `env-local-prod` | `rg-trading` |
| AKS | `aks-adaptive-apps` | `ws-azure-prod` | `env-azure-prod` | `rg-trading` |

The two workspaces target independent Radius control planes. An application named
`adaptive-apps` in one control plane is not the same Radius object as the application
with that name in the other.

## Constraints

- Deploy `iac/app.bicep` unchanged to both platforms.
- Use the published `ghcr.io/microsoft/adaptive-apps` images; do not rebuild the
  application.
- Explicitly switch both Kubernetes and Radius targets before every deployment.
- Restore the K3s localhost API tunnel after a devcontainer restart. The dedicated
  kubeconfig is `~/.kube/adaptive-apps-k3s.yaml`, and its API endpoint is localhost.
- Use the resource types and recipes produced in Challenges 03 and 04. Repair a missing
  platform mapping in the environment layer, not in the application model.
- Prompt for the frontend password. Do not put credentials in source, shell history,
  screenshots, or evidence files.
- Keep AI disabled. Challenge 08 owns AI adaptation.
- Do not add Azure Event Grid MQTT authorization in this challenge. On AKS the
  `mqttBrokers` contract intentionally resolves to an in-cluster broker, because the
  published application cannot perform the MQTT v5 enhanced authentication that Event
  Grid requires. Change the recipe registration if you must, never the application model,
  and never add a shared secret.
- Reach the frontend only through `rad resource expose` or Kubernetes port-forwarding.
  Do not expose ports on the private K3s VM.

## Tasks

### Task 1: Define the portability boundary

Review `iac/app.bicep` and identify:

- Application-team inputs and resources that remain identical.
- Environment-specific choices supplied at deployment time.
- Platform implementations selected through recipes.
- Features intentionally deferred to later challenges.

Create a parity checklist covering target selection, resource-type availability,
recipes, deployment, graph validation, backing resources, and frontend exposure.

### Task 2: Prove the K3s deployment

Restore the Bastion tunnel if needed, then explicitly select:

- Kubernetes context `k3s-azure-vm`
- Radius workspace `ws-local-prod`
- Radius group `rg-trading`
- Radius environment `env-local-prod`

Verify that the generated Bicep extension from Challenge 03 is available and that the
required PostgreSQL, MQTT, and workload-identity recipes are registered.

Deploy `iac/app.bicep`, wait for recipe-owned schema initialization, prove the four
tables and single `Demo Account` seed through safe metadata checks, inspect the graph and
resources, check backend database access, and expose the frontend through the active K3s
Radius control plane.

### Task 3: Prove the AKS deployment

Stop the K3s frontend exposure before switching targets. Explicitly select:

- Kubernetes context `aks-adaptive-apps`
- Radius workspace `ws-azure-prod`
- Radius group `rg-trading`
- Radius environment `env-azure-prod`

Verify the Azure credential registration from Challenge 02 and the required recipe
mappings from Challenge 04. Deploy the same `iac/app.bicep` file with the same image
inputs, then inspect the graph, Kubernetes resources, Azure backing resources, and
frontend exposure. Repeat the same schema, seed, and backend database-access checks and
confirm the initializer requires TLS.

### Task 4: Compare evidence and ownership

Capture a side-by-side comparison that shows:

- The same application model and resource-type contracts on both targets.
- A local PostgreSQL and MQTT implementation on K3s.
- Azure Database for PostgreSQL on AKS, and the same in-cluster MQTT broker on both.
- Independent application state in each Radius control plane.
- Parameters that changed and parameters that stayed the same.
- Application-team responsibilities versus platform-team responsibilities.
- Known runtime gaps, and why a recipe can differ from the "obvious" cloud service.

## Success criteria

- `iac/app.bicep` is deployed unchanged to both target environments.
- Every deployment is preceded by an explicit four-part target check.
- Both Radius control planes show an `adaptive-apps` graph with frontend, backend,
  PostgreSQL, MQTT, and workload-identity resources.
- The backing implementations differ according to each environment's recipes.
- Both implementations contain `accounts`, `orders`, `trades`, and `positions`, exactly
  one `Demo Account`, and a backend that is Ready only after `/api/accounts` succeeds.
- The frontend can be exposed through each active control plane, one at a time.
- No password or cluster credential is committed or captured in evidence.
- The team can explain why deployment portability is proven even though the AKS
  environment resolves `mqttBrokers` to an in-cluster broker rather than Event Grid.
- The ownership split is clear: application teams own the model and safe parameters;
  platform teams own control planes, environments, provider scopes, recipes, and
  backing-service policy.

## Progressive hints

### Targeting

1. A valid Kubernetes context does not select the Radius control plane.
2. Compare the active context with the workspace target before deploying.
3. On K3s, the Bastion process must be running because the kubeconfig endpoint is
   `https://127.0.0.1:16443`.

### Resource readiness

1. Radius installation alone does not make custom resource types deployable.
2. The application needs the extension package generated from the Challenge 03 catalog.
3. A `RecipeNotFoundFailure` is an environment-layer problem. Return to Challenge 04.

### Deployment and validation

1. Keep the Bicep file path and image values identical.
2. Each Radius control plane has its own application graph and state.
3. Stop a foreground exposure before switching workspaces, then start a new exposure
   against the newly active control plane.

### Runtime parity

1. A recipe that provisions successfully does not prove the application can use what it
   provisioned.
2. Event Grid MQTT accepts an Entra token only through MQTT v5 enhanced authentication,
   not as a CONNECT password. A client that gets this wrong is refused at connect time.
3. A crash-looping background service can fail a whole deployment: .NET stops the host by
   default when a `BackgroundService` throws.
4. The fix belongs in the recipe registration, not in `iac/app.bicep`. Never bypass
   identity with a shared secret.

## Learning resources

- [Deploy applications with Radius](https://docs.radapp.io/guides/deploy-apps/)
- [Radius environments](https://docs.radapp.io/guides/deploy-apps/environments/overview/)
- [Radius workspaces](https://docs.radapp.io/guides/operations/workspaces/overview/)
- [Radius recipes](https://docs.radapp.io/guides/recipes/overview/)
- [AKS workload identity](https://learn.microsoft.com/azure/aks/workload-identity-overview)
- [Azure Event Grid MQTT](https://learn.microsoft.com/azure/event-grid/mqtt-overview)
