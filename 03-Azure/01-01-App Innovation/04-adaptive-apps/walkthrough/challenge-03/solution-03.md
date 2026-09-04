# Walkthrough Challenge 03 - Build the platform abstractions

[< Previous Solution](../challenge-02/solution-02.md) - **[Home](../../Readme.md)** - [Next Solution](../challenge-04/solution-04.md)

Duration: 45-75 minutes

## Coach notes

This challenge makes the platform-engineering story concrete. Teams define the
vocabulary that application developers use in later challenges.

The sequence is deliberate:

1. Install a capability portfolio that represents the platform contract.
2. Create one resource type manually to understand the schema.
3. Import the full catalog to establish a realistic platform foundation.

Do not let teams confuse a resource type with a recipe:

- A **resource type** is a versioned schema and contract.
- A **recipe** is an environment-specific implementation of that contract.

The manual steps are the learning path. Optional scripts at the end perform the same
registration for participants who need an automated setup.

Before any K3s work after a devcontainer restart, restore the localhost API tunnel:

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
bash resources/prepare-k3s-azure-vm.sh connect
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
```

## Capability portfolio

The portfolio establishes the baseline capabilities offered by the platform before
teams define and implement portable contracts. This is the cleanest point in the
storyline to install it: platform infrastructure and Radius are ready, and recipes are
introduced next in Challenge 04.

The default profile is `core` on both platforms:

- Identity through Keycloak and PostgreSQL
- Service mesh with strict mTLS
- Observability through OpenTelemetry, Prometheus, and Zipkin

AKS uses its managed Istio add-on. K3s installs Istio through the portfolio chart.

## Manual tutorial, Stage 0: Install the portfolio

Clone the pinned Adaptive Apps source used by this MicroHack, or point
`ADAPTIVE_APPS_REPO` at an existing checkout of the same commit:

```bash
export MICROHACK_DIR="$(pwd)"
git clone https://github.com/microsoft/adaptive-apps.git /tmp/adaptive-apps
cd /tmp/adaptive-apps
git checkout 885627980684e5bcc6fe4bbd2848c1ec247b0a0b
export ADAPTIVE_APPS_REPO="$(pwd)"
cd "$MICROHACK_DIR"
```

### Install manually on AKS

```bash
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps

export PORTFOLIO=core
helm upgrade --install "$PORTFOLIO" \
  "$ADAPTIVE_APPS_REPO/charts/adaptive-apps" \
  --values "$ADAPTIVE_APPS_REPO/charts/adaptive-apps/profiles/${PORTFOLIO}.yaml" \
  --set features.istio.install=false \
  --set istio.namespace=aks-istio-system \
  --namespace "$PORTFOLIO" \
  --create-namespace
```

### Install manually on K3s

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
bash resources/prepare-k3s-azure-vm.sh connect
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm

export PORTFOLIO=core
helm upgrade --install "$PORTFOLIO" \
  "$ADAPTIVE_APPS_REPO/charts/adaptive-apps" \
  --values "$ADAPTIVE_APPS_REPO/charts/adaptive-apps/profiles/${PORTFOLIO}.yaml" \
  --namespace "$PORTFOLIO" \
  --create-namespace
```

K3s was prepared without its bundled Traefik ingress controller so the portfolio can
install and use its own Istio stack without an ingress-controller conflict.

### Validate the portfolio

Run against each context:

```bash
helm status core --namespace core
kubectl wait --for=condition=Available deployments --all --namespace core --timeout=15m
kubectl rollout status statefulset/core-keycloak-postgresql --namespace core --timeout=15m
kubectl get pods --namespace core
```

`kubectl rollout status` accepts a single object, so use `kubectl wait` for the
deployments and name each statefulset explicitly.

Do not continue until the workloads are healthy.

## Resource-type concepts

A Radius resource type defines:

- Input properties supplied by an application developer
- Read-only outputs returned by a recipe
- Secrets that must not appear in plain text

```text
Application developer writes              Platform returns
------------------------------------       --------------------------------
size: S                                   host: sql.prod.svc
environment: <environment-id>              port: 1433
application: <application-id>              secrets.password: <secret>
```

Resource types live in a namespace such as `Radius.Resources`. A type has no
implementation by itself. Different environments can register different recipes for
the same type while the application declaration remains unchanged.

## Manual tutorial, Stage 1: Create a SQL Server type

Create `iac/sql-databases.yaml`:

```yaml
namespace: Radius.Resources
types:
  sqlDatabases:
    description: A portable Microsoft SQL Server database resource.
    apiVersions:
      '2025-08-01-preview':
        schema:
          type: object
          properties:
            environment:
              type: string
              description: (Required) The Radius Environment ID.
            application:
              type: string
              description: (Required) The Radius Application ID.
            size:
              type: string
              enum: [S, M, L]
              description: (Optional) Size tier.
            host:
              type: string
              readOnly: true
              description: SQL Server hostname or IP.
            port:
              type: integer
              readOnly: true
              description: SQL Server port.
            database:
              type: string
              readOnly: true
              description: Database name.
            username:
              type: string
              readOnly: true
              description: Login username.
            secrets:
              type: object
              readOnly: true
              properties:
                password:
                  type: string
                  readOnly: true
                  description: Login password.
              required: [password]
          required: [environment, application]
```

### Register manually on AKS

```bash
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps
rad workspace switch ws-azure-prod

rad resource-type create \
  --workspace ws-azure-prod \
  --from-file iac/sql-databases.yaml
```

### Register manually on K3s

```bash
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
rad workspace switch ws-local-prod

rad resource-type create \
  --workspace ws-local-prod \
  --from-file iac/sql-databases.yaml
```

Discuss:

- Which properties are developer inputs?
- Why are outputs marked `readOnly`?
- Why is the password nested under `secrets`?
- Would an Azure SQL recipe require this contract to change?

## Manual tutorial, Stage 2: Import the catalog

The source catalog is pinned to the Adaptive Apps commit used to author this
MicroHack:

```bash
export TYPES_URL="https://raw.githubusercontent.com/microsoft/adaptive-apps/885627980684e5bcc6fe4bbd2848c1ec247b0a0b/radius/resource-types/types.yaml"
curl --fail --location "$TYPES_URL" --output /tmp/adaptive-apps-types.yaml
```

Review the downloaded schema before registering it.

### Import manually on AKS

```bash
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps
rad workspace switch ws-azure-prod

rad resource-type create \
  --workspace ws-azure-prod \
  --from-file /tmp/adaptive-apps-types.yaml
```

### Import manually on K3s

```bash
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
rad workspace switch ws-local-prod

rad resource-type create \
  --workspace ws-local-prod \
  --from-file /tmp/adaptive-apps-types.yaml
```

Generate the Bicep extension once per workstation:

```bash
mkdir -p artifacts
rad bicep publish-extension \
  --from-file /tmp/adaptive-apps-types.yaml \
  --target artifacts/types.tgz \
  --force
```

The catalog includes portable types for PostgreSQL, MQTT, workload identity, identity
providers, AI models, governance, and agent guardrails.

## Explore and validate

Run this section once for each target pair:

| Platform | Kubernetes context | Radius workspace | Group | Environment |
| --- | --- | --- | --- | --- |
| AKS | `aks-adaptive-apps` | `ws-azure-prod` | `rg-trading` | `env-azure-prod` |
| Private K3s through Bastion | `k3s-azure-vm` | `ws-local-prod` | `rg-trading` | `env-local-prod` |

The Kubernetes context selects cluster objects such as the portfolio and Radius
dashboard. The Radius workspace selects the independent Radius control plane queried by
`rad resource-type`. Those selectors do not change each other.

### 1. Select and confirm one target

For AKS:

```bash
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps
rad workspace switch ws-azure-prod
rad group switch rg-trading
rad env switch env-azure-prod
```

For K3s, restore the localhost Bastion API tunnel first. The dedicated kubeconfig points
to that local endpoint; it does not expose K3s publicly.

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
bash resources/prepare-k3s-azure-vm.sh connect
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
rad workspace switch ws-local-prod
rad group switch rg-trading
rad env switch env-local-prod
```

These commands select existing objects; they do not create another cluster, workspace,
group, or environment. `kubectl config use-context` reports the context it selected,
the three `rad ... switch` commands update local CLI defaults, and
`prepare-k3s-azure-vm.sh connect` starts or reuses the localhost Bastion tunnel needed
to reach the private K3s API.

Now inspect the four selectors:

```bash
kubectl config current-context
rad workspace show
rad group show rg-trading
rad env show
```

| Command | Stable indicators | Why it exists and when it was created | Scope |
| --- | --- | --- | --- |
| `kubectl config current-context` | Exactly `aks-adaptive-apps` or `k3s-azure-vm` for the row being validated | Challenge 01 created or retrieved the cluster credentials; Challenge 02 selected the context before installing Radius | Local kubeconfig selection; subsequent `kubectl` commands reach that Kubernetes cluster |
| `rad workspace show` | Workspace name `ws-azure-prod` with connection context `aks-adaptive-apps`, or `ws-local-prod` with `k3s-azure-vm` | Solution 02 **AKS Step 4** or **K3s Step 3** ran `rad workspace create kubernetes`; `rad workspace switch` selected it | Local CLI configuration in `~/.rad/config.yaml` that points to one Radius control plane |
| `rad group show rg-trading` | Group name `rg-trading`; it is a Radius group, not an Azure resource group | Solution 02 **AKS Step 4** or **K3s Step 3** ran `rad group create rg-trading` independently on each control plane | Active Radius workspace/control plane |
| `rad env show` | `env-azure-prod` with Kubernetes namespace `env-azure-prod` and Azure provider scope, or `env-local-prod` with namespace `env-local-prod` and no Azure provider | Solution 02 **AKS Step 4** or **K3s Step 3** ran `rad env create`; the AKS step then ran `rad env update` to add its Azure scope | Active Radius workspace, group, and environment |

Output formatting can vary by Radius CLI version. Validate the names and connection or
compute fields rather than column order. Resource types are control-plane-wide
definitions selected by the workspace; the group and environment do not own them. The
group and environment checks confirm the complete target state that later recipe and
application commands will use.

Do not continue with a mixed pair. For example, `k3s-azure-vm` plus
`ws-azure-prod` would inspect the K3s portfolio but query the AKS Radius control plane.

### 2. Recheck the capability portfolio

```bash
helm status core --namespace core
helm list --namespace core --filter '^core$'
kubectl get deployments,statefulsets,services,pods --namespace core
kubectl get crd peerauthentications.security.istio.io
kubectl get peerauthentication --all-namespaces --output yaml
```

| Command or object | Stable indicators | Role | Created by |
| --- | --- | --- | --- |
| `helm status core --namespace core` | Release `core`, namespace `core`, and status `deployed`; revision and timestamps may differ | Reports health and release metadata for the selected `core` capability profile | Stage 0 `helm upgrade --install core ... --namespace core --create-namespace`, or the matching optional `configure-resource-types-*.sh` script |
| `helm list --namespace core --filter '^core$'` | One `core` row with chart `adaptive-apps-0.1.0` and status `deployed` | Confirms that the expected pinned portfolio chart backs the release | The same Stage 0 Helm command |
| Namespace `core` | The namespace exists and contains the release objects below | Isolates the shared identity and observability portfolio from Radius and application namespaces | Stage 0's Helm command through `--create-namespace` |
| Deployment `core-keycloak` and StatefulSet `core-keycloak-postgresql` | Workloads report their desired replicas ready; pod names include generated suffixes and are not stable | Keycloak is the shared identity broker; PostgreSQL persists its configuration and users | The identity feature in the Stage 0 `core` profile |
| Deployments and Services `otel-collector`, `prometheus`, and `zipkin` | Deployments become Available and Services are `ClusterIP`; exact pod counts or suffixes are not part of the contract | Receive OTLP data and provide workshop metrics and trace collection/query paths | The observability feature in the Stage 0 `core` profile |
| CRD `peerauthentications.security.istio.io` | The CRD exists and normally reports condition `Established=True` | Defines Istio's `PeerAuthentication` policy object | On AKS, the managed Istio add-on enabled in Challenge 01; on K3s, the Istio base release launched by the Stage 0 portfolio pre-install hook |
| `PeerAuthentication/default` | Namespace `aks-istio-system` on AKS or `istio-system` on K3s, with `spec.mtls.mode: STRICT` | Establishes mesh-wide strict mutual TLS for workloads enrolled in the mesh | The Stage 0 portfolio post-install hook |

The `core` profile does not enable OPA, AI, or agent-guardrail workloads. Do not expect
those objects here. On K3s the Stage 0 hook also installs separate `istio-base` and
`istiod` Helm releases in `istio-system`; on AKS the portfolio reuses the managed Istio
add-on in `aks-istio-system`. Stable workload readiness matters more than an exact pod
count because chart and platform versions can change replicas and generated pod names.

These are Kubernetes objects selected by the current kube context. They are not Radius
resource types and are not stored in `ws-azure-prod` or `ws-local-prod`.

### 3. Inspect the registered contracts

In each workspace, preserve the following commands:

```bash
rad resource-type list
rad resource-type show Radius.Resources/sqlDatabases
rad resource-type show Radius.Resources/postgreSqlDatabases
rad resource-type show Radius.Resources/aiModels
```

| Command | Stable indicators | Why the object exists and when it was registered | Scope |
| --- | --- | --- | --- |
| `rad resource-type list` | At least the eight `Radius.Resources/*` types listed below; other configured or built-in types and the total row count can vary with the installed Radius version | Lists contracts known to the selected control plane. `sqlDatabases` came from Stage 1; the other seven came from the Stage 2 catalog import | Radius control plane selected by the active workspace; not Kubernetes, group, or environment scoped |
| `rad resource-type show Radius.Resources/sqlDatabases` | API version `2025-08-01-preview`; required inputs `environment` and `application`; optional `size` values `S`, `M`, or `L`; read-only `host`, `port`, `database`, `username`, and `secrets.password` | This is the manually designed SQL contract from `iac/sql-databases.yaml`, registered separately by the Stage 1 `rad resource-type create` command | One independent definition in each Radius control plane |
| `rad resource-type show Radius.Resources/postgreSqlDatabases` | API version `2025-08-01-preview`; writable `environment`, `application`, and `size`; read-only `host`, `port`, `database`, `username`, and `secrets.password` | Provides the portable PostgreSQL vocabulary used by the application. Stage 2 imported it from `/tmp/adaptive-apps-types.yaml` | One independent definition in each Radius control plane |
| `rad resource-type show Radius.Resources/aiModels` | API version `2025-08-01-preview`; writable `environment`, `application`, and `model`; read-only `endpoint`, `provider`, and `secrets.apiKey` | Provides the portable AI-model vocabulary used in Challenge 08. Stage 2 imported it from the same catalog | One independent definition in each Radius control plane |

`rad resource-type show` displays a **definition**, not a deployed resource instance.
There is no provisioning status, Kubernetes pod, database, or AI model to find at this
stage. The schema tells Radius and Bicep which values an application may write and which
values a future recipe must return.

The complete expected custom catalog and its origin are:

| Resource type | Registered by |
| --- | --- |
| `Radius.Resources/sqlDatabases` | Stage 1 manual `rad resource-type create --from-file iac/sql-databases.yaml` |
| `Radius.Resources/agentGuardrails` | Stage 2 catalog import |
| `Radius.Resources/aiModels` | Stage 2 catalog import |
| `Radius.Resources/governance` | Stage 2 catalog import |
| `Radius.Resources/idProviders` | Stage 2 catalog import |
| `Radius.Resources/mqttBrokers` | Stage 2 catalog import |
| `Radius.Resources/postgreSqlDatabases` | Stage 2 catalog import |
| `Radius.Resources/workloadIdentities` | Stage 2 catalog import |

Every custom type currently uses API version `2025-08-01-preview`. Each Stage 1 and
Stage 2 `rad resource-type create --workspace ...` command was run twice because the
control planes are federated. Registering a type on AKS does not make it available on
K3s, or vice versa.

### 4. Confirm the local Bicep extension

```bash
test -s artifacts/types.tgz
ls -lh artifacts/types.tgz
grep -n '"radiusResources"' iac/bicepconfig.json
```

| Object | Expected | Why and when it was created | Scope |
| --- | --- | --- | --- |
| `artifacts/types.tgz` | A non-empty generated archive; size and timestamp depend on the tool version | Stage 2 ran `rad bicep publish-extension` after downloading the catalog. The optional scripts run the same command and overwrite this path with `--force` | Local generated artifact on the participant workstation; intentionally not registered with either control plane |
| `radiusResources` entry in `iac/bicepconfig.json` | Maps the extension name to `../artifacts/types.tgz` | Lets Bicep compile declarations such as `Radius.Resources/postgreSqlDatabases@2025-08-01-preview` with the catalog's types | Repository configuration consumed locally by Bicep |

The extension contains compile-time type metadata generated from the catalog. It does
not contain a recipe or deploy a backing service. The generated archive is gitignored.
One workstation copy can compile models for both platforms, while each control plane
still needs its own Stage 1 and Stage 2 type registration.

### 5. Confirm the recipe boundary

```bash
rad recipe list
```

After Challenges 00-03 only, the active environment should have no recipe rows for the
custom `Radius.Resources/*` contracts introduced here. A Radius version may show
built-in environment recipes; custom rows indicate that the environment was
preconfigured or has already advanced into Challenge 04. In every case, the type import
itself did not create a recipe.

A **resource type** declares the portable contract in the Radius control plane.
A **recipe** associates an implementation template with that contract in a particular
Radius environment. Challenge 04 registers different recipes in `env-azure-prod` and
`env-local-prod`; that is when declarations can provision Azure-managed or in-cluster
implementations.

### 6. Inspect the matching Radius control plane

Open the dashboard for the matching kube context:

```bash
kubectl port-forward service/dashboard \
  --namespace radius-system 7007:80
```

Expect a foreground message that local port `7007` is forwarding to the dashboard
Service. Open <http://localhost:7007>. The `dashboard` Service and the `radius-system`
namespace were created by `rad install kubernetes` in Solution 02 **AKS Step 3** or
**K3s Step 2**. They belong to the Kubernetes-hosted Radius control plane, not to the
`core` portfolio.

The dashboard shows the control plane in the current Kubernetes context. Compare it
with `rad workspace show`; a mismatched workspace can make CLI and dashboard results
appear inconsistent even though both are functioning.

Inspect each contract for:

- Developer inputs
- Read-only outputs
- Secret properties
- API versions

At least these types should be present:

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

Stop the foreground port-forward before switching clusters. K3s dashboard access
depends on the active Bastion API tunnel, but the dashboard itself is never exposed
through a public K3s or VM endpoint.

## Optional platforms

If Azure Local or Arc-enabled Kubernetes replaces K3s, run the same resource-type
commands against that platform's Radius workspace. Resource-type schemas are
platform-independent.

## Optional automation

These scripts install the portfolio and perform both resource-type stages against one
environment. Use them only when the participant chooses to skip the step-by-step
tutorial.

### AKS

```bash
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps

# Run from the Adaptive Apps MicroHack root.
bash resources/configure-resource-types-aks.sh
```

### K3s

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
bash resources/prepare-k3s-azure-vm.sh connect
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm

# Run from the Adaptive Apps MicroHack root.
bash resources/configure-resource-types-k3s.sh
```

Both scripts accept `TYPES_URL` to override the pinned catalog and
`BICEP_EXTENSION_TARGET` to choose the generated package location. Set `PORTFOLIO` to
choose another profile.
