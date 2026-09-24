# Troubleshooting

Start with the symptom, then change only one layer at a time: VM access, local app, database, container image, Container App, telemetry, or pipeline. Do not print secrets while debugging.

## Quick symptom table

| What you see | Likely cause | First fix |
| --- | --- | --- |
| RDP cannot connect | JIT access is missing, expired, or opened for the wrong IP | Request **Just-in-Time VM access** for the matching VM and your current public IP. |
| RDP login fails | Wrong VM, username, password, or keyboard layout | Confirm `vm-dotnet-userNNN` or `vm-java-userNNN`; retype credentials manually. |
| `localhost:5000` or `:8080` does not load on the VM | App is stopped or you are using the other stack's port | Restart the selected app and check [`dotnet`](../dotnet/README.md) or [`java`](../java/README.md). |
| `/healthz` works but `/readyz` fails | Process is alive but database readiness failed | Check database host, name, port, SSL mode, service state, and `CATALOG_DATABASE_*`. |
| Fewer than 198 figures or 20 categories | Seed data path or startup import is wrong | Verify `data/catalog.json`, `data/images/`, and `CATALOG_STARTUP_IMPORT_ENABLED=true`. |
| Product images are broken | Image path, mount, blob URL, or content type is wrong | Test `/images/<file>.png`; check `CATALOG_IMAGES_PATH` or the storage URL. |
| App ignores the new database | Stale environment variable overrides config files | Print non-secret `CATALOG_DATABASE_*` values and clear old ones. |
| Azure database times out | Firewall does not allow the client or Azure service | Add your client IP for local tests; add the intended Azure access rule for ACA. |
| `az acr build` fails immediately | Wrong folder, missing Dockerfile, or registry typo | Run from `dotnet/` or `java/`; check `az acr show --name <acr>`. |
| Container App cannot pull image | Identity lacks `AcrPull` or registry server is wrong | Assign `AcrPull` on ACR to the app identity and fix registry settings. |
| Container App starts then exits | Missing env var, secret, target port, or data mount | Read revision logs and compare settings with the app README. |
| Scale rule does not fire | Load hits the wrong revision or the rule watches the wrong signal | Check traffic weight, min/max replicas, rule type, and `/perftest/catalog` load. |
| `/perftest/catalog` returns 401/403 | Missing or wrong `x-api-key` header | Use the configured API key; do not use this endpoint from a browser by accident. |
| No traces appear | Exporter or Application Insights connection string is missing, or ingestion is delayed | Generate fresh traffic, wait a few minutes, then query the workspace. |
| GitHub Actions cannot log in to Azure | OIDC subject, environment, or role assignment mismatch | Recheck federated credential fields and managed identity roles. |
| Approval gate never appears | GitHub environment name does not match the workflow | Create or rename the protected environment used by the workflow. |

## VM and JIT access

Each resource group has two VMs. Use only the one for the stack picked in [ch00](../challenges/ch00.md).

| Stack | VM | Local URL |
| --- | --- | --- |
| `.NET 8 + SQL Server` | `vm-dotnet-userNNN` | `http://localhost:5000` |
| `Java 17 + PostgreSQL` | `vm-java-userNNN` | `http://localhost:8080` |

The NSG starts closed. Request JIT from the VM blade, connect with Remote Desktop, and browse the app inside the VM. If you change networks, renew JIT for the new IP.

Useful PowerShell checks:

```powershell
Get-Process dotnet,java -ErrorAction SilentlyContinue
Test-NetConnection localhost -Port 5000
Test-NetConnection localhost -Port 8080
Get-ChildItem C:\MicroHack\logs
```

If `az vm run-command` reports a conflict, wait and retry. A VM accepts one run-command at a time, and an interrupted command can keep running in the background. Do not deallocate the VM unless a facilitator tells you to.

## Local application checks

The shared routes are `/`, `/figure/{id}`, `/images/{file}`, `/import`, `/healthz`, `/readyz`, and `/perftest/catalog`. The last one requires an `x-api-key` header.

If `/healthz` and `/readyz` both fail, debug startup, port binding, and runtime version. If only `/readyz` fails, debug the database first.

Print only non-secret settings:

```powershell
Get-ChildItem Env:CATALOG_* | Where-Object Name -notmatch 'PASSWORD|KEY|SECRET'
```

Environment variables override `appsettings.json` and `application.properties`. Restart the process after changing them.

## Managed database connectivity

For Challenge 1, public database access is allowed for learning simplicity. Common fixes:

- Add your current client IP when the app runs locally against Azure SQL or PostgreSQL.
- Behind a VPN or corporate proxy, the address the database sees is **not** what
  `curl https://api.ipify.org` reports. Take the address from the error itself — *"Client
  with IP address 'x.x.x.x' is not allowed to access the server"* — and whitelist that one.
- Allow Azure services only when your Container App needs to reach the database without VNet integration.
- Confirm database name, username format, port (`1433` for SQL, `5432` for PostgreSQL), and SSL requirements.
- Restart or create a new Container App revision after changing secrets or environment variables.

## ACR and Container Apps

For build problems:

```bash
az acr show --name <registry-name> --query loginServer -o tsv
az acr build --registry <registry-name> --image lego-catalog/app:latest <dotnet-or-java-folder>
```

For runtime problems:

```bash
az containerapp revision list -g <resource-group> -n <app-name> -o table
az containerapp logs show -g <resource-group> -n <app-name> --follow false --tail 100
```

Check image name, registry server, managed identity, `AcrPull`, target port, ingress, secrets, `CATALOG_DATABASE_*`, `CATALOG_IMAGES_PATH`, seed path, and readiness probe settings before rebuilding.

## Autoscaling and load tests

Challenge 2 uses `/perftest/catalog` because it creates predictable database work over ordinary HTTP. If replicas stay at one:

1. Confirm the load includes `x-api-key`.
2. Confirm the path is `/perftest/catalog`, not just `/`.
3. Confirm traffic reaches the revision with the scale rule.
4. Check min/max replicas; `maxReplicas=1` prevents visible scale-out.
5. Watch database CPU and connections; the bottleneck may move downstream.

Scale-down is not instant. Wait for the cooldown period before concluding it is stuck.

## OpenTelemetry and Application Insights

If traces do not appear in [ch04](../challenges/ch04.md):

- Confirm the Application Insights connection string is set on the active revision.
- Confirm the app starts the OpenTelemetry exporter.
- Generate fresh traffic after deployment.
- Wait a few minutes for ingestion.
- Check resource names so you know whether you are viewing VM, local, or ACA telemetry.

## GitHub Actions and OIDC

OIDC failures usually come from one mismatch. Compare the workflow with the Azure federated credential: organization, repository, branch, GitHub environment name, managed identity client ID, and role assignments.

The workflow needs permission to push images to ACR and update the Container App. Keep roles narrow: assign what it needs on the registry, app, and resource group rather than broad subscription access.

## When to ask a facilitator

Ask early if the issue is outside your resource group, affects subscription-wide settings, requires paid Defender or SRE resources, or involves deleting infrastructure. Also ask if a VM tool install appears missing; replacing a lab VM is often faster than repairing it by hand.

