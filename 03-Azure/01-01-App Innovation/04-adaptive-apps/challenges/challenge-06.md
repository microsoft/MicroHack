# Challenge 06 - Adapt Identity Services - Configure User Authentication

[< Previous Challenge](challenge-05.md) - **[Home](../Readme.md)** - [Next Challenge >](challenge-07.md)

Estimated time: 60-90 minutes | Difficulty: intermediate to advanced

## Challenge objective

Add user authentication to the portable trading application without coupling the
frontend to one enterprise identity system. The frontend must keep one OpenID Connect
(OIDC) contract with Keycloak while each platform supplies a different user source:

- `ws-local-prod` uses users held locally by Keycloak on private K3s.
- `ws-azure-prod` brokers Microsoft Entra ID through Keycloak on AKS.

The application model changes once to express the stable OIDC contract. That same model
is then deployed to both independent Radius control planes with target-specific
parameters and broker configuration.

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

- Separate end-user authentication from Radius control-plane and application workload
  identities.
- Use Keycloak as a stable OIDC boundary in front of different user authorities.
- Keep client ID, redirect URI, and application model consistent while client secrets
  and upstream federation remain target-specific.
- Prevent identity changes from reaching the wrong Kubernetes or Radius control plane.
- Validate the complete browser, broker, upstream-provider, and callback path.

## Fixed target map

| Platform | Kubernetes context | Radius workspace | Environment | Radius group |
| --- | --- | --- | --- | --- |
| Private K3s through Bastion | `k3s-azure-vm` | `ws-local-prod` | `env-local-prod` | `rg-trading` |
| AKS | `aks-adaptive-apps` | `ws-azure-prod` | `env-azure-prod` | `rg-trading` |

The Keycloak database and the Radius application state are independent on each target.
An OIDC client secret or user created on one target does not exist on the other.

## Additional prerequisites

- Completion of Challenge 05 with healthy `core-keycloak` workloads on both clusters.
- A Microsoft Entra role that can create/configure the workshop enterprise application
  and assign its test users, such as **Cloud Application Administrator**,
  **Application Administrator**, or ownership delegated for the application.
- A non-privileged Entra test user permitted by your organization's Conditional Access
  policy.
- Permission to update Kubernetes resources and Secrets in namespace `core` on both
  workshop clusters.
- A browser that can reach forwarded localhost ports 3000 and 8080.

## Identity boundaries

Do not conflate these three identity planes:

| Plane | Purpose | Established by |
| --- | --- | --- |
| Radius control-plane identity | Lets Radius deploy Azure resources | Challenge 02 |
| Application workload identity | Lets pods call platform services | Challenges 04-05 recipes |
| End-user authentication | Signs users into the frontend | This challenge |

Challenge 06 changes only the third plane. Do not create service-principal secrets,
change the Challenge 02 federated credential, or claim that user login completes Azure
Event Grid MQTT authorization.

## Constraints

- Start from the application and environments completed in Challenge 05.
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

### Task 1: Define the portable authentication contract

Review `iac/app.bicep` and identify the optional OIDC parameters and frontend
environment variables. Draw both authentication sequences:

1. Browser -> K3s Keycloak -> local Keycloak user -> frontend callback.
2. Browser -> AKS Keycloak -> Microsoft Entra ID -> Keycloak -> frontend callback.

Label each value as application-owned, broker-owned, or upstream-provider-owned.
Explain why the app model can remain identical even though each Keycloak instance has a
different client secret.

### Task 2: Configure and validate the K3s identity path

Reconnect the Bastion API tunnel and explicitly select `k3s-azure-vm`,
`ws-local-prod`, `rg-trading`, and `env-local-prod`.

On the K3s `core` Keycloak instance:

- Create or reconcile the confidential `adaptive-apps` client.
- Create a non-administrator local test user with a securely entered password.
- Rotate the portfolio bootstrap administrator without exposing its password.
- Capture the generated client secret only into a protected shell variable.
- Redeploy `iac/app.bicep` with the OIDC contract enabled.
- Forward Keycloak to local port 8080 and the frontend to local port 3000.
- Sign in through the OIDC path and verify the returned user identity.

Record why this is a local availability pattern rather than an enterprise directory
replacement.

### Task 3: Configure Microsoft Entra federation on AKS

Stop both K3s foreground processes, clear the dedicated K3s kubeconfig, and explicitly
select `aks-adaptive-apps`, `ws-azure-prod`, `rg-trading`, and `env-azure-prod`.

On the AKS `core` Keycloak instance:

- Create the same `adaptive-apps` OIDC client contract.
- Rotate this broker's portfolio bootstrap administrator independently from K3s.
- Configure a non-gallery Microsoft Entra enterprise application for SAML SSO.
- Use the Keycloak realm as the SAML service provider and add Entra as an upstream
  identity provider with alias `entra`.
- Give the SAML service provider a team-unique entity ID so multiple workshop teams can
  share one Entra tenant.
- Assign only the workshop test users or group to the enterprise application.
- Map the user attributes needed by the frontend.
- Redeploy the same `iac/app.bicep` with this target's Keycloak client secret.
- Forward Keycloak and the frontend, then complete an Entra-backed sign-in.

The localhost SAML and OIDC URLs are acceptable only for this port-forwarded workshop.
Document the stable HTTPS hostnames and certificate ownership a production deployment
would require.

### Task 4: Compare evidence and troubleshoot by layer

For both targets, capture non-secret evidence of:

- The active Kubernetes context, Radius workspace, group, and environment.
- The `adaptive-apps` client settings without its secret.
- Frontend and Keycloak workload health.
- The Radius application graph and frontend OIDC environment-variable names.
- Successful login through the intended user authority.

Create a layered diagnostic checklist covering:

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
