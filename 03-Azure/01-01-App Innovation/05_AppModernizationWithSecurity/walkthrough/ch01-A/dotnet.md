# ch01-A solution · .NET — Modernize the existing application

> `dotnet-sqlserver` stack. Java walkthrough is [here](./java.md).

There are multiple ways to solve this challenge; below is one possible approach. It keeps
the existing application and moves it forward: newer framework, a container, and a managed
database.

Work in **GitHub Codespaces** on your own fork or clone of this repository. The
[dev container](../../.devcontainer/README.md) already has both SDKs, Maven, Docker and the
Azure CLI, so nothing needs installing on your machine. The legacy VM from Challenge 0
stays as it is — it is the "before" you can go
back and look at.

| | |
| --- | --- |
| Source folder | `dotnet/` |
| Managed database | Azure SQL Database (serverless) |
| Local port | 5000 |

## Step 1: Upgrade the framework

The application runs on .NET 8. Before moving anything to Azure, bring it up to date — an
upgrade is much easier to review while the app still runs locally against a local database.

The **GitHub Copilot app modernization** extension does this as a guided flow: it assesses
the project, proposes a plan, and then executes the upgrade task by task. Install it in VS
Code, open the `dotnet/` folder, and run the upgrade. Review each change before accepting
it, and run the existing tests after each step.

If you prefer plain Copilot Chat, this works too:

```
Upgrade this project to the latest LTS .NET version.
- Move from .NET 8 to .NET 10, updating the target framework, the SDK version, and all NuGet packages
- Do not change application behavior, routes, or the database schema
- Fix any compilation errors and deprecated API usage introduced by the upgrade
- Work in small steps and explain each change before making it
```

Verify with the existing test suite, then run the app locally to confirm it still behaves
the same way:

```powershell
dotnet test dotnet/LegoCatalog.sln
dotnet run --project dotnet/src/LegoCatalog.App/LegoCatalog.App.csproj
```

> If the upgrade turns into a fight, timebox it. Getting to Azure matters more than
> reaching the newest possible version — .NET 9 is a perfectly good stopping point.
>
> The upgraded project files are in
> [`dotnet/app/src/…/LegoCatalog.App.csproj`](./dotnet/app/src/LegoCatalog.App/LegoCatalog.App.csproj)
> and [`dotnet/app/tests/…`](./dotnet/app/tests/LegoCatalog.App.Tests/LegoCatalog.App.Tests.csproj).

## Step 2: Use a cloud database

We do not change the application yet: we leave it running locally and deploy a managed
database for it to talk to. For this first iteration we allow access over a public
endpoint (we tighten this in ch07-enterprise). We use the serverless tier so the database
scales with load and costs little when idle.

You can deploy the database with the Azure Portal, Azure CLI, Bicep, Terraform, or Pulumi.
Here we use **GitHub Copilot** to author Bicep.

```
In folder bicep create Bicep template to deploy Azure SQL Database in serverless SKU to Azure.
- Make sure to whitelist IP of our application and allow public access, IP should be parameter
- Administrator login and password should be parameter and ensure @secure() annotation for password
- Use location that is derived from resource group location
- As name must be unique add some unique string with full resource group ID as seed
- Create main.bicep as well as example bicepparam file
- Check correct syntax at #fetch https://learn.microsoft.com/en-us/azure/templates/microsoft.sql/servers?pivots=deployment-language-bicep
- Read documentation at #fetch https://learn.microsoft.com/en-us/azure/azure-sql/database/serverless-tier-overview?view=azuresql&tabs=general-purpose
- Use database auto-pause after 1 hour and autoscaling between 0.5 and 2 cores
- Write simple README.md to describe how to deploy to your resource group and reference parameters file
```

Deploy it:

```powershell
az deployment group create --resource-group rg-userNNN --template-file bicep/main.bicep --parameters bicep/main.bicepparam
```

> A worked version of this template — built up across steps 2, 4, 5 and 6 — is in
> [`dotnet/bicep/`](./dotnet/bicep/README.md).

Now move the data. The catalog is small, so the simplest route is to let the application
create the schema and re-import the seed data:

1. Point the application at the new database using the `CATALOG_DATABASE_*` environment
   variables documented in [`dotnet/README.md`](../../dotnet/README.md).
2. Leave `CATALOG_STARTUP_IMPORT_ENABLED=true` so the app applies its migration and
   imports `data/catalog.json` on startup.
3. Start the app and confirm the catalog page lists all 198 figures across 20 categories.

If you would rather move the existing rows, export and restore instead — a `.bacpac` via
SQL Server Management Studio or the Azure portal. Ask Copilot for the exact command line.

> Environment variables override `appsettings.json`. If you previously exported a
> connection setting in your shell, either clear it or update it — a stale variable is the
> most common reason the app "ignores" your new database.

## Step 3: Package as a Docker container

Create a Dockerfile so the application can run anywhere, and test it right there in the
dev container — it has a Docker daemon.

The application reads a data folder containing the seed JSON and the product images. It is
not good practice to bake static content into the container image, so mount that folder as
a volume for now.

Use GitHub Copilot to write the Dockerfile:

```
Create a Dockerfile for my application.
- This is a Razor/Blazor Server app currently run with `dotnet run --project src/LegoCatalog.App/LegoCatalog.App.csproj`; use the built-in Kestrel web server
- We are building for Linux
- Use a multi-stage Dockerfile so we build with the SDK image and run on the smaller ASP.NET runtime image
- Place the Dockerfile in the dotnet/ folder, so all paths inside are relative to it
- Add example docker CLI commands to the README showing how to build the image and run it with the data folder mounted as a volume and the database connection supplied as environment variables
```

Build and run it locally, and confirm you get the same catalog page as before.

> A worked [`Dockerfile`](./dotnet/app/Dockerfile) and
> [`.dockerignore`](./dotnet/app/.dockerignore), with the `docker build` and `docker run`
> commands, are in [`dotnet/`](./dotnet/README.md).

## Step 4: Create an Azure Container Registry and build there

Ask GitHub Copilot to add ACR to your Bicep template:

```
Extend current main.bicep file to also create Azure Container Registry resource
- As name must be unique add some unique string with full resource group ID as seed
- Use configurable SKU as parameter, but Basic will be default option
- See Bicep documentation for this resource at #fetch https://learn.microsoft.com/en-us/azure/templates/microsoft.containerregistry/registries?pivots=deployment-language-bicep
- You can also check quickstart #fetch https://learn.microsoft.com/en-us/azure/container-registry/container-registry-get-started-bicep?tabs=CLI
```

After deploying, run an on-demand build inside ACR. This needs no local Docker daemon:

```powershell
cd dotnet
$registry = "yourregistryname"
az acr build --registry $registry --image lego-catalog/app:latest .
```

## Step 5: Let Azure services reach the database

For simplicity we deploy the application without VNet integration, so there is no
predictable outbound IP to whitelist. Temporarily enable access from Azure services.

```
Extend main.bicep to enable "Allow access to Azure services" on the Azure SQL server —
a firewall rule with 0.0.0.0 as both the start and the end IP.
```

Note: in ch07-enterprise you replace this with Private Endpoints and remove public access
entirely.

## Step 6: Deploy to Azure Container Apps

Extend the Bicep template to deploy the container, referencing the database and the
registry:

```
Modify main.bicep to deploy application into Azure Container Apps.
- Make sure to deploy ACA environment with workload profile (v2) and use consumption for our app (note consumption profile has no minimum or maximum count settings).
- App will use environment variables for the database connection (CATALOG_DATABASE_HOST, CATALOG_DATABASE_NAME, CATALOG_DATABASE_USERNAME, CATALOG_DATABASE_PASSWORD); the password must come from a Container Apps secret
- App needs one volume for the seed JSON file and one for images. Mount Azure Files shares and set CATALOG_IMAGES_PATH and CATALOG_SEED_PATH accordingly.
- App will use external ingress targeting the port exposed by my Dockerfile
- App will scale between 0 and 3 instances based on HTTP scaling
- Name of container image in our ACR is lego-catalog/app:latest
- #fetch Bicep structure from https://learn.microsoft.com/en-us/azure/templates/microsoft.app/managedenvironments?pivots=deployment-language-bicep and https://learn.microsoft.com/en-us/azure/templates/microsoft.app/containerapps?pivots=deployment-language-bicep
- You can check additional examples at #fetch https://learn.microsoft.com/en-us/azure/container-apps/azure-resource-manager-api-spec?tabs=arm-template
- #fetch volumes information at https://learn.microsoft.com/en-us/azure/container-apps/storage-mounts-azure-files?tabs=bash
- Configure RBAC and managed identities so ACA can access ACR for image pull following this guide: #fetch https://docs.azure.cn/en-us/container-apps/managed-identity-image-pull?tabs=bash&pivots=bicep
- Size container to 1 cpu and 2GB of RAM
```

Upload `data/catalog.json` and `data/images/` to the file shares, then open the Container
App ingress URL and test the application.

**That's it! The app is up and running and you are ready for the next challenge.**

## Verify

- The catalog page lists 198 figures across 20 categories.
- Search and category filtering work.
- A figure detail page opens and its photograph loads.
- `GET /healthz` returns healthy and `GET /readyz` reports the database as reachable.
- The Container App scales to zero when idle and comes back on the next request.

## BONUS

We separated static content from the container image, which is good — but even better
would be to avoid serving images from the application container at all. As a bonus,
investigate what it takes to **serve the images directly from Azure Blob Storage**. With a
base URL change and the right CORS settings you save container resources and get a more
scalable, cheaper solution.

Static content can also be cached. In ch07-enterprise, when you add **Azure Front Door**
for security and performance, you can enable **image caching** to accelerate delivery
further.

---

**Challenge:** [ch01-A · .NET](../../challenges/ch01-A-dotnet.md) ·
**Java walkthrough:** [ch01-A · Java](./java.md) ·
**Next solution:** [ch02](../ch02/README.md)
