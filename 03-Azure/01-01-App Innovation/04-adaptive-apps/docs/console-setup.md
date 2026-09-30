# Connect to a hosted Console lab

[Home](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/Readme.md)

Use this path only when the organizer has supplied a **ready, developer-ready**
Adaptive Apps lab. Console setup covers Challenges **02-05**, including recipe
publication and registration. It does not deploy the Challenge 06 application.
This connection procedure requires workshop validation; it is not a claim of a
completed live Console test.

## 1. Prepare your workstation

Complete **Task 2 (workstation), Task 3 (local state), and Task 4 (tool checks)** in
[Challenge 01](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/challenges/challenge-01.md).
Use the canonical `microsoft/MicroHack` repository on `main`. The validated option
remains a **local VS Code devcontainer**; a manual host toolchain is also supported.
Use a **Bash terminal**, even when PowerShell is installed in the container.

Hosted participants skip subscription provider/feature registration, the extra
preflight resource group/public IP, capacity provisioning, and the installation
commands in Challenges 02-05. The organizer supplies **Owner on your lab resource
group** and **Reader on its AKS node resource group**; these are not subscription-
or tenant-administrator permissions. Do not request broader permissions just to
repeat the manual setup. Bring-your-own-subscription participants continue with
the original manual path.

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

Only `AZURE_SUBSCRIPTION` and `RESOURCE_GROUP` are required inputs. The helper checks
the lab ready flag, discovers `ACR_NAME` from the resource group's `adaptiveAppsAcr`
tag, obtains your cluster connections, creates the local Radius workspaces, and
regenerates `artifacts/types.tgz`. It **does not provision infrastructure** and uses
your own Azure CLI credentials, not credentials copied from an automation runner.
If the lab is not ready or access is denied, stop and contact the organizer rather
than rerunning installation scripts.

| Target | Local Kubernetes context | Local Radius workspace |
| --- | --- | --- |
| AKS | `aks-adaptive-apps` | `ws-azure-prod` |
| Private K3s | `k3s-azure-vm` | `ws-local-prod` |

The environments remain `env-azure-prod` and `env-local-prod`, each with Radius
group `rg-trading`. Keep the discovered Console resource names; do not replace them
with manual examples such as `rg-adaptive-apps`.

The default private VM is `vm-adaptive-apps-k3s` and its Bastion host is
`bas-adaptive-apps`. The hosted region is fixed by the supplied resource group's
location. If setup rejects that region as unsuitable, ask the organizer to correct
the lab assignment; do not change regions or delete/recreate the supplied group.

## 3. Every new Bash terminal

From the lab root, restore the generated shell assignments:

```bash
source artifacts/console-env.sh
```

The file uses safe shell assignments for your lab configuration. Do not commit it
or share local credential directories. The helper leaves the Bastion API tunnel
running in the background and prints reconnect/disconnect instructions. Follow
those instructions after a workstation/container restart; sourcing the file alone
does not restart a tunnel. Application and dashboard port-forwards are separate
and must stay running while you browse their localhost URLs.

Continue at [Challenge 06](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/challenges/challenge-06.md).
Read Challenges 02-05 for context, but do not reprovision or reinstall their shared
components. The hosted control-tag policies are organizer-managed; participants
do not need to add policy/tag checks or change those controls.

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
