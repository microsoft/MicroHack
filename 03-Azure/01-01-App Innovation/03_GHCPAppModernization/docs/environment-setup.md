# Environment setup

Use GitHub Codespaces for this MicroHack unless your facilitator asks you to use a local workstation. The repository provides a dedicated development container with the required .NET, Java, Docker, Azure, GitHub, Copilot, and modernization tooling.

## Option A: GitHub Codespaces (recommended)

### 1. Create the Codespace

1. Sign in to [GitHub](https://github.com/) with the account that has your GitHub Copilot subscription.
1. Fork the MicroHack repository if you do not already have a fork you can modify.
1. From your fork, select **Code** > **Codespaces** > **New with options**.
1. For **Dev container configuration**, select **Azure / App Innovation / GHCP App Modernization**.
1. Create the Codespace and wait for the container setup to finish.

Do not create the Codespace with the default configuration. The MicroHack repository contains several development containers, and the other configurations do not necessarily include the tools required by this hack.

### 2. Verify the tools

Open a terminal in the Codespace and run:

```bash
gh --version
modernize --version
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

Follow the browser prompt and use the same GitHub account that owns your sample application forks and has GitHub Copilot access.

> [!NOTE]
> GitHub and Azure use separate authentication sessions. A successful `az login` does not sign in the modernization CLI to GitHub.

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

Use the [modernization agent quickstart](https://learn.microsoft.com/azure/developer/github-copilot-app-modernization/modernization-agent/quickstart) for the current platform-specific prerequisites and installation options.

On Linux or macOS, install and verify the modernization CLI with:

```bash
curl -fsSL https://raw.githubusercontent.com/microsoft/modernize-cli/main/scripts/install.sh | sh
source ~/.bashrc
modernize --version
```

If you use Zsh, run `source ~/.zshrc` instead. On Windows, install the CLI with:

```powershell
winget install GitHub.Copilot.modernization.agent
```

Open a new terminal after the Windows installation. Then authenticate and verify GitHub CLI:

```bash
gh auth login
gh auth status
```

Your workstation must also provide the SDKs and tools listed in the [general prerequisites](../Readme.md#general-prerequisites).

## Fork and clone the sample applications

Keep the sample applications in separate repositories. Challenges 2 and 3 create commits, branches, and pull requests independently for each application.

### 1. Create the forks

Open both fork pages while signed in with the GitHub account used by `gh`:

- [Fork PhotoAlbum-Java](https://github.com/Azure-Samples/PhotoAlbum-Java/fork)
- [Fork PhotoAlbum](https://github.com/Azure-Samples/PhotoAlbum/fork)

Create both forks under your GitHub account or the organization assigned by your facilitator.

### 2. Clone your forks

In the GHCP App Modernization Codespace, the terminal starts in the hack directory. Run:

```bash
mkdir -p repos
cd repos

GH_USER="$(gh api user --jq .login)"
git clone "https://github.com/${GH_USER}/PhotoAlbum-Java.git"
git clone "https://github.com/${GH_USER}/PhotoAlbum.git"
```

If your forks belong to an organization rather than your personal account, replace `${GH_USER}` with the organization name in both clone URLs.

Verify that each `origin` points to your fork:

```bash
git -C PhotoAlbum-Java remote -v
git -C PhotoAlbum remote -v
```

Do not continue until both `origin` URLs refer to repositories where you have permission to push.

## Troubleshooting

| Problem | Resolution |
| --- | --- |
| `modernize: command not found` in Codespaces | Confirm that the Codespace was created with **Azure / App Innovation / GHCP App Modernization**. If it was not, delete that Codespace and create a new one with the correct configuration. If it was, rebuild the container and check the creation log for installation errors. |
| `modernize: command not found` after a local installation | Open a new terminal, or reload the shell with `source ~/.bashrc` or `source ~/.zshrc`, then run `modernize --version`. |
| `gh auth status` reports no account or the wrong account | Run `gh auth login --web --git-protocol https` and authenticate with the GitHub account that has GitHub Copilot access. |
| GitHub reports an SSO or SAML authorization error | Authorize the GitHub CLI credential for the organization through the link shown by GitHub. If repository creation through `gh` remains blocked, create the fork in the browser and clone it over HTTPS. |
| The modernization CLI reports that Copilot is unavailable | Compare the account shown by `gh auth status` with the account that owns the GitHub Copilot subscription. Sign out and back in with the licensed account if they differ. |
| A sample repository fork already exists | Reuse the existing fork. Clone it into `repos/` and confirm its `origin` with `git remote -v`. |
| `Permission denied` when pushing a sample application | The clone probably points to the upstream `Azure-Samples` repository or to the wrong account. Update `origin` to your fork before continuing. |
| Azure commands use the wrong tenant or subscription | Run `az login --use-device-code`, then select the assigned subscription with `az account set --subscription "<subscription-name-or-id>"`. |

After the tools, authentication, forks, and remotes are verified, continue with [Challenge 1](../challenges/challenge-01.md).
