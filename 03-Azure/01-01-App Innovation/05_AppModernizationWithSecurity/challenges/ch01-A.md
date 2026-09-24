# ch01-A: Modernize the existing application

> This is **path A** of [Challenge 1](ch01.md). If you have not chosen a path
> yet, [read the chooser first](ch01.md). Path B is
> [here](ch01-B.md) — you do not need it.

## Goal

Keep the catalog application you have, and move it forward: a current framework version,
running as a container on **Azure Container Apps**, talking to a **managed database**, with
the product images served from **Azure storage**.

Work in **GitHub Codespaces** on your own fork or clone of this repository. The
[dev container](../.devcontainer/README.md) already has both SDKs, Maven, Docker and the
Azure CLI, so nothing needs installing on your machine. The legacy VM from
[Challenge 0](ch00.md) stays exactly as it is. It
is the "before" you can go back and look at, and in path A you never deploy from it.

## Pick your stack

The steps are the same shape for both stacks, but the commands, the prompts and the managed
database differ enough that we keep them apart. **Open only the one you chose in
[Challenge 0](ch00.md)** and ignore the other completely.

| | `dotnet-sqlserver` | `java-postgresql` |
| --- | --- | --- |
| Source folder | [`dotnet/`](../dotnet/README.md) | [`java/`](../java/README.md) |
| Runs today on | .NET 8, Blazor Server | Java 17, Spring Boot 3 |
| Managed database | Azure SQL Database (serverless) | Azure Database for PostgreSQL Flexible Server |
| Local port | 5000 | 8080 |

➡️ **[Go to ch01-A · .NET](./ch01-A-dotnet.md)**

➡️ **[Go to ch01-A · Java](./ch01-A-java.md)**

## Success Criteria

Whichever stack you follow, you are finished when:

- The application is fully functional in Azure: browse, search, filter by category, open
  a figure detail page, and see its photograph.
- The application and the database are deployed separately, and the database is a managed
  Azure service.
- The application runs as a container on Azure Container Apps and can scale.
- No database password is committed to the repository.

## Solution — spoiler warning

[.NET walkthrough](../walkthrough/ch01-A/dotnet.md) ·
[Java walkthrough](../walkthrough/ch01-A/java.md)

---

**Challenge:** [ch01](ch01.md) · **Other path:**
[ch01-B](ch01-B.md) · **Next:** [ch02](ch02.md)
