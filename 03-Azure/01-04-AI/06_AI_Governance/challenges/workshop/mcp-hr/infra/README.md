# HR MCP APIM publication

This folder is self-contained Bicep for publishing the workshop HR MCP Container App through an existing APIM instance.

It creates:

- APIM `type: mcp` API at path `hr-mcp`, exposed as `${gatewayUrl}/hr-mcp/mcp`.
- APIM backend pointing at the HR MCP backend **base URL** (no trailing `/mcp`).
- Citadel-style product/access contract `MCP-HR-Tools-DEV`.
- Deterministic subscription `MCP-HR-Tools-DEV-SUB-01`.
- Product policy with Entra JWT validation, bearer forwarding, `tools/call` throttling, JSON-RPC batch rejection, and bounded trace snippets.

## Container base images and Docker Hub rate limits

The HR MCP server image (`mcp-hr/server/Dockerfile`) builds on `ghcr.io/astral-sh/uv:python3.13-bookworm-slim`, a single GHCR image that bundles both Python 3.13 and `uv`. GHCR is not subject to Docker Hub's anonymous pull-rate limit (`toomanyrequests`), which previously caused ACR remote builds to fail or appear to hang while pulling `python:3.13-slim` from Docker Hub.

To further reduce external pulls, the server Dockerfile parameterizes the base image with a build arg (`BASE_IMAGE`), and the build path first mirrors the image into the target ACR with `az acr import`, then builds against the ACR-local copy:

- `deploy-hr-mcp.*` imports `ghcr.io/astral-sh/uv:python3.13-bookworm-slim` into the HR MCP ACR and builds the server image with `--build-arg BASE_IMAGE=<acr>/astral-sh/uv-python:3.13-bookworm-slim`.

If `az acr import` is unavailable or fails, the build falls back to the public GHCR image (a warning is printed). The default remains the public GHCR image, so the Dockerfile still works without ACR mirroring.

## Networking

`deploy-hr-mcp.*` creates two Container Apps paths:

- a public, Entra-protected ACA endpoint for direct laptop troubleshooting;
- a private/internal ACA endpoint for APIM backend traffic.

For the private path, the deploy script discovers the Citadel hub VNet in the hub resource group and creates/uses a dedicated `snet-mcp` subnet delegated to `Microsoft.App/environments`. It inspects the VNet address space and existing subnets, then selects the first available subnet prefix (`/26` by default, configurable with `HR_MCP_ACA_SUBNET_PREFIX_LENGTH`). Override with `HR_MCP_CITADEL_VNET_NAME`, `HR_MCP_ACA_SUBNET_NAME`, `HR_MCP_ACA_SUBNET_PREFIX`, or `HR_MCP_ACA_SUBNET_ID` when needed. The script does not add VNet address space automatically; if no suitable prefix is available, expand the Citadel VNet or provide an available `HR_MCP_ACA_SUBNET_PREFIX`.

The APIM publication scripts prefer `HR_MCP_PRIVATE_BACKEND_URL`, emitted by `deploy-hr-mcp.*`. The public direct ACA troubleshooting endpoint remains unchanged.

### Internal environment ingress (important)

The private Container Apps environment is created with `--internal-only`, so it has no public endpoint and is reachable only from the peered/injected VNet. Within an **internal** environment, the app ingress type still matters:

- `external: true` publishes the app on the environment's **VNet-facing** internal load balancer. This is what APIM (running in the hub VNet) must reach, and it is still private — there is no internet exposure because the environment itself is internal-only. The app FQDN is `<app>.<envDefaultDomain>`.
- `external: false` publishes the app **only inside the environment** (app-to-app). APIM in the VNet cannot reach it and receives an `Azure Container App - Unavailable` 404 from the environment edge.

Therefore the private HR MCP app is deployed with `--ingress external --transport http`. A custom private DNS zone for the environment `defaultDomain` (wildcard `A` records to the environment static IP) is linked to the hub VNet so APIM can resolve the backend FQDN.

### Private DNS

`deploy-hr-mcp.*` creates a private DNS zone for the internal environment `defaultDomain`, links it to the Citadel hub VNet, and adds wildcard `A` records (`*` and `*.internal`) pointing to the environment static IP. APIM resolves the backend FQDN through this zone.

### Backend Host header

The APIM API policy forwards a single `Host` header equal to the backend FQDN (`set-header name="Host" exists-action="override"`). This is required because the ACA environment edge routes requests by Host; without the override APIM may forward the gateway hostname and the edge returns a 404 `Unavailable` page.

## Policy streaming note

The product policy inspects JSON request bodies so it can identify `tools/call` and reject batches. Response snippets are logged only when the response is not `text/event-stream`; this avoids buffering streamable MCP responses where possible. Authorization headers and bearer tokens are not logged.
