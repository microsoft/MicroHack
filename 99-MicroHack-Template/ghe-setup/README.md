# MicroHack GitHub Enterprise tenant setup

Reusable setup for **disposable GitHub Enterprise Cloud tenants with Enterprise
Managed Users (EMU)**, based on the read-only inspection of
`MngEnvMCAP447224` / `mngenvmcap447224` on 2026-10-16. It uses Python's standard
library, GitHub CLI (`gh`), Git and Azure CLI (`az`); no Python packages are required.

**Warning: applying this setup installs a nightly workflow that permanently
deletes EVERY organization repository except `microhack`, regardless of name,
visibility, age or archive status. There is no keep-list.** This intentionally
matches the reference tenant. Do not use it in a shared or production organization.
The setup itself never deletes repositories or dispatches the cleanup workflow.
The next scheduled run, or a manual dispatch, performs deletion.

## What is managed

| Area | Configuration |
| --- | --- |
| Azure identity | Verify `GHCPUsers` and `GHCPAdmins` in the supplied Azure tenant against the provisioned GitHub SCIM groups' `externalId`. Refuse wrong-tenant/group matches. |
| Enterprise teams | Ensure `GHCPUsers` and `GHCPAdmins` exist and are linked to the corresponding SCIM groups. |
| Copilot seats | Grant the **enterprise team** `GHCPUsers` Copilot access. Verify active team-assigned seats for its current members. GitHub/SCIM handles subsequent group membership changes; no periodic user-name matching script is needed. |
| Organization teams | Ensure `participants` links to `GHCPUsers`, `admins` links to `GHCPAdmins`; grant read/admin access respectively to MicroHack. |
| Repository | Internal `microhack`, default branch `main`, forkable. Seed an empty repository with a snapshot of `microsoft/MicroHack` (not its history); do not replace an existing repository's contents/history. |
| Upstream workflow | Daily at **04:00 UTC**, copy the upstream main tree and preserve the two tenant workflows, using `MIRROR_TOKEN`. Same behavior as the reference, including its non-pruning `git checkout` synchronization (not a force mirror). |
| Cleanup workflow | Daily at **00:00 UTC**, paginate all organization repositories, delete all except the hosting repository (case-insensitive), then verify no others remain. Same behavior as the reference, including explicitly logged 404 races. |
| Budgets | Enterprise-level **Codespaces $6,000/month** and **Actions $100/month**, usage blocked at the limit, alerts enabled. Upsert by scope/product; never create duplicate budgets or delete unrelated budgets. Preserve existing recipients unless explicitly overridden; new budgets notify the authenticated owner. |
| Codespaces | Enable access for **all organization members** (explicitly selected for this automation; the reference access selection is not readable through the API). |
| Actions | Enabled for all organizations/repositories/actions; SHA pinning not required. Default workflow token read-only; PR-review approval allowed. First-time outside contributors need workflow approval. |
| Enterprise policies | Match the reference's forking, repository creation/access/deletion, collaborator, purchasing, deploy-key and project policies through GraphQL. Organization defaults permit internal, not private/public, repository creation. |
| Security defaults | Match the reference: no automatic Advanced Security, Dependabot alerts, secret scanning or push protection for new repositories. These are lab parity settings, **not production recommendations**. |
| Copilot coding agent | Enable for all organization repositories. Audit organization chat/CLI/public-code policies against the reference. |
| Tenant marker | Store `AZURE_TENANT_ID` as a repository Actions variable and reject reuse with a different tenant ID. |

The policy values are in [baseline.json](./baseline.json). Do not change the
repository/upstream/branch constants without updating and testing the workflows:
the reference synchronization behavior is deliberately fixed to upstream and
local `main`. Schedule times are UTC (local CET/CEST offsets vary).

## One-time prerequisites for each tenant

1. The GitHub enterprise and its organization already exist. An Azure tenant ID
   alone cannot create a GitHub enterprise, buy its subscription, configure SSO,
   authorize billing or establish Entra SCIM provisioning using these APIs.
2. Configure the enterprise's Entra SAML/OIDC and SCIM integration. Assign
   `GHCPUsers` and `GHCPAdmins` to the enterprise application, provision both groups,
   and allow provisioning to complete. The script **does not** recreate users,
   invite personal accounts, edit Azure group membership or overwrite SSO settings.
3. Enable a Copilot Business/Enterprise subscription for the enterprise. The
   automation grants purchased seats to `GHCPUsers`; it cannot accept purchase
   terms or enable a subscription where none exists. The reference organization's
   `/copilot/billing` shows `seat_management_setting=unconfigured` and zero org seats:
   this is expected because licensing happens through the **enterprise** team.
4. Sign into `gh` as the target tenant's enterprise **and** organization owner.
   For the reference account:

   ```bash
   gh auth switch --hostname github.com --user manuelgugger_ms447224
   gh auth refresh --hostname github.com \
     --scopes repo,workflow,admin:org,admin:enterprise,manage_billing:enterprise
   ```

   Use the corresponding owner account in every other tenant. An explicit
   `GH_TOKEN` environment variable overrides the stored CLI login; remove it if
   relying on `gh auth switch`. Setup does not switch accounts or change global
   Git credential configuration. Enterprise changes affect **all organizations**
   in that enterprise, not only MicroHack.
5. Sign into Azure CLI for the target tenant. The identity needs Microsoft Graph
   `Group.Read.All` or `Directory.Read.All`, with appropriate consent:

   ```bash
   az login --tenant <azure-tenant-guid> --allow-no-subscriptions
   ```

6. For first apply, provide `MIRROR_TOKEN` **in the process environment**, not in a file,
   JSON configuration, command argument or source control. Use a target org
   owner's **classic PAT** with `repo`, `workflow`, `delete_repo`, `admin:org`,
   and any required SSO authorization. The script validates its scopes and org
   owner role and stores it as an encrypted repository Actions secret via stdin.
   Alternatively, create the empty internal target repository first and enter the
   PAT directly into GitHub CLI's hidden prompt:

   ```bash
   gh secret set MIRROR_TOKEN --repo <organization-name>/microhack
   ```

   With no environment token, setup reuses an existing repository secret without
   overwriting it. Only its existence can be verified, not its scopes, value or
   expiry; the run explicitly requires workflow validation. This also supports
   subsequent applies without entering the token again.

   A default `GITHUB_TOKEN` cannot delete sibling repositories or update workflows.
   If the enterprise disallows classic PATs, this reference-compatible credential
   model must be changed before use; a fine-grained PAT limited to MicroHack
   cannot perform the all-repository cleanup.

   For example, in Bash, enter the PAT without putting it in shell history:

   ```bash
   read -rsp "MIRROR_TOKEN: " MIRROR_TOKEN; echo
   export MIRROR_TOKEN
   ```

## Run

From this directory, preview first (no GitHub or Azure writes):

```bash
python3 setup-ghe.py --tenant-id <azure-tenant-guid> \
  --report /tmp/ghe-plan.json
```

With one visible enterprise and organization, they are discovered from the
authenticated GitHub account. Otherwise specify `--enterprise <slug>` and
`--organization <name>`. The script verifies that the organization belongs to
that enterprise and that the current account owns both.

Apply requires an explicit organization-name confirmation of the destructive
nightly behavior:

```bash
python3 setup-ghe.py --tenant-id <azure-tenant-guid> \
  --enterprise <enterprise-slug> --organization <organization-name> \
  --confirm-organization <organization-name> --apply \
  --report /tmp/ghe-apply.json
```

Optionally repeat `--budget-alert-login <target-github-login>` to explicitly set
recipients for **both** budgets. Without it, existing recipients are retained and
new budgets use the current owner. Budgets do not include Copilot license costs,
premium requests or AI credits.

Audit later:

```bash
python3 setup-ghe.py --tenant-id <azure-tenant-guid> --check \
  --report /tmp/ghe-audit.json
```

For a read-only GitHub inspection when Azure credentials are unavailable, omit
`--tenant-id` or use `--skip-azure-verification`. This is explicitly reported as
incomplete and is **never allowed with `--apply`**.

The script is rerunnable: it updates drift, preserves unrelated repository
files/budgets, never force-pushes, and reasserts team licensing and Codespaces
access. PATCH requests only send changed fields, avoiding re-submission of
unchanged settings controlled by inherited enterprise policies.
GitHub adds the creator to a new organization team. If that creator is the sole
explicit member, setup removes that team membership before SCIM linking (their
organization-owner role is unchanged). Other explicit memberships stop setup
for review instead of being silently removed.
If interrupted during repository creation, rerun to seed the empty
repository. Wait for SCIM propagation and rerun if licensing has not converged.
Failures are printed and stop the run; already-applied changes are not rolled back.
An existing `main` protected by rulesets/branch protections must permit the owner
and scheduled sync to push; a rejection is an error, not a reason to bypass policy.

### Exit codes and verification boundaries

- `0`: preview completed; **not** a claim that the tenant is ready.
- `1`: authorization, prerequisite, API, command or read-back verification failure.
- `2`: check/apply completed but **manual verification is still required**.

Apply reads back supported settings, group links, current team seat assignments,
budgets, workflows, secret existence, repository team permissions and the tenant
marker. JSON reports contain the target, operations and explicit manual items,
never tokens. On a failure, the nonzero exit and stderr are authoritative; a final
report is only written when the full run reaches its reporting stage.

Public APIs do **not** expose all feature policies, a Codespaces access GET, the
contents/expiry of existing secrets, or all organization policy setters.
Therefore check/apply deliberately return `2`, not a false fully-verified success.
Complete the following operator checks before calling the tenant ready:

- Verify SSO/SCIM source tenant and group provisioning health.
- Verify enterprise Copilot access, feature/model policies and public-code
  suggestions (`allow`), IDE/GitHub chat and CLI (`enabled`). Organization billing
  API values are organization-local, not effective enterprise policies. For users
  licensed through the enterprise `GHCPUsers` team, an organization-local CLI
  value of `unconfigured` (or a disabled/locked organization control) does not
  establish an effective denial. Set the enterprise policy to **Enabled
  everywhere** to enforce it centrally. If using **Let organizations decide**,
  configure **Policies for enterprise-assigned users** as well. The audit reports
  local differences for context without treating them as effective-policy drift.
  See [GitHub policy precedence](https://docs.github.com/en/copilot/concepts/enterprise/policies)
  and [Copilot CLI administration](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/copilot-cli/administer-copilot-cli-for-your-enterprise).
- Verify Codespaces access, repository selection, machine, retention and
  idle-timeout policies in the UI. Codespaces access is reasserted on every apply.
- Verify organization member deletion/visibility/team-creation permissions against
  the `organization_observed` baseline; differences are reported with required UI
  actions because the public update API does not support these fields.
- Verify billing linkage, alert delivery and premium-request/AI-credit controls.
- Review active Copilot grants outside `GHCPUsers`. The script reports these and
  **does not revoke unrelated/direct assignments**; removing them can impact
  other organizations. Pending cancellations are not considered active seats.
- Verify token expiry/rotation and workflow run results. **Dispatching cleanup
  permanently deletes all other organization repositories.**
- Test with a real `GHCPUsers` participant: sign in, use Copilot, open a Codespace,
  create/fork an internal lab repository, and validate group removal/provisioning.
  License cancellation may remain billed until the end of the billing cycle.

## Validation

Offline unit and workflow-behavior tests (no live tenant writes):

```bash
python3 -m unittest discover -s tests -v
```

## Authentication troubleshooting

- **Enterprise APIs work, organization APIs return SAML/SSO HTTP 403:** the CLI
  token is not authorized for the organization, even if the browser is signed in.
  Sign into the enterprise's SSO, then run `gh auth refresh -h github.com -s user`
  while that SSO session is active and approve organization access. An API
  response's `X-GitHub-SSO` header can also provide the exact authorization URL.
- **Workflow checkout returns "Write access to repository not granted":** check
  that `MIRROR_TOKEN` belongs to the target managed owner, has the required
  classic PAT scopes, and is SSO-authorized. Replacing a secret in another
  repository or changing only the CLI login does not update the workflow secret.
  Verify the target secret's `updated_at` without reading its value:

  ```bash
  gh api repos/<organization-name>/microhack/actions/secrets/MIRROR_TOKEN \
    --jq '{name,updated_at}'
  ```

- **Organization Copilot CLI control is disabled/locked:** verify the enterprise
  policy first. **Enabled everywhere** overrides organization-local settings;
  do not enable organization-based licensing just to change a non-authoritative
  local value when licenses are intentionally assigned through enterprise teams.
- **Zero Copilot seats after setup:** an empty `GHCPUsers` group correctly has no
  user seats. Validate automatic assignment after a real participant is added to
  the Azure group and SCIM provisioning completes.
