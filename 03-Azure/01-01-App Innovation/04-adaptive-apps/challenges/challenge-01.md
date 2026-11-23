# Recommended environment: GitHub Codespaces

Use **GitHub Codespaces with the Azure / App Innovation / Adaptive Apps
devcontainer** for the workshop command-line tasks. It provides VS Code in your
browser with Azure CLI, PowerShell 7, Bicep, `kubectl`, Helm, Radius CLI, and the
supporting lab tools, without requiring local installations. Continue to use the
Azure portal for portal-based tasks. No Kubernetes cluster or Docker daemon runs
inside this container; the lab platforms run in Azure.

## Set up Codespaces (recommended)

1. Sign in with a **personal GitHub account**. Optionally set **Settings >
   Codespaces > Default idle timeout** at
   [github.com/settings/codespaces](https://github.com/settings/codespaces)
   **before creating the Codespace**. The default is 30 minutes; you can choose
   5-240 minutes, subject to organization policy. The setting applies to new
   Codespaces.
2. Open the **repository home page**, [djong1/MicroHack](https://github.com/djong1/MicroHack),
   while signed in to GitHub. Above the file list, select the green **Code**
   button, then the **Codespaces** tab. This is the repository's Code menu, not
   a menu inside VS Code.

   <a href="https://docs.github.com/assets/images/help/codespaces/who-will-pay.png"><img src="https://docs.github.com/assets/images/help/codespaces/who-will-pay.png" alt="GitHub documentation example of the Code menu with the Codespaces tab selected" width="420"></a>

   In the **top-right corner of the Codespaces tab**, select **...**, then **New
   with options**. Do not use the quick-create button: this repository has
   multiple devcontainers, and you must choose the Adaptive Apps one.

   <a href="https://docs.github.com/assets/images/help/codespaces/default-machine-type.png"><img src="https://docs.github.com/assets/images/help/codespaces/default-machine-type.png" alt="GitHub documentation example showing the Codespaces three-dot menu and New with options" width="420"></a>

   These screenshots are examples from
   [GitHub's Codespaces documentation](https://docs.github.com/en/codespaces/developing-in-a-codespace/creating-a-codespace-for-a-repository#creating-a-codespace-for-a-repository);
   repository names and existing Codespaces may differ. If the **Codespaces**
   tab is missing, check that you are signed in. Alternatively, open
   [Create a codespace](https://github.com/codespaces/new), select
   **djong1/MicroHack**, and continue with the options below.
3. Select branch **djong1-challenge-3-connections**, devcontainer configuration
   **Azure / App Innovation / Adaptive Apps**, and a **2-core** machine, then
   **Create codespace**. The configuration file is
   [`.devcontainer/03-azure-01-01-app-innovation-04-adaptive-apps/devcontainer.json`](../../../../.devcontainer/03-azure-01-01-app-innovation-04-adaptive-apps/devcontainer.json).
   Wait for the post-create setup to finish before using the terminal. If this
   configuration is not offered, use the
   [local Dev Container setup](../walkthrough/challenge-01/solution-01.md#recommended-devcontainer)
   instead of the default Codespace.
4. In **Terminal > New Terminal**, open **Bash**, sign in to Azure with your
   workshop account, and select your assigned lab subscription:

   ```bash
   az login --use-device-code
   az account set --subscription "<subscription-id>"
   az account show --query "{Account:user.name,Subscription:name,Tenant:tenantId}" --output table
   ```

   Open the device-login URL printed by Azure CLI and enter its **device code**.
   For hosted events, use the account and, if supplied, the Temporary Access
   Pass (TAP) from the Console. The TAP and device code are different; never
   save either in files or commands. Use a private browser window if necessary
   to avoid signing in with your normal work account. For bring-your-own-
   subscription labs, use your own Azure identity. Confirm that the displayed
   account and subscription match your lab details.
5. Use this same Codespace for subsequent challenges. The repository is already
   cloned, and Explorer should open
   `03-Azure/01-01-App Innovation/04-adaptive-apps`. Run the workshop commands
   from that directory in **Bash**; run `pwsh` when PowerShell 7 is needed.
   Check the installed tools with the commands in
   [Verify and troubleshoot](../walkthrough/challenge-01/solution-01.md#verify-and-troubleshoot),
   then continue with the shared
   [access checks](../walkthrough/challenge-01/solution-01.md#required-access-and-capacity)
   and [verification checklist](../walkthrough/challenge-01/solution-01.md#verification-checklist),
   not the manual installation instructions.

## Terminals, breaks and saved work

- **Multiple terminals:** use **Terminal > New Terminal** or the terminal panel's
  **+** button. Leave Bastion tunnels and port-forwards running in their own
  terminals. Terminals share files and networking, **not shell variables**;
  initialize the required variables in each terminal as directed.
- **After a restart:** saved files persist when a Codespace stops, but processes,
  tunnels, and shell variables do not. Save only non-secret variable assignments
  in a file such as `~/adaptive-apps-env.sh`, then reload it with
  `source ~/adaptive-apps-env.sh` in each new Bash terminal. For PowerShell, use
  a `.ps1` file and dot-source it. Recheck Azure sign-in and restart tunnels.
  Do not save TAPs, tokens, passwords, private keys, or kubeconfig files in the
  repository.
- **Browser access:** use the Ports view's forwarded HTTPS URLs, not browser
  `localhost`. Organizers must validate the Bastion connection and the frontend,
  Keycloak, and identity redirect URLs before the event; see
  [Console setup](../docs/console-setup.md#optional-extensions-and-hosted-browsers).
  Challenge 10's GitHub Copilot app / Radius Canvas work still requires a host
  installation, not just a Codespace.
- **Finish for the day:** use **Codespaces: Stop Codespace** in the Command
  Palette, or stop it at [github.com/codespaces](https://github.com/codespaces).
  Closing the browser tab alone does not stop it immediately. When the event
  is over, download any work you want to keep and delete the Codespace. Stopped
  Codespaces still consume storage and are subject to automatic deletion after
  their retention period.

**Included usage:** GitHub Free personal accounts include **120 core-hours per
month**, equivalent to **60 hours (3,600 minutes) on a 2-core machine**, plus
**15 GB-months of storage**. Larger machines consume compute allowance faster.
Check your allowance and current billing terms before the event: container images
and persisted state also consume storage, and a longer idle timeout uses more
compute. Azure resource costs are separate; stopping the Codespace does not stop
Azure resources.

Sources: [Codespaces timeout](https://docs.github.com/en/codespaces/setting-your-user-preferences/setting-your-timeout-period-for-github-codespaces)
and [Included usage and billing](https://docs.github.com/en/billing/concepts/product-billing/github-codespaces).
