# Lab automation: App Modernization with Security

The MicroHack platform provisions one resource group and its participant Owner
assignment per lab. `deploy-lab.ps1` deploys the [Bicep template](main.bicep)
there, using the platform's region-fallback helper. `shared-deploy-lab.ps1`
registers the providers used by the base VMs and workshop challenges, plus the
Network public-IP feature, once per subscription before the participant deployments run.
No Terraform state, Entra user creation, or subscription-wide paid Defender
plans are deployed by this folder. The platform creates the users and resource
groups; the optional, **paid** Defender foundation in
[`baseInfra/terraform/defender.tf`](../baseInfra/terraform/defender.tf) remains
a separate facilitator decision and is disabled by default.

Each lab gets the two independent Windows Server 2025 legacy VMs (.NET/SQL
Server Express and Java/PostgreSQL), Premium OS disks, static Standard public
IPs, NICs, VNet/subnet, NSG, managed identities, VM Owner assignments and
Security Reader for its participant(s). The pinned install/provisioning
scripts are bundled in `scripts/` so platform deployments do not depend on
files outside this folder. Per-lab names derive from the precreated resource
group rather than Terraform's global participant index; the VNet CIDR
`10.1.0.0/22` is reused safely in separate resource groups. When no RDP
source CIDRs are specified, no inbound RDP rule is created; participants open
it only for their own IP in Challenge 0.
Azure VM resource names retain the stack name, while Windows computer names
use `d-` and `j-` plus the 12-character lab suffix to stay within the
15-character Windows limit.

## Facilitator prerequisites

Before starting the event:

1. Run [`preflight-capacity.ps1`](../baseInfra/scripts/preflight-capacity.ps1)
   against the actual subscription, participant count, preferred regions,
   `Standard_D2as_v5`, and **two** 127-GiB Premium OS disks per participant.
   Include two VMs and two Standard public IPs in the quota/cost review.
   This is a facilitator preparation step, not a check run by `deploy-lab.ps1`. The
   [baseline cost estimate](../docs/CostEstimate.md) puts 30 base labs at
   approximately $315/day; the `lab-defaults.json` $11/day estimate rounds up
   that baseline, **not** participant-created workloads or licensing.
2. The VM bootstrap is pinned in `deploy-lab.ps1` to the published workshop
   commit `4e3d090e252fd7197b529ed06d5cd427f158b2df` and its verified
   GitHub archive SHA-256. When updating workshop content, review and update
   both values together as in the [facilitator guide](../docs/Facilitator.md).
   No additional settings file or job environment variables are required.
   The platform-provided participant identity is used for the provisioner's
   migration-principal fields because that participant owns the lab's scope;
   this differs from the facilitator identity used by standalone Terraform.

The per-lab VM administrator password, database passwords, and performance
API keys use the platform's `New-MhhStablePassword` helper: re-runs converge on
the same credentials. They are passed to ARM as secure parameters, never stored
in this folder or printed in logs. The administrator and performance API
credentials are emitted to **that lab's** dashboard only after a successful
deployment. Treat Azure deployment history and VM custom data as sensitive;
restrict their access to the same trusted operators as the Terraform baseline.

The `GHCPUsers` group provisions Copilot seats for the workshop. Verify the
chosen `labsPerSubscription` (4) and regions against subscription quota.
Public IP creation in the workshop subscription requires registration of
`Microsoft.Network/AllowBringYourOwnPublicIpAddress`; if the subscription
does not permit it, the shared hook fails explicitly before any lab runs.

For the platform parameter contract, lifecycle, and region fallback details,
see the [MicroHack labautomation template](../../../../99-MicroHack-Template/labautomation/README.md).
