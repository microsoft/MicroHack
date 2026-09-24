# ch01-A solution · Java — Modernize the existing application

> `java-postgresql` stack. .NET walkthrough is [here](./dotnet.md).

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
| Source folder | `java/` |
| Managed database | Azure Database for PostgreSQL Flexible Server |
| Local port | 8080 |

The finished [application overlays](./java/README.md) and
[Bicep files](./java/bicep/README.md) are available alongside this walkthrough. The
root `java/` folder remains the legacy baseline; apply the overlays to your working
copy before running the commands below.

## Step 1: Upgrade the framework

The application runs on Java 17 and Spring Boot 3.5.16. Before moving anything to Azure,
bring
it up to date — an upgrade is much easier to review while the app still runs locally
against a local database.

The **GitHub Copilot app modernization** extension does this as a guided flow: it assesses
the project, proposes a plan, and then executes the upgrade task by task. Install it in VS
Code, open the `java/` folder, and run the upgrade. Review each change before accepting it,
and run the existing tests after each step.

If you prefer plain Copilot Chat, this works too:

```
Upgrade this project to the latest LTS Java and Spring Boot version.
- Move to Java 21 and Spring Boot 4, updating pom.xml, the parent version, and all dependencies
- Do not change application behavior, routes, or the database schema
- Fix any compilation errors and deprecated API usage introduced by the upgrade
- Work in small steps and explain each change before making it
```

Verify with the existing test suite, then run the app locally to confirm it still behaves
the same way:

```bash
cd java && ./mvnw test && ./mvnw spring-boot:run
```

> If the upgrade turns into a fight, timebox it. Getting to Azure matters more than
> reaching the newest possible version — moving to **Java 21 only**, staying on Spring
> Boot 3.5, is a perfectly good stopping point.

## Step 2: Use a cloud database

We do not change the application yet: we leave it running locally and deploy a managed
database for it to talk to. For this first iteration we allow access over a public
endpoint (we tighten this in ch07-enterprise). We use a burstable tier so the database
costs little when idle.

You can deploy the database with the Azure Portal, Azure CLI, Bicep, Terraform, or Pulumi.
Here we use **GitHub Copilot** to author Bicep.

```
In folder bicep create Bicep template to deploy Azure Database for PostgreSQL Flexible Server.
- Use Burstable B1ms SKU and PostgreSQL version 16 or later
- Administrator login and password should be parameter and ensure @secure() annotation for password
- Add a firewall rule allowing my client IP, IP should be parameter
- Use location that is derived from resource group location
- As name must be unique add some unique string with full resource group ID as seed
- Create main.bicep as well as example bicepparam file
- Check correct syntax at #fetch https://learn.microsoft.com/en-us/azure/templates/microsoft.dbforpostgresql/flexibleservers?pivots=deployment-language-bicep
- Write simple README.md to describe how to deploy to your resource group and reference parameters file
```

Deploy it:

```powershell
az deployment group create --resource-group rg-userNNN --template-file bicep/main.bicep --parameters bicep/main.bicepparam
```

Now move the data. The catalog is small, so the simplest route is to let the application
create the schema and re-import the seed data:

1. Point the application at the new database using the `CATALOG_DATABASE_*` environment
   variables documented in [`java/README.md`](../../java/README.md). The managed server
   requires TLS, so set `CATALOG_DATABASE_SSL_MODE` accordingly.
2. Leave `CATALOG_STARTUP_IMPORT_ENABLED=true` so the app applies its migration and
   imports `data/catalog.json` on startup.
3. Start the app and confirm the catalog page lists all 198 figures across 20 categories.

If you would rather move the existing rows, export and restore instead — `pg_dump` and
`pg_restore`. Ask Copilot for the exact command line.

> Environment variables override `application.properties`. If you previously exported a
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
- This is a Spring Boot app currently run with `./mvnw spring-boot:run`; package to a jar and run it
- We are building for Linux
- Use a multi-stage Dockerfile so we build with the JDK image and run on the smaller JRE image
- Place the Dockerfile in the java/ folder, so all paths inside are relative to it
- Add example docker CLI commands to the README showing how to build the image and run it with the data folder mounted as a volume and the database connection supplied as environment variables
```

Build and run it locally, and confirm you get the same catalog page as before.

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
cd java
$registry = "yourregistryname"
az acr build --registry $registry --image lego-catalog/app:latest .
```

## Step 5: Let Azure services reach the database

For simplicity we deploy the application without VNet integration, so there is no
predictable outbound IP to whitelist. Temporarily enable access from Azure services.

```
Extend main.bicep to enable access from Azure services on the PostgreSQL Flexible Server
firewall — the rule that allows Azure-internal traffic without a specific client IP.
```

Note: in ch07-enterprise you replace this with Private Endpoints and remove public access
entirely.

## Step 6: Deploy to Azure Container Apps

Extend the Bicep template to deploy the container, referencing the database and the
registry:

```
Modify main.bicep to deploy application into Azure Container Apps.
- Make sure to deploy ACA environment with workload profile (v2) and use consumption for our app (note consumption profile has no minimum or maximum count settings).
- App will use environment variables for the database connection (CATALOG_DATABASE_HOST, CATALOG_DATABASE_NAME, CATALOG_DATABASE_USERNAME, CATALOG_DATABASE_PASSWORD, CATALOG_DATABASE_SSL_MODE); the password must come from a Container Apps secret
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

**Challenge:** [ch01-A · Java](../../challenges/ch01-A-java.md) ·
**.NET walkthrough:** [ch01-A · .NET](./dotnet.md) ·
**Next solution:** [ch02](../ch02/README.md)
