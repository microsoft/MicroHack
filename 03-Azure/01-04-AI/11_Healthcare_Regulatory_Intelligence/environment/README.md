# Where to run the tools

[Home](../README.md)

The challenges need only a browser. You run the supplied tools in one of three places; the same commands work in all of them.

| Place | Use it for | Setup |
|---|---|---|
| **Azure Cloud Shell** (recommended for Challenges 1–5) | `python3 -m regintel …` | None. Python 3 and the Azure CLI are built in |
| **GitHub Codespaces** | Challenge 6, or all challenges | Opens the lab's dev container in the browser |
| **Dev container in VS Code** | Challenge 6 on your own machine | Docker plus the VS Code Dev Containers extension |

The `regintel` tools use only the Python standard library and the Azure CLI. Only the optional Challenge 6 assistant needs extra packages, and the container installs those for you.

## GitHub Codespaces

Codespaces only reads dev container configurations from the repository root's `.devcontainer` folder, where every MicroHack has its own folder. This lab's is `.devcontainer/03-azure-01-04-ai-11-healthcare-regulatory-intelligence/`; it builds from the same Dockerfile as the lab's local devcontainer. Choose it explicitly:

1. On GitHub, open the repository and branch your facilitator names, then select **Code → Codespaces → … → New with options**.
2. Under **Dev container configuration**, select **Azure / AI / Regulatory Intelligence**.
3. Select **Create codespace**. Codespaces may be billed to your GitHub account or organisation.

From a terminal you can do the same:

```bash
gh codespace create --repo <owner>/MicroHack --branch <branch> \
  --devcontainer-path .devcontainer/03-azure-01-04-ai-11-healthcare-regulatory-intelligence/devcontainer.json
```

## Dev container on your machine

Open the folder `03-Azure/01-04-AI/11_Healthcare_Regulatory_Intelligence` in VS Code and choose **Dev Containers: Reopen in Container**. Only this lab folder is mounted into the container.

## What the container does when it starts

1. Builds from `mcr.microsoft.com/devcontainers/python:1-3.12-bookworm` and adds the Azure CLI, Bicep and the Azure Developer CLI.
2. Installs `uv` 0.12.10 and every Python package from the **package feed proxy** (`https://packagefeedproxy.microsoft.io/pypi/simple/`), using the exact versions in `uv.lock`. The virtual environment lives outside the lab folder, at `/home/vscode/.venvs/regintel`, so a Windows `.venv` can never break it.
3. Runs every lab test: `uv run --frozen --all-extras pytest -q`. These tests check the monitor, de-duplication, versioning, citations, sign-off rules, the agent chain (built offline, with network calls blocked), the documentation links and these container settings.

**The container is ready when that command ends with `passed` and no failures.** It does not sign in to Azure, deploy anything or call a model. Port 8088 is forwarded **privately** for the optional local run of the hosted assistant.

To run the checks again at any time:

```bash
uv run --frozen --all-extras pytest -q
```

## Sign in to Azure from a Codespace or container

```bash
az login --use-device-code
az account set --subscription "<lab subscription>"
```

Never paste a Temporary Access Pass into the terminal; type it only on the Microsoft sign-in page.

## For maintainers

- `.github/workflows/regulatory-intelligence-devcontainer.yml` is a **reference** workflow. GitHub only runs workflows from the repository root, so run the container check manually before publishing changes.
- After changing `pyproject.toml`, regenerate the lock through the proxy with `uv lock`, then rebuild the container.
