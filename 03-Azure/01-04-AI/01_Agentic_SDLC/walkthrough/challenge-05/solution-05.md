# Walkthrough Challenge 5 - Deploy into Azure

**[Home](../../Readme.md)** - [Previous Challenge Solution](../challenge-04/solution-04.md) - [Next Challenge Solution](../challenge-06/solution-06.md)

Duration: 60 minutes

## Prerequisites

Complete [Challenge 4](../challenge-04/solution-04.md). Confirm your **Azure prerequisites**: subscription/budget, Contributor on your scope, a working GitHub ↔ Azure **OIDC federated credential**, and region capacity.

## Approach

The most operationally demanding challenge. **Get to a simple, working deploy early**, then refine — a reachable app on basic infra beats perfect templates that never ship. Auth and quota are the top time sinks.

Suggested pacing:

```
Choose IaC + author templates            ~20 min
Build the Actions pipeline               ~20 min
Configure secure auth (OIDC/secrets)     ~10 min
Deploy and verify                        ~10 min
```

### Task 1: Choose IaC and author templates

- Pick **Bicep** or **Terraform** and let Copilot scaffold the resources: compute for frontend/API, storage/database, supporting services.
- 💡 **Optional starter scaffold** — [`infra/`](../../infra/README.md) (Bicep) is bundled in this MicroHack folder; combined with the bundled [`.github/workflows/deploy.yml`](../../.github/workflows/deploy.yml) it sketches a **Container Apps + ACR + Log Analytics + OIDC** topology — two apps (`api` on port 3000, `frontend`/nginx on port 80). The design decisions (SKUs, database/storage strategy, API ingress visibility, secrets, scaling, image build/push, frontend→api discovery) are deliberately left as `TODO`. It's a de-risking starting point, **not** a required or "correct" answer — extend it, replace it, or ignore it. See [`infra/README.md`](../../infra/README.md).

### Task 2: Build one linear pipeline

- Author a single GitHub Actions workflow that goes **build → test → provision → deploy**. Keep it linear and readable.

### Task 3: Configure secure auth

- 🔑 Use **OIDC federated credentials** for Azure auth, not long-lived secrets. The **most common wall** is the federated-credential subject (`repo:<owner>/<repo>:ref:refs/heads/main` or an environment subject) or a missing role. If auth fails in the pipeline, check this first and confirm the identity has Contributor on your scope.

### Task 4: Deploy and verify

- Get a simple deploy reachable first, then refine SKUs and structure. Load the app's Azure URL and exercise a real flow (e.g. the cart). Ask Copilot for **Azure Well-Architected** guidance when choosing SKUs/services.

## Common blockers

- **Azure auth fails** → almost always the OIDC/federated credential or a missing role.
- **Quota / capacity errors** → fall back to a smaller SKU or an alternate region.
- **Provisioning partially fails** → tear down the resource group and re-provision clean rather than patching half-built state.
- **Secrets committed to source** → stop and move them to GitHub secrets / OIDC.
- **Pipeline green but app unreachable** → check ingress/networking and that the deploy targeted the provisioned resources.

> No optional stretch. Fast finishers should harden the pipeline (environments, review gates) or get a head start on Challenge 6's observability.

You successfully completed challenge 5! 🚀🚀🚀
