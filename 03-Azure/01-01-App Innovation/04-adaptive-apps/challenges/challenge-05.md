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
- Do not create application workload identities in this challenge. Challenge 06 owns
  identity adaptation. The Azure deployment may therefore prove graph and resource
  portability before Azure MQTT publish/subscribe reaches full runtime parity.
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

Deploy `iac/app.bicep`, inspect the graph and resources, check Kubernetes workload
health, and expose the frontend through the active K3s Radius control plane.

### Task 3: Prove the AKS deployment

Stop the K3s frontend exposure before switching targets. Explicitly select:

- Kubernetes context `aks-adaptive-apps`
- Radius workspace `ws-azure-prod`
- Radius group `rg-trading`
- Radius environment `env-azure-prod`

Verify the Azure credential registration from Challenge 02 and the required recipe
mappings from Challenge 04. Deploy the same `iac/app.bicep` file with the same image
inputs, then inspect the graph, Kubernetes resources, Azure backing resources, and
frontend exposure.

### Task 4: Compare evidence and ownership

Capture a side-by-side comparison that shows:

- The same application model and resource-type contracts on both targets.
- A local PostgreSQL and MQTT implementation on K3s.
- Azure Database for PostgreSQL and Azure Event Grid MQTT implementations on AKS.
- Independent application state in each Radius control plane.
- Parameters that changed and parameters that stayed the same.
- Application-team responsibilities versus platform-team responsibilities.
- Known runtime gaps, especially Azure Event Grid MQTT authorization.

## Success criteria

- `iac/app.bicep` is deployed unchanged to both target environments.
- Every deployment is preceded by an explicit four-part target check.
- Both Radius control planes show an `adaptive-apps` graph with frontend, backend,
  PostgreSQL, MQTT, and workload-identity resources.
- The backing implementations differ according to each environment's recipes.
- The frontend can be exposed through each active control plane, one at a time.
- No password or cluster credential is committed or captured in evidence.
- The team can explain why deployment portability is proven even though Azure MQTT
  publish/subscribe still requires topic-space and permission configuration.
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

1. Successful provisioning and a reachable frontend do not prove every MQTT flow.
2. Event Grid MQTT requires topic spaces, permission bindings, and federated workload
   identities in addition to an endpoint.
3. Record the gap; do not bypass identity with a shared secret.

## Learning resources

- [Deploy applications with Radius](https://docs.radapp.io/guides/deploy-apps/)
- [Radius environments](https://docs.radapp.io/guides/deploy-apps/environments/overview/)
- [Radius workspaces](https://docs.radapp.io/guides/operations/workspaces/overview/)
- [Radius recipes](https://docs.radapp.io/guides/recipes/overview/)
- [AKS workload identity](https://learn.microsoft.com/azure/aks/workload-identity-overview)
- [Azure Event Grid MQTT](https://learn.microsoft.com/azure/event-grid/mqtt-overview)
