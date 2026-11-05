# Environment setup

GitHub Codespaces is the **supported environment** for this MicroHack — use it unless your facilitator explicitly asks you to use a local workstation. The repository provides a dedicated development container with the required .NET, Java, Docker, Azure, GitHub, Copilot, and modernization tooling.

## Option A: GitHub Codespaces (recommended)

### 1. Create the Codespace

1. Sign in to [GitHub](https://github.com/) with the account that has your GitHub Copilot subscription.
1. Open the [MicroHack repository](https://github.com/microsoft/MicroHack). If your organization restricts creating Codespaces on public repositories, fork it first and continue from your fork.
1. Select **Code** > **Codespaces** > **New with options**.
1. For **Dev container configuration**, select **Azure / App Innovation / GHCP App Modernization**.
1. Create the Codespace and wait for the container setup to finish.

Do not create the Codespace with the default configuration. The MicroHack repository contains several development containers, and the other configurations do not necessarily include the tools required by this hack.

### 2. Verify the tools

Open a terminal in the Codespace and run:

```bash
gh --version
modernize --version
copilot --version
az --version
dotnet --version
java --version
docker --version
```

If one of these commands is unavailable, see [Troubleshooting](#troubleshooting) before continuing.

### 3. Sign in to GitHub

The modernization CLI uses GitHub CLI authentication. First, check the account currently used by GitHub CLI:

```bash
gh auth status
```

The authenticated account must have access to GitHub Copilot. If GitHub CLI is not authenticated, or it is using the wrong account, sign in:

```bash
gh auth login --web --git-protocol https
gh auth status
```

Follow the browser prompt and use the GitHub account that has GitHub Copilot access.

> [!NOTE]
> GitHub and Azure use separate authentication sessions. A successful `az login` does not sign in the modernization CLI to GitHub.

**GitHub Copilot CLI** keeps its own sign-in session, separate from GitHub CLI. Start it and sign in on first use:

```bash
copilot
```

If you are not signed in, run the `/login` slash command and follow the instructions — in a Codespace this is a device-code flow: open <https://github.com/login/device> and enter the one-time code. Verify the signed-in account with `/user`; it must be the account that has GitHub Copilot access.

> [!NOTE]
> An explicitly exported `COPILOT_GITHUB_TOKEN`, `GH_TOKEN`, or `GITHUB_TOKEN` environment variable overrides the `/login` session (the token a Codespace injects automatically does not). If Copilot CLI reports an authentication error, unset those variables and sign in with `/login`. Classic personal access tokens (`ghp_…`) are not supported.

### 4. Sign in to Azure

Sign in with the Azure account and subscription assigned to the MicroHack:

```bash
az login --use-device-code
az account show --output table
```

If the displayed subscription is not the one assigned to the lab, select it:

```bash
az account set --subscription "<subscription-name-or-id>"
az account show --output table
```

## Option B: Local workstation

> [!IMPORTANT]
> Local setups are best-effort. If the modernize CLI or Copilot CLI installation fails on your workstation, switch to the recommended Codespace instead of debugging the installation during the event.

Use the [modernization agent quickstart](https://learn.microsoft.com/azure/developer/github-copilot-app-modernization/modernization-agent/quickstart) for the current platform-specific prerequisites and installation options.

On Linux or macOS, install and verify the modernization CLI with:

```bash
curl -fsSL https://raw.githubusercontent.com/microsoft/modernize-cli/main/scripts/install.sh | bash
source ~/.bashrc
modernize --version
```

If you use Zsh, run `source ~/.zshrc` instead. On macOS or Linux you can also install it with Homebrew:

```bash
brew tap microsoft/modernize https://github.com/microsoft/modernize-cli
brew install modernize
```

On Windows, install the CLI with:

```powershell
winget install GitHub.Copilot.modernization.agent
```

Open a new terminal after the Windows installation.

On **every platform**, also install **GitHub Copilot CLI**, which Challenge 1 uses to verify agents, skills, and MCP configuration ([installation guide](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli)):

```bash
npm install -g @github/copilot
copilot --version
```

Then authenticate and verify GitHub CLI:

```bash
gh auth login
gh auth status
```

Your workstation must also provide the SDKs and tools listed in the [general prerequisites](../Readme.md#general-prerequisites).

## Clone the sample applications

Keep the sample applications in separate repositories. Challenges 2 and 3 create commits and branches independently for each application. You do not need to fork the samples — clone them directly from `Azure-Samples` and work on a local branch, as in the [modernization agent quickstart](https://learn.microsoft.com/azure/developer/github-copilot-app-modernization/modernization-agent/quickstart).

### 1. Clone the repositories

In the GHCP App Modernization Codespace, the terminal starts in the hack directory. Stay there — every command in this MicroHack runs from the hack directory. Run:

```bash
mkdir -p repos
git clone https://github.com/Azure-Samples/PhotoAlbum-Java.git repos/PhotoAlbum-Java
git clone https://github.com/Azure-Samples/PhotoAlbum.git repos/PhotoAlbum
```

### 2. Create a working branch

Create a `modernize` branch in each repository — your modernization commits stay on this branch:

```bash
git -C repos/PhotoAlbum-Java checkout -b modernize
git -C repos/PhotoAlbum checkout -b modernize
```

Verify both repositories:

```bash
git -C repos/PhotoAlbum-Java status
git -C repos/PhotoAlbum status
```

Each should report `On branch modernize` with a clean working tree. `origin` points to the upstream `Azure-Samples` repositories, which are read-only for you — your work stays on the local `modernize` branch, and the challenges tell you when a push target is needed.

## Troubleshooting

| Problem | Resolution |
| --- | --- |
| `modernize: command not found` in Codespaces | Confirm that the Codespace was created with **Azure / App Innovation / GHCP App Modernization**. If it was not, delete that Codespace and create a new one with the correct configuration. If it was, rebuild the container and check the creation log for installation errors. |
| `modernize: command not found` after a local installation | Open a new terminal, or reload the shell with `source ~/.bashrc` or `source ~/.zshrc`, then run `modernize --version`. |
| `copilot: command not found` | In Codespaces: confirm the Codespace uses the **Azure / App Innovation / GHCP App Modernization** configuration (it installs GitHub Copilot CLI). Locally: install it with `npm install -g @github/copilot` and open a new terminal. |
| Copilot CLI reports an authentication or authorization error | Run `/login` inside `copilot` and verify the account with `/user`. Unset any explicitly exported `COPILOT_GITHUB_TOKEN`, `GH_TOKEN`, or `GITHUB_TOKEN` variable — it overrides the signed-in session. Classic personal access tokens (`ghp_…`) are not supported. |
| A CLI installation keeps failing on a local workstation | Switch to the recommended Codespace — it has all tools preinstalled and is the supported environment for this MicroHack. |
| The .NET assessment fails with `Failed to install .NET AppCAT tool` | Run the `dotnet tool install --tool-path … dotnet-appcat` command shown in the error message, then re-run the assessment. |
| `gh auth status` reports no account or the wrong account | Run `gh auth login --web --git-protocol https` and authenticate with the GitHub account that has GitHub Copilot access. |
| GitHub reports an SSO or SAML authorization error | Authorize the GitHub CLI credential for the organization through the link shown by GitHub, then retry the command. |
| The modernization CLI reports that Copilot is unavailable | Compare the account shown by `gh auth status` with the account that owns the GitHub Copilot subscription. Sign out and back in with the licensed account if they differ. |
| A `repos/<app>` clone already exists | Reuse it. Run `git -C <app> status`, make sure the working tree is clean, and create the `modernize` branch if it is missing. |
| `Permission denied` when pushing a sample application | Expected — the upstream `Azure-Samples` repositories are read-only for you. Keep your commits on the local `modernize` branch; the challenges tell you when and where to publish changes. |
| Azure commands use the wrong tenant or subscription | Run `az login --use-device-code`, then select the assigned subscription with `az account set --subscription "<subscription-name-or-id>"`. |

After the tools, authentication, and sample clones are verified, continue with [Challenge 1](../challenges/challenge-01.md).
