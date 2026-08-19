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
kubectl rollout status deployment --all --namespace core --timeout=15m
kubectl rollout status statefulset --all --namespace core --timeout=15m
kubectl get pods --namespace core
```

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

In each workspace:

```bash
rad resource-type list
rad resource-type show Radius.Resources/sqlDatabases
rad resource-type show Radius.Resources/postgreSqlDatabases
rad resource-type show Radius.Resources/aiModels
```

Open the dashboard for the matching kube context:

```bash
kubectl port-forward service/dashboard \
  --namespace radius-system 7007:80
```

Inspect:

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

No recipes should be registered yet. Recipes are introduced in Challenge 04.

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
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm

# Run from the Adaptive Apps MicroHack root.
bash resources/configure-resource-types-k3s.sh
```

Both scripts accept `TYPES_URL` to override the pinned catalog and
`BICEP_EXTENSION_TARGET` to choose the generated package location. Set `PORTFOLIO` to
choose another profile.
