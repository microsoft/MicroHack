# ch07-enterprise: make it survive an enterprise review

This optional challenge is for teams who want to harden the modernized catalog beyond
"it runs on Azure". Pick one enterprise control, design it well, and deploy it only if
there is time and subscription permission.

By now your chosen stack should be running as a container on **Azure Container Apps**,
with product data in either **Azure SQL Database serverless** or **Azure Database for
PostgreSQL Flexible Server**, images outside the app container, and telemetry flowing.
Enterprise review starts where the required path ends: who can reach it, who can change
it, where secrets live, and what happens when a control fails.

Defender for Cloud is already covered in [ch05-defender](ch05-defender.md), so
do not repeat that challenge. Use its findings as input, then go deeper on one control.

## Choose a control

Pick one area from the list below. A complete answer to one area is better than shallow
notes on all of them.

## 1. Network isolation

- Put clear boundaries around the Container Apps environment, database, registry, image
  storage, Key Vault, and observability resources.
- Evaluate private endpoints, delegated subnets, private DNS zones, and approved egress.
- Decide how operators, GitHub Actions, health probes, image pulls, and telemetry still
  reach what they need.
- Remove public access only after you have a tested replacement path.

The hard part is not creating a private endpoint. The hard part is keeping deployment,
diagnostics, and support usable after you close the public route.

## 2. Secure ingress

- Place Azure Front Door or Application Gateway with WAF in front of the application.
- Make the edge the only public entry point; test that the Container App cannot be reached
  directly.
- Configure TLS, custom domains if available, managed rules, rate limits, and health
  probes.
- Define how false positives are reviewed and how the team rolls back a bad WAF rule.

A WAF that can be bypassed by calling the origin URL is a dashboard, not a control.

## 3. Identity and secrets

- Replace remaining runtime passwords with managed identity where your selected service
  supports it.
- Use Key Vault for anything that cannot yet be identity-based.
- Build a simple identity-to-resource matrix: identity, role, scope, reason, and owner.
- Keep the database boundary stack-aware: Azure SQL and PostgreSQL handle Entra
  authentication differently.

No secret should end up in source, container layers, workflow logs, browser code, or chat
prompts.

## 4. Data protection

- Review encryption options for the database, registry, storage account, and monitoring
  data.
- Decide whether customer-managed keys are required, and where Key Vault or managed HSM
  would sit.
- Plan key rotation, soft delete, purge protection, service identities, and failure
  behavior.
- Add audit logging for data access that matters to your scenario.

Do not assume one encryption pattern works the same way across both database stacks.

## 5. Governance and operations

- Propose audit-first Azure Policy rules for region, tags, public network access,
  diagnostics, identities, and allowed SKUs.
- Add ownership for budgets, alerts, locks, exceptions, and expiry dates.
- Keep resource-group scope unless a facilitator explicitly approves broader changes.
- Describe cleanup and rollback before you deploy anything.

Platform controls are successful when teams can still ship safely, not when deployment
becomes impossible.

## Coach note

Ask a coach to review your design before changing networking, DNS, identity, keys, or
policy. These controls can affect more than your resource group.

> Tip: Start with a table: control, what it breaks, how you keep that working, how you
> test it, and how you undo it. Fill that in before writing infrastructure.

---

**Previous:** [ch06-sre-agent](ch06-sre-agent.md) · **Other optional challenge:** [ch07-innovation](ch07-innovation.md) · **Wrap-up:** [wrapup](wrapup.md)
