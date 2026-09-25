# ch01-A · .NET — solution artifacts

The finished files for the [.NET walkthrough](../dotnet.md). The `dotnet/` folder at the
repository root is deliberately left in its legacy state — it is the "before" you compare
against — so the versions you are meant to *produce* live here instead.

Paths under `app/` mirror `dotnet/`, so you can drop them straight in:

```bash
cp -R walkthrough/ch01-A/dotnet/app/. dotnet/
```

Copy them if you get stuck. Producing them yourself, with GitHub Copilot, is the exercise.

## What's here

| File | Step | What it does |
| --- | --- | --- |
| `app/src/LegoCatalog.App/LegoCatalog.App.csproj` | 1 | Target framework moved to `net10.0`, EF Core packages to 10.0.11 |
| `app/tests/LegoCatalog.App.Tests/LegoCatalog.App.Tests.csproj` | 1 | Same upgrade for the test project |
| `bicep/` | 2, 4, 5, 6 | SQL, ACR, firewall and Container Apps — see [`bicep/README.md`](./bicep/README.md) |
| `app/Dockerfile` | 3 | Multi-stage build; SDK image to compile, ASP.NET runtime image to run |
| `app/.dockerignore` | 3 | Keeps `bin/`, `obj/` and the test project out of the build context |

Only `app/` is meant to be copied over `dotnet/`. `bicep/` is deployed from where it sits.

## Step 1 — the framework upgrade

Two changes, in both project files:

- `<TargetFramework>net8.0</TargetFramework>` becomes `net10.0`.
- The `Microsoft.EntityFrameworkCore.*` and `Microsoft.AspNetCore.Mvc.Testing` packages
  move from `8.0.22` to `10.0.11`.

The explicit `Microsoft.AspNetCore.Components.Web` reference is **removed**: it ships as
part of the ASP.NET Core shared framework that `Microsoft.NET.Sdk.Web` already references,
so pinning a version only risks drift against the installed runtime.

The OpenTelemetry packages are already current and need no change.

```bash
dotnet build dotnet/LegoCatalog.sln    # clean, and the projects treat warnings as errors
dotnet test dotnet/LegoCatalog.sln
```

## Step 3 — the container

Build from the `dotnet/` folder, because every path in the Dockerfile is relative to it:

```bash
cd dotnet
docker build -t lego-catalog-app:local .
```

Kestrel listens on **8080** inside the container and the image runs as a non-root user.
The seed JSON and the product images are static content and are **not** baked into the
image — `CATALOG_SEED_PATH` and `CATALOG_IMAGES_PATH` default to `/data/catalog.json` and
`/data/images`, so mounting the repository `data/` folder at `/data` is all you need:

```bash
docker run -d --name lego-catalog -p 5000:8080 \
  -v "$(pwd)/../data:/data:ro" \
  -e CATALOG_DATABASE_HOST='<server>.database.windows.net' \
  -e CATALOG_DATABASE_NAME='LegoCatalog' \
  -e CATALOG_DATABASE_USERNAME='catalogadmin' \
  -e CATALOG_DATABASE_PASSWORD="$SQL_ADMIN_PASSWORD" \
  -e PERFTEST_API_KEY='<pick-a-local-key>' \
  -e DEPLOYMENT_ENVIRONMENT=lab \
  -e OTEL_SERVICE_VERSION="$(git rev-parse HEAD)" \
  -e CONTAINER_APP_REVISION='local-container' \
  lego-catalog-app:local

curl http://localhost:5000/readyz
```

In Azure you can drop `CONTAINER_APP_REVISION` — Container Apps injects it for you.

---

**Walkthrough:** [ch01-A · .NET](../dotnet.md) · **Infrastructure:**
[`bicep/`](./bicep/README.md)
