# ch01-A solution: Modernize the existing application

There are multiple ways to solve this challenge; the walkthroughs below describe one
possible approach for each stack. They keep the existing application and move it forward:
newer framework, a container, and a managed database.

Work in **GitHub Codespaces** on your own fork or clone of this repository. The
[dev container](../../.devcontainer/README.md) already has both SDKs, Maven, Docker and the
Azure CLI, so nothing needs installing on your machine. The legacy VM from Challenge 0
stays as it is — it is the "before" you can go
back and look at.

## Pick your stack

| | `dotnet-sqlserver` | `java-postgresql` |
| --- | --- | --- |
| Source folder | `dotnet/` | `java/` |
| Managed database | Azure SQL Database (serverless) | Azure Database for PostgreSQL Flexible Server |
| Local port | 5000 | 8080 |

➡️ **[.NET walkthrough](./dotnet.md)**

➡️ **[Java walkthrough](./java.md)**

The .NET walkthrough builds up a single Bicep template across steps 2, 4, 5 and 6. The
finished files for that path — the upgraded project files, the Dockerfile and the Bicep —
are in [`dotnet/`](./dotnet/README.md). The `dotnet/` folder at the repository root stays
in its legacy state on purpose, so it remains the "before" you can compare against.

The Java path has corresponding [solution artifacts](./java/README.md) and
[staged Bicep](./java/bicep/README.md). Its application files are overlays too, keeping
the root `java/` baseline intact.

## The six steps, in both walkthroughs

1. **Upgrade the framework** — while the app still runs locally, before Azure enters the
   picture.
2. **Use a cloud database** — deploy a managed database and move the catalog into it,
   without changing the application.
3. **Package as a Docker container** — multi-stage build, static content stays outside the
   image.
4. **Create an Azure Container Registry and build there** — `az acr build`, no local Docker
   daemon required.
5. **Let Azure services reach the database** — a temporary firewall opening, replaced by
   Private Endpoints in ch07-enterprise.
6. **Deploy to Azure Container Apps** — secrets, managed identity for image pull, Azure
   Files mounts, scale 0 to 3.

## Verify

- The catalog page lists 198 figures across 20 categories.
- Search and category filtering work.
- A figure detail page opens and its photograph loads.
- `GET /healthz` returns healthy and `GET /readyz` reports the database as reachable.
- The Container App scales to zero when idle and comes back on the next request.

---

**Challenge:** [ch01-A](../../challenges/ch01-A.md) ·
**Other path:** [ch01-B](../../challenges/ch01-B.md) ·
**Next solution:** [ch02](../ch02/README.md)
