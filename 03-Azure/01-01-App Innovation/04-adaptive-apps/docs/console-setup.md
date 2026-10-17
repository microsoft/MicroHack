# Connect to a hosted Console lab

[Home](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/Readme.md)

Console supplies AKS, a private K3s VM, networking, Bastion, and a container
registry (ACR). You install and explore Radius, resource types, and recipes in
**Challenges 03-05**, then deploy the application in **Challenge 06**.

## 1. Prepare your workstation

Complete **Task 2 (workstation), Task 3 (local state), and Task 4 (tool checks)** in
[Challenge 01](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/challenges/challenge-01.md).
Use a **full checkout** of the canonical `microsoft/MicroHack` repository on `main`;
the challenges need its `iac`, `resources`, and application files, not only a
downloaded connection script. The validated workstation option
remains a **local VS Code devcontainer**; a manual host toolchain is also supported.
Use a **Bash terminal**, even when PowerShell is installed in the container.

Skip subscription setup and infrastructure provisioning. In Challenge 02,
explore and validate the supplied platforms instead. Use the **managed identity**
option in Challenge 03; it works with your assigned lab permissions.

## 2. Connect with your own identity

Open the Adaptive Apps lab root, not the repository root. In a normal clone:

```bash
cd "03-Azure/01-01-App Innovation/04-adaptive-apps"
```

The devcontainer already opens this directory. Then run:

```bash
az login
export AZURE_SUBSCRIPTION='<Console subscription>'
export RESOURCE_GROUP='<Console resource group>'
bash resources/connect-console.sh
source artifacts/console-env.sh
```

The helper discovers your lab settings, connects to both clusters, checks their
nodes, and saves the configuration to `artifacts/console-env.sh`. It uses your
Azure sign-in. If the lab is not ready or access is denied, contact the organizer.

| Target | Connected Kubernetes context | Workspace you create in Challenge 03 |
| --- | --- | --- |
| AKS | `aks-adaptive-apps` | `ws-azure-prod` |
| Private K3s | `k3s-azure-vm` | `ws-local-prod` |

In Challenge 03 create environments `env-azure-prod` and `env-local-prod`, each
with Radius group `rg-trading`. Keep the discovered Console resource names; do not replace them
with manual examples such as `rg-adaptive-apps`.

Keep the supplied resource group and region. If setup reports a problem with
either, contact the organizer rather than changing or recreating them.

## 3. Every new Bash terminal

From the lab root, restore the generated shell assignments:

```bash
source artifacts/console-env.sh
```

Do not commit the generated file or share local credential directories.
After a workstation/container restart, run `bash resources/connect-console.sh`
again and source the file to reconnect. Sourcing the file alone does not restart
the private API tunnel. Keep application and dashboard port-forwards running
while you browse their localhost URLs.

Validate/explore the supplied platforms using the read-only checks in
[Challenge 02](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/challenges/challenge-02.md),
then continue at [Challenge 03](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/challenges/challenge-03.md).
Complete the Radius, abstraction, and recipe exercises in Challenges 03-05.
Reuse the supplied ACR in Challenge 05; do not recreate it. The Bicep extension
`artifacts/types.tgz` is generated in Challenge 04, not during connection.

## Optional extensions and hosted browsers

- **Challenge 07:** the local Keycloak exercise follows Challenge 06. The Entra
  enterprise-application/SAML portion needs separate tenant permissions and may
  require organizer assistance; lab resource-group Owner does not grant them.
- **Challenge 09:** arrange an **existing, approved Azure OpenAI deployment** and
  the access needed to assign inference permissions. It is not included in the
  hosted baseline. Challenge 08 is not yet published; go from 07 to 09.
- **Challenge 10:** optional, **host-only GitHub Copilot app / Radius Canvas** work,
  with its own GitHub Actions, Entra/federation, and Azure prerequisites. A
  devcontainer or Codespace does not supply these. Finish after 10; Challenge 11
  is not yet published.

**Codespaces is an optional organizer-validation path, not a validated workshop
promise.** To evaluate it, use the canonical repository's **Code > Codespaces >
New with options**, select branch `main` and the
`03-azure-01-01-app-innovation-04-adaptive-apps` devcontainer configuration, and
verify all tools and the Bastion connection before the event. If that configuration
is not offered, use the local devcontainer rather than the default Codespace.
Use the Ports view's forwarded HTTPS URLs for browser access: browser `localhost`
does not address a hosted container. Validate frontend and Keycloak public URLs,
OIDC redirect URIs, allowed origins, and Entra SAML reply URLs together; do not
mechanically substitute a hostname or make identity ports public. Challenge 10
still runs on the host.
