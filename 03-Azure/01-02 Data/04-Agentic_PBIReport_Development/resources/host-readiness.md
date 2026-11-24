# Participant VM and Copilot readiness

Complete this checklist on the **prepared VM before Challenge 1**. You verify the
environment; the organizer installs/pins tools, prepares both host configurations,
checks licensing/permissions and pilots the journey beforehand. Do not repair
missing packages, change tenant settings or update the event image yourself.

## Check your files and tools

- Open `C:\MicroHack\student` in VS Code or start Copilot CLI there. Both scenario
  CSV folders, `manifest.json`, `dictionary.md` and generator scripts must be under
  `datasets`; business/design briefs are under `briefs` on the VM. The platform's
  Student download instead keeps supporting briefs under `resources`.
- Connect to your private VM through the Azure portal's **Connect > Bastion**
  page using the VM credentials provided by the lab platform. A public VM IP or
  personal RDP source-range registration is not required.
- From that exercise folder, run `python datasets\generate-data.py --validate`.
  This reads and verifies both scenarios without changing files. Stop and ask the
  coach if files are absent or validation fails; do not regenerate over bad inputs.
- Check the supplied Git, Python, Node, Azure CLI, Copilot, VS Code and
  PowerShell 7 and `powerbi-report-author` commands against the organizer's
  approved version record.
  Report a missing tool or version mismatch rather than installing `latest`.

## Sign in and verify your chosen host

- **Copilot CLI (primary):** sign in as yourself, choose the approved available
  model, check your permitted usage budget, and inspect active authoring skills
  and CLI tools. The prepared path uses CLI/REST authoring, not a required MCP.
  The coach must resolve missing tools; a consumption-only MCP is not enough.
  If the coach asks you to run `C:\MicroHack\initialize-user.ps1`, review it first;
  it initializes your CLI skills and installs/verifies the prepared VS Code
  extensions in your profile. It refuses to overwrite unrelated existing skills.
- **VS Code Agent (alternative):** open the exercise folder, sign in, select Agent
  mode and the approved model, and inspect project skills and authoring commands.
  CLI plugin installation alone does not configure VS Code.
- Authenticate to Fabric/Power BI interactively with your assigned identity.
  Never share or print tokens. Opening the portal or acquiring a Fabric token does
  not prove Power BI query entitlement; ask the coach about authentication errors.

## Confirm scope with the coach

Confirm your supplied capacity ID, workspace alias, workspace-creation and
capacity-assignment permissions, and enabled authoring entitlement. **F16 alone
does not supply a Power BI authoring license.** Do not grant yourself capacity
administration or create a capacity, identity or license.

Read the [banking](banking-business-brief.md) or
[insurance](insurance-business-brief.md) brief and the
[dictionary](../datasets/dictionary.md). Workspace creation begins in Challenge 1;
it is not a preflight task. Manual Fabric experimentation is permitted within
the same approved scope. Stop for unresolved readiness failures.
