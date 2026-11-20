---
title: Walkthrough Challenge 07 - Adapt Identity Services
description: Prove one frontend OIDC contract with local Keycloak users and Entra SAML federation.
---

[< Previous Solution](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/walkthrough/challenge-06/solution-06.md) - **[Home](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/Readme.md)** - [Next Solution](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/walkthrough/challenge-09/solution-09.md)

Duration: 60-90 minutes. The shorter path reduces copying; a new completion-time
estimate requires a learner pilot.

## 1. Understand the contract and check your starting point

This is optional after hosted Challenge 06. Confirm organizer support for Entra
enterprise-app/SAML administration; lab resource-group Owner alone is insufficient.
Hosted participants use Bash and source `artifacts/console-env.sh` in each new
terminal. Browser port-forwards and OIDC need the
[hosted-browser considerations](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/docs/console-setup.md#optional-extensions-and-hosted-browsers).
Continue directly to 09: 08 is not yet published.

This challenge is about **end-user authentication**. It does not replace the federated
identity Radius uses to deploy Azure resources, and it does not complete the workload
identity and authorization needed by Event Grid MQTT.

```text
K3s: frontend --OIDC--> Keycloak --> local-trader
AKS: frontend --OIDC--> Keycloak --SAML--> Microsoft Entra ID
```

The same `iac/app.bicep`, frontend image inputs, client ID `adaptive-apps`,
authorization-code flow and callback work in both places. The brokers, application
state and client secrets are independent. This demonstrates authentication
portability, not a live disconnection test of the whole Azure-hosted lab.

Challenge 04 already installed `core-keycloak` in namespace `core`; do not deploy
another broker or identity recipe. Challenge 06 must work on both targets.
You also need an Entra enterprise-app administrator/owner and an assigned,
non-privileged test user permitted by your tenant's policies.

Use Bash in the devcontainer, or WSL2 with the checkout in the WSL Linux filesystem
(not `/mnt/c`). Run commands from the Adaptive Apps MicroHack directory.
Keep shell tracing and terminal recording disabled.

Three selective helper actions replace repetitive mechanics:

```bash
bash resources/configure-identity.sh --help
```

| Action | Purpose |
| --- | --- |
| `check` | Read-only checks of target bindings and broker health |
| `setup` | Realm/client reconciliation and the K3s test user |
| `deploy` | Existing app inputs plus target-specific OIDC settings |

The [manual reference](../../docs/identity-manual.md) provides the equivalent
commands, credential recovery and deeper troubleshooting. You still configure Entra,
inspect the result and complete both browser sign-ins yourself.

| Target | Kubernetes context | Radius workspace | Environment | Group |
| --- | --- | --- | --- | --- |
| K3s | `k3s-azure-vm` | `ws-local-prod` | `env-local-prod` | `rg-trading` |
| AKS | `aks-adaptive-apps` | `ws-azure-prod` | `env-azure-prod` | `rg-trading` |

End-user sign-in is separate from the Radius deployment identity (Challenge 03) and
pod workload identities (Challenges 05-06). Do not change their federated credentials,
enable AI, or extend MQTT authorization for this challenge.

## 2. Prepare K3s and inspect the client

Reconnect after a devcontainer restart, then select both targets explicitly:

```bash
export AZURE_SUBSCRIPTION="${AZURE_SUBSCRIPTION:-<subscription-id>}"
bash resources/prepare-k3s-azure-vm.sh connect
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
rad workspace switch ws-local-prod
rad group switch rg-trading
rad env switch env-local-prod
bash resources/configure-identity.sh k3s check
bash resources/configure-identity.sh k3s setup --rotate-admin
```

`setup` prompts for the current broker admin password (Enter uses the pod's current
Secret), a password for the new `local-trader`, and a new admin password. Keep them in
your approved password manager. Never use the administrator for app sign-in.

Use `--rotate-admin` on initial setup before browser exposure. On later retries,
use `setup` without that flag. Existing local-user passwords are retained; add
`--reset-local-password` only when you intend to change one. If authentication fails
after a chart upgrade, supply the current approved password and follow the
[credential recovery guidance](../../docs/identity-manual.md#rotate-the-administrator-before-initial-browser-exposure).

Inspect the printed target tuple and non-secret client summary:

- Realm `adaptive-apps`, separate from administration realm `master`
- Client ID `adaptive-apps`, enabled and confidential (`publicClient: false`)
- Standard authorization-code flow enabled; implicit/direct grants and service accounts disabled
- Redirect URI `http://localhost:3000/*`, origin `http://localhost:3000`

Explain why the client ID can be identical without sharing users or secrets.

## 3. Deploy and prove local sign-in

```bash
bash resources/configure-identity.sh k3s deploy
```

Enter the current admin password and existing frontend break-glass password. The
helper reads the current frontend/backend inputs, captures this broker's client secret
just before deployment, and uses owner-only temporary parameters outside the
repository. It preserves your image inputs, cookie secret and workload settings.
Unsupported current inputs fail with a manual-route instruction, not default guesses.

The endpoint split is intentional:

| Caller | Endpoint |
| --- | --- |
| Frontend pod | `http://core-keycloak.core.svc.cluster.local:8080/realms/adaptive-apps` |
| Participant browser | `http://localhost:8080/realms/adaptive-apps/protocol/openid-connect/auth` |
| Frontend callback | `http://localhost:3000/auth/oidc/callback` |

Pods cannot use your workstation's localhost, and your browser cannot resolve cluster
DNS. Omitting all OIDC inputs still leaves Challenge 06 behavior unchanged.

Deployment checks are not a successful login. Use two foreground terminals:

**Terminal A:**

```bash
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
kubectl port-forward --namespace core service/core-keycloak 8080:8080
```

**Terminal B:**

```bash
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
rad workspace switch ws-local-prod
rad group switch rg-trading
rad env switch env-local-prod
rad app graph --application adaptive-apps
rad resource list --application adaptive-apps
rad resource expose Applications.Core/containers frontend \
  --application adaptive-apps --port 3000 --remote-port 3000
```

Open a private browser session at <http://localhost:3000>, choose OIDC sign-in and
authenticate as `local-trader`. Confirm the authenticated identity in the frontend.
The frontend's separate local break-glass login is not evidence of Keycloak sign-in.

Close the private browser session and stop both forwards with <kbd>Ctrl</kbd>+<kbd>C</kbd>.

## 4. Switch to AKS and configure Entra federation

```bash
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps
rad workspace switch ws-azure-prod
rad group switch rg-trading
rad env switch env-azure-prod
bash resources/configure-identity.sh aks check
bash resources/configure-identity.sh aks setup --rotate-admin
```

Choose an admin password different from K3s. Inspect the same client settings and
target tuple. Nothing was copied from K3s's identity database.

In Terminal A, keep this foreground forward running:

```bash
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps
kubectl port-forward --namespace core service/core-keycloak 8080:8080
```

In the [Entra admin center](https://entra.microsoft.com):

1. Open **Entra ID** > **Enterprise applications** > **New application** >
   **Create your own application**. Create a non-gallery app named
   `Adaptive Apps Keycloak workshop`.
2. Select **Single sign-on** > **SAML**. Choose a tenant-unique team identifier
   such as `team-07` and configure:

   | Setting | Value |
   | --- | --- |
   | Identifier (Entity ID) | `urn:adaptive-apps:keycloak:<team-id>` |
   | Reply URL (ACS) | `http://localhost:8080/realms/adaptive-apps/broker/entra/endpoint` |

3. Keep the minimum sign-in claims. Name ID must identify the test user; retain email,
   given name and surname claims when tenant policy permits them.
4. Under **Users and groups**, assign only your workshop user or narrowly scoped group.
   Keep assignment required; do not disable it to bypass a failed sign-in.
5. Download **Federation Metadata XML** from **SAML Certificates**.

Open the [Keycloak admin console](http://localhost:8080/admin/master/console/).
Authenticate using the AKS administrator, then select realm **adaptive-apps**:

1. Choose **Identity providers** > **SAML v2.0**.
2. Set alias `entra`, display name `Microsoft Entra ID`, and import the Entra metadata.
3. Confirm enabled state, intended tenant single sign-on URL, signature validation
   enabled, and sync mode `FORCE`.
4. Set **Service provider entity ID** to the same
   `urn:adaptive-apps:keycloak:<team-id>`, then save.
5. Under **Mappers**, add **Attribute Importer** entries, each with **Name Format**
   `ATTRIBUTE_FORMAT_BASIC` and sync mode `INHERIT`:

   | Name | SAML attribute name | User attribute |
   | --- | --- | --- |
   | `email` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress` | `email` |
   | `firstName` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname` | `firstName` |
   | `lastName` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname` | `lastName` |

Compare both Entity IDs and the exact Reply URL before proceeding. The alias `entra`
is part of that URL. This is the adaptation: Keycloak bridges SAML upstream while
the frontend remains an OIDC client.

## 5. Deploy and prove Entra-backed sign-in

Use the AKS client secret captured in Stage 3, step 2. The endpoint values match K3s
because both portfolios use the same service and realm names; the secret and upstream
provider differ.

> [!IMPORTANT]
> This redeploys `iac/app.bicep`, so the Azure PostgreSQL recipe runs again. Keep the
> same recipe registration used for the healthy Challenge 06 deployment. Record the
> database host before deploying, then confirm it is unchanged afterward:
>
> ```bash
> rad resource show Radius.Resources/postgreSqlDatabases trading-db \
>   --workspace ws-azure-prod --group rg-trading --output json | jq -r '.properties.host'
> ```
>
> A different host means a replacement server, not a rename. Stop and follow the
> recipe-version guidance in Challenge 05 before continuing.

**Bash:**

```bash
bash resources/configure-identity.sh aks deploy
```

Keep Terminal A's AKS Keycloak forward running. In Terminal B:

```bash
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps
rad workspace switch ws-azure-prod
rad group switch rg-trading
rad env switch env-azure-prod
rad app graph --application adaptive-apps
rad resource list --application adaptive-apps
rad resource expose Applications.Core/containers frontend \
  --application adaptive-apps --port 3000 --remote-port 3000
```

Open a **new private browser session** at <http://localhost:3000>. Choose OIDC sign-in,
then **Microsoft Entra ID** in Keycloak, and authenticate as the assigned test user.
Complete any first-login profile confirmation, then verify the frontend identity.
Do not reuse the earlier K3s session as AKS evidence.

```text
frontend -> localhost Keycloak -> Entra SAML sign-in
         -> localhost Keycloak broker endpoint -> frontend callback
```

## 6. Compare the result and clean up

| What stayed the same | What changed |
| --- | --- |
| App model and image inputs | Kubernetes/Radius target and independent application state |
| Frontend OIDC contract, client ID and callback | Broker database and client secret |
| Local browser ports 3000/8080 | Local user authority versus Entra SAML |
| Resource-type contracts and app graph | Broker-side federation and claim mapping |

For each target, retain only the non-secret target tuple, client settings, graph,
workload health and successful test-user identity. Record the image version/digest
used so later image drift is not confused with an identity change.

Never capture tokens, codes, cookies, passwords or secrets. Whole Radius container
resources, Kubernetes Deployments and raw frontend logs can contain credentials or
profile data; they are not safe evidence.

The application team owns the OIDC contract. The platform team owns broker
availability, credentials, federation and exposure. The identity team owns Entra
policy, assignment, claims and lifecycle.

### If something fails

| Symptom | First check |
| --- | --- |
| Target or connection check fails | Context/workspace/environment binding; reconnect K3s Bastion |
| Setup authentication fails | Current approved admin password; Helm/database credential drift |
| No OIDC sign-in or callback failure | Target-specific client/secret and internal/browser endpoint split |
| Port already in use | Stop your stale foreground forward; do not kill processes by name |
| Entra denies access or rejects reply URL | Tenant assignment, exact ACS, matching unique Entity IDs |
| Entra option or profile fields missing | Enabled provider alias, metadata and three claim mappers |
| Intermittent invalid authorization code | Keycloak replica cache/discovery health |

Use the [manual troubleshooting reference](../../docs/identity-manual.md#troubleshooting-by-layer)
for the next check; never weaken authentication to pass the lab.

### K3s reports connection refused on `127.0.0.1:16443`

The devcontainer restarted and the Bastion process is no longer running:

```bash
export AZURE_SUBSCRIPTION="${AZURE_SUBSCRIPTION:-<subscription-id>}"
bash resources/prepare-k3s-azure-vm.sh connect
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
```

In PowerShell, set `$env:AZURE_SUBSCRIPTION`, invoke the same script through `bash`,
and set `$env:KUBECONFIG`.

### Local port 8080 or 3000 is already in use

Stop the stale foreground `kubectl port-forward` or `rad resource expose` process with
<kbd>Ctrl</kbd>+<kbd>C</kbd>. Do not kill processes by name. Confirm the intended
Kubernetes context and Radius workspace before starting a replacement.

### The frontend shows no OIDC sign-in option

Check that `rad deploy` received a non-empty client ID and secret. Inspect only
environment-variable names with a JSONPath that cannot render their values. Review
frontend pod logs for the non-secret `OIDC disabled: missing config` diagnostic; never
dump all environment values.

**Bash:**

```bash
kubectl get deployment frontend \
  --namespace "$APP_NAMESPACE" \
  --output jsonpath='{.spec.template.spec.containers[?(@.name=="frontend")].env[*].name}'
echo
```

**PowerShell 7:**

```powershell
kubectl get deployment frontend `
    --namespace $AppNamespace `
    --output jsonpath='{.spec.template.spec.containers[?(@.name=="frontend")].env[*].name}'
Write-Output ""
```

### Keycloak reports an invalid redirect URI

The client must include `http://localhost:3000/*`, while `appBaseUrl` must be
`http://localhost:3000`. Keep the callback generated by the frontend at
`/auth/oidc/callback`.

### The browser cannot reach the authorization endpoint

The browser endpoint must use `http://localhost:8080`. Cluster-local
`core-keycloak.core.svc.cluster.local` addresses are only for frontend-to-Keycloak
token and user-info calls.

### Login succeeds at Keycloak but the callback fails

Check:

1. Keycloak client secret matches the active control plane.
2. Internal issuer, token, and user-info endpoints use the `core-keycloak` service.
3. Frontend and Keycloak forwards belong to the same cluster stage.
4. The frontend callback is on the current port-3000 exposure.

Do not copy the other cluster's client secret as a shortcut.

### Entra authenticates the user but denies application access

Check the enterprise application's **Users and groups** assignments and
**Assignment required** setting. Assign the intended test identity; do not disable
assignment globally just to pass the workshop.

### Keycloak does not show the Entra option

Verify the SAML provider is enabled, has alias `entra`, and imported metadata from the
intended tenant. Check that the Keycloak forward is still attached to
`aks-adaptive-apps`, not K3s.

### Entra reports a reply URL mismatch

For this lab the reply URL is exactly:

```text
http://localhost:8080/realms/master/broker/entra/endpoint
```

The alias is part of the URL. A production HTTPS hostname requires corresponding changes
in Entra, Keycloak, the OIDC browser endpoint, redirect origins, and application base
URL.

### Entra reports that the identifier is already in use

Another workshop application in the tenant already owns the SAML entity ID. Choose a
different `<team-id>`, then update both the Entra **Identifier (Entity ID)** and
Keycloak **Service provider entity ID** to the same unique
`urn:adaptive-apps:keycloak:<team-id>` value.

### The callback fails intermittently with an invalid authorization code

The portfolio runs multiple Keycloak replicas. Check both Keycloak pod logs for a
healthy Infinispan/JGroups cluster view. The browser forward can stay pinned to one pod
while the frontend token request reaches another through `core-keycloak`; a broken
Keycloak cache cluster makes authorization codes appear invalid on alternate requests.
Repair Keycloak clustering rather than weakening OIDC validation.

### A later portfolio upgrade breaks admin CLI authentication

`core-keycloak-admin` is managed by Helm. Re-running the Challenge 04
`helm upgrade --install core` command with the original chart values can restore the
old Kubernetes Secret while the Keycloak database retains the rotated password. Repeat
the target-specific administrator rotation with approved values after a portfolio
upgrade; do not print or recover the old password from command output.

### Do not use token output as evidence

Tokens, authorization codes, cookies, client secrets, and passwords are credentials.
Validate user identity in the frontend and use non-secret configuration metadata. Do
not paste tokens into JWT inspection sites or workshop notes.

## Optional enterprise local-directory extension

If a local AD DS deployment already exists, Keycloak can replace the local workshop
user source with LDAP federation:

1. Use `ldaps://<domain-controller>:636`; do not use cleartext LDAP.
2. Mount the issuing CA into Keycloak's trust store.
3. Use a dedicated read-only bind account stored in an approved secret store.
4. Scope the users DN and group search to the workshop organizational units.
5. Use read-only edit mode and test connection, authentication, and user sync.
6. Validate an AD user through the full frontend OIDC flow.

Do not claim this extension is complete when only TCP connectivity or user import works.
Certificate validation, credential protection, group mapping, account lifecycle, and an
end-to-end sign-in are part of the identity boundary.

## Cleanup

Stop foreground port-forwards with <kbd>Ctrl</kbd>+<kbd>C</kbd>. Remove only
workshop-scoped Entra assignments or the non-gallery enterprise application when it is
no longer needed, following your organization's change process. Do not delete shared
Keycloak, Radius, AKS, K3s, or Bastion resources as part of this challenge.

For the K3s Bastion tunnel itself:

```bash
bash resources/prepare-k3s-azure-vm.sh status
bash resources/prepare-k3s-azure-vm.sh disconnect
```

Disconnecting a tunnel does not stop Bastion billing; follow the
[K3s cleanup guidance](../../docs/prepare-k3s.md) for resource cleanup.

For an existing local directory, the optional
[LDAPS extension](../../docs/identity-manual.md#optional-local-directory-extension)
retains the same frontend contract. Production requires stable HTTPS hostnames,
restricted redirects, trusted certificates and durable credential management; these
HTTP localhost settings are for the private workshop only.
