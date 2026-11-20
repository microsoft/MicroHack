# Challenge 07 - Adapt Identity Services - Configure User Authentication

[< Previous Challenge](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/challenges/challenge-06.md) - **[Home](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/Readme.md)** - [Next Challenge >](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/challenges/challenge-09.md)

Estimated time: 60-90 minutes | Difficulty: intermediate to advanced

## Challenge objective

Can the same frontend sign in users at both a private site and in Azure without changing
how the application authenticates? Yes: the frontend uses OIDC with Keycloak in both
places; only the user source behind Keycloak changes.

On private K3s, Keycloak authenticates a local user. On AKS, Keycloak sends the user to
Microsoft Entra ID and then returns the result to the same frontend OIDC flow. The app
model and client ID stay the same; each target keeps its own Keycloak realm and secret.

## Scenario

The trading firm requires cloud users to sign in with Microsoft Entra ID. A local site
must retain an authentication path even when no cloud directory or route to a domain
controller is available. Application developers do not want provider-specific login
code for every location.

The platform team already deployed a `core` portfolio containing Keycloak on each
cluster. Use those Keycloak instances as identity brokers. In a production design they
would use stable HTTPS hostnames; this workshop reaches Keycloak and the frontend only
through local port-forwarding.

## Learning goals

- Trace one frontend OIDC flow through Keycloak to either a local user or Entra.
- Keep the app contract the same while switching the user source between K3s and AKS.
- Verify the selected target and successful sign-in without exposing secrets.

## Fixed target map

| Platform | Kubernetes context | Radius workspace | Environment | Radius group |
| --- | --- | --- | --- | --- |
| Private K3s through Bastion | `k3s-azure-vm` | `ws-local-prod` | `env-local-prod` | `rg-trading` |
| AKS | `aks-adaptive-apps` | `ws-azure-prod` | `env-azure-prod` | `rg-trading` |

The Keycloak database and the Radius application state are independent on each target.
An OIDC client secret or user created on one target does not exist on the other.
Create the application client and users in a dedicated `adaptive-apps` realm on each
Keycloak instance. The matching realm names do not share users or configuration; keep
the `master` realm for Keycloak administration.

## Additional prerequisites

This is an **optional extension** to the hosted baseline. The Entra
enterprise-application/SAML setup requires tenant permissions that lab
resource-group Owner does not grant; arrange organizer assistance before starting.
Use Bash with the sourced Console environment. Hosted-browser OIDC needs separate
validation; see [Console setup](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/docs/console-setup.md#optional-extensions-and-hosted-browsers).
Challenge 08 is not yet published; continue from 07 to 09.

- Completion of Challenge 06 with healthy `core-keycloak` workloads on both clusters.
- A Microsoft Entra role that can create/configure the workshop enterprise application
  and assign its test users, such as **Cloud Application Administrator**,
  **Application Administrator**, or ownership delegated for the application.
- A non-privileged Entra test user permitted by your organization's Conditional Access
  policy.
- Permission to update Kubernetes resources and Secrets in namespace `core` on both
  workshop clusters.
- A browser that can reach forwarded localhost ports 3000 and 8080.

## Identity boundaries

**Boundary:** this challenge changes end-user sign-in only. The other identities keep
doing their existing jobs:

| Plane | Purpose | Established by |
| --- | --- | --- |
| Radius control-plane identity | Lets Radius deploy Azure resources | Challenge 03 |
| Application workload identity | Lets pods call platform services | Challenges 05-06 recipes |
| End-user authentication | Signs users into the frontend | This challenge |

Challenge 07 changes only the third plane. Do not create service-principal secrets,
change the Challenge 03 federated credential, or claim that user login completes Azure
Event Grid MQTT authorization.

## Constraints

- Start from the application and environments completed in Challenge 06.
- Use the exact target map above and verify all four selectors before each stage.
- After a devcontainer restart, reconnect K3s with
  `bash resources/prepare-k3s-azure-vm.sh connect` and use
  `~/.kube/adaptive-apps-k3s.yaml`.
- Keep one app-facing contract:
  - Client ID `adaptive-apps`
  - Confidential OIDC client with authorization-code flow
  - Redirect URI `http://localhost:3000/*`
  - Browser Keycloak endpoint on `http://localhost:8080`
- Do not commit, echo, screenshot, or save passwords and client secrets in the
  repository. Use secure prompts and clear plaintext variables after the CLI boundary.
- Pass secret deployment parameters through a protected temporary ARM JSON parameter
  file, not `rad deploy` command-line values; remove the file after deployment, including
  when deployment fails. On Windows, use Bash in WSL2 with the repository in the WSL
  Linux filesystem for all credential-sensitive steps, including client-secret capture
  and deployment.
- Keep all port-forwards in the foreground. Stop Keycloak and frontend forwarding before
  switching targets.
- Do not expose the private K3s VM, Kubernetes API, Keycloak, or frontend to the
  Internet.
- Use Keycloak-local users for the default K3s path. LDAP/AD DS is an optional
  enterprise extension only when the site already has a reachable directory and trust
  chain.
- Use Microsoft Entra SAML federation as the AKS upstream identity path. The frontend
  still speaks OIDC only to Keycloak.
- Keep AI disabled and do not expand the MQTT runtime scope.

## Tasks

### Task 1: Prove the app contract with a local K3s user

Select the K3s target. Configure its independent `adaptive-apps` realm, OIDC client,
and non-administrator local test user. Deploy the app with the OIDC contract, then
sign in through Keycloak. Use the existing target checks and temporary parameter-file
instructions; do not expose credentials or public endpoints.

You may use `resources/configure-identity.sh k3s check`, `setup --rotate-admin`,
and `deploy` as separate actions instead of copying the administration blocks.
Inspect the helper's non-secret settings and complete the browser login yourself.
The [manual reference](../docs/identity-manual.md) retains the underlying commands.

### Task 2: Keep the app, switch the user source on AKS

Stop the K3s forwards and select the AKS target. Configure its independent
`adaptive-apps` realm and the same OIDC client settings, then connect Keycloak to Entra
over SAML. Verify Entra's Reply URL matches the realm callback and assign only the
workshop test user or group. Redeploy the same app contract and complete an Entra-backed
sign-in.

Use the same helper actions with target `aks` for repetitive broker/deployment
mechanics. Keep Entra app creation, assignment and Keycloak SAML federation manual.
Use `--rotate-admin` only for initial setup; reruns must not reset credentials
unless explicitly requested.

### Task 3: Compare the two sign-in paths

For both targets, capture non-secret evidence of:

- The active Kubernetes context, Radius workspace, group, and environment.
- The `adaptive-apps` client settings without its secret.
- Frontend and Keycloak workload health.
- The Radius application graph and frontend OIDC environment-variable names.
- Successful login through the intended user authority.

Explain what changed (the user source and target-specific broker settings) and what did
not (the frontend OIDC contract, client ID, and redirect URI). If sign-in fails, check
the relevant layer in order:

1. Local port-forward and browser reachability.
2. OIDC client, redirect URI, and secret alignment.
3. Keycloak realm and upstream provider state.
4. Entra enterprise-app assignment or local-user state.
5. Callback, issuer, token, user-info, and browser endpoint alignment.

## Success criteria

- `iac/app.bicep` contains one optional, platform-neutral OIDC contract and still deploys
  with OIDC disabled when its parameters are omitted.
- The same app model, client ID, redirect URI, and browser ports are used on both
  targets.
- K3s login succeeds with a non-administrator local Keycloak user.
- AKS login succeeds with an assigned Microsoft Entra user brokered through Keycloak.
- Client secrets and user passwords differ per target, remain out of source and
  evidence, and are cleared from plaintext variables.
- Secret deployment parameters are passed by a protected temporary file that is removed
  on success or failure.
- The team can explain why Keycloak changes upstream providers without changing the
  frontend's OIDC protocol.
- The team can distinguish user authentication from Radius control-plane identity and
  pod workload identity.
- No public endpoint or inbound VM rule is introduced for the workshop login flow.

## Progressive hints

### Architecture and targeting

1. The app should not know whether its user originated in Keycloak or Entra.
2. Kubernetes context selects the Keycloak instance; Radius workspace selects the app
   deployment. Verify both.
3. Each control plane has its own client secret even when the client ID is identical.

### OIDC client

1. Validate Keycloak health and client configuration before debugging federation.
2. The browser reaches `localhost:8080`, while the frontend container reaches Keycloak
   through its `core` cluster service.
3. A redirect mismatch usually means the client does not include
   `http://localhost:3000/*`.

### K3s local identity

1. A local Keycloak user is enough to prove the broker and OIDC contract without
   introducing AD DS into the workshop.
2. Use a non-administrator account for application sign-in.
3. If the callback fails after successful credentials, inspect frontend logs and the
   OIDC endpoints rather than changing the user.

### Entra federation

1. Keycloak is the SAML service provider; Entra is the upstream SAML identity provider.
2. The reply URL ends in `/broker/entra/endpoint`.
3. An Entra user may authenticate successfully but still be denied when assignment is
   required and the user or group is not assigned.

### Port-forwarding

1. Keycloak needs local port 8080 and the frontend needs local port 3000.
2. A foreground forward belongs to the cluster active when it started.
3. Stop both forwards before switching targets; do not reuse a stale browser session as
   evidence.

## Learning resources

- [Keycloak identity brokering](https://www.keycloak.org/docs/latest/server_admin/#_identity_broker)
- [Keycloak OIDC clients](https://www.keycloak.org/docs/latest/server_admin/#assembly-managing-clients_server_administration_guide)
- [Microsoft Entra SAML single sign-on](https://learn.microsoft.com/entra/identity/enterprise-apps/add-application-portal-setup-sso)
- [Assign users and groups to an enterprise application](https://learn.microsoft.com/entra/identity/enterprise-apps/assign-user-or-group-access-portal)
- [OpenID Connect overview](https://openid.net/developers/how-connect-works/)
- [Kubernetes port forwarding](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)

## Optional stretch

If an actual local AD DS environment is already available, replace the K3s local user
source with Keycloak LDAP user federation over LDAPS. Validate DNS, certificate trust,
bind-account scope, read-only user search, and group/claim mapping. Do not describe this
optional path as complete unless an AD user signs in end to end.
