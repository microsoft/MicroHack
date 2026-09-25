# GitHub Org Quick Setup
This script helps automating preparing GitHub organization for MicroHack. 

*Note: Participants need GitHub to succeed in challenge 03, but can use their personal space and fork this repo. Nevertheless this script helps preparing centralized repositories and funding from MicroHack subscription for users GitHub Copilot licenses, Codespaces and Actions.*

## 1. Create (or choose) an Organization
Create a free org in the browser if you don't have one:
https://github.com/account/organizations/new

## 2. Enable Azure Subscription Billing
- In GitHub: Organization Settings → Billing & plans → "Add Azure Subscription".
- Sign in with an Azure account that can grant (or trigger) tenant-wide admin consent for the GitHub SPV app.
- Select the desired Azure Subscription ID (you must be an Owner) and confirm.

## 3. Enable and configure GitHub
In the org UI: **Settings → Copilot → Choose Business → Enable**.
Configure **Copilot** - enable all models, enable web search, enable Copilot on GitHub.com, enable Code Review, enable preview features, Coding agent, MCP servers
Configure **Codespaces** → General → Enable for all members

During MicroHack see requests for Copilot seat assignments and approve.

## 4. Install & Login to GitHub CLI
Download: https://cli.github.com/
```pwsh
gh auth login -s admin:org -s manage_billing:copilot
```

## 5. Configure .env
Copy the sample and edit:
```pwsh
copy .env.sample .env
```
Set:
```
ORG_NAME=your-org-name
SOURCE_REPO=owner/source-repo   # no need to change
```

## 6. Install Dependencies
```pwsh
uv sync
```

## 7. Run
```pwsh
uv run python main.py
```
What it does:
- Verifies access to `ORG_NAME`.
- If `SOURCE_REPO` is set: creates (if missing) a repo of the same name in the org, marks it as a template, and for per-user repos generates a snapshot from that template (no original history preserved).

Output shows green check marks on success. Exit codes: 0=ok, 1=config/auth error, 2=org not found/no access.

That's it.
