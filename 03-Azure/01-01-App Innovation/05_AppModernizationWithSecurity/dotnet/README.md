# Lego Catalog — .NET / SQL Server baseline

This is the legacy application you are modernizing: a .NET 8 Blazor Server monolith backed
by SQL Server 2022 Express, both installed on the same Windows VM.

It deliberately ships **no Dockerfile and no Azure infrastructure**. Creating those is your
job in [Challenge 1](../challenges/ch01.md).

## Prerequisites

- .NET SDK 8.0
- SQL Server 2022 Express, or any SQL Server 2022 instance
- The catalog data in `data/catalog.json` and `data/images/`

All of this is preinstalled on the workshop VM.

## Configuration

Environment variables override the non-secret local defaults in `appsettings.json`.

| Variable | Required | Purpose |
| --- | --- | --- |
| `CATALOG_DATABASE_HOST` | No | SQL Server host or named instance; defaults to `.\SQLEXPRESS` |
| `CATALOG_DATABASE_PORT` | No | TCP port, when the host is not a named instance |
| `CATALOG_DATABASE_NAME` | No | Database name; defaults to `LegoCatalog` |
| `CATALOG_DATABASE_USERNAME` | With password | SQL login; omit both to use Windows integrated security |
| `CATALOG_DATABASE_PASSWORD` | With username | SQL login secret — supply it outside source control |
| `CATALOG_IMAGES_PATH` | No | Directory holding the figure images |
| `CATALOG_SEED_PATH` | No | Path to `catalog.json` |
| `CATALOG_STARTUP_IMPORT_ENABLED` | No | `true` by default; imports the seed data on startup |
| `PERFTEST_API_KEY` | Yes | Key required by `GET /perftest/catalog` |
| `PERFTEST_WORK_FACTOR` | No | Integer 1–25; defaults to `10` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | No | OTLP endpoint; telemetry is only exported when this is set |
| `OTEL_SERVICE_VERSION` | Yes | Version identity of what is running |
| `DEPLOYMENT_ENVIRONMENT` | Yes | Use `lab` |
| `CONTAINER_APP_REVISION` | Yes | Revision identity; use a local label during development |

The three telemetry identity variables have no defaults and the app will refuse to start
without them — that is intentional, so a running instance can always tell you which build
it is. When you containerize in Challenge 1, remember to set them in the Container App.

Never commit a database password or the performance API key.

## Run it

Create the database, grant your login permission to migrate and read/write, then from
`dotnet/`:

```powershell
$env:PERFTEST_API_KEY = '<pick-a-local-key>'
$env:CATALOG_SEED_PATH = (Resolve-Path ..\data\catalog.json)
$env:CATALOG_IMAGES_PATH = (Resolve-Path ..\data\images)
$env:DEPLOYMENT_ENVIRONMENT = 'lab'
$env:OTEL_SERVICE_VERSION = (git rev-parse HEAD)
$env:CONTAINER_APP_REVISION = 'local-vm'
dotnet run --project src\LegoCatalog.App\LegoCatalog.App.csproj
```

The app applies its EF Core migration, imports any seed records it does not already have
in one transaction, and listens on the URL Kestrel prints — usually
<http://localhost:5000>.

## Routes

| Route | Behavior |
| --- | --- |
| `GET /` | Catalog list; `search` matches on name, `category` accepts a slug or display name |
| `GET /figure/{id}` | Detail page, or 404 |
| `GET /images/{filename}` | PNG bytes, or 404; path traversal is rejected |
| `GET /import` | Upload form |
| `POST /import` | Validates the uploaded document and inserts new figures in a transaction |
| `GET /healthz` | Liveness — is the process up |
| `GET /readyz` | Readiness — SQL connectivity plus startup migration/import state |
| `GET /perftest/catalog` | Bounded database work behind an `x-api-key` header, for load testing |

`/healthz` and `/readyz` are what you wire into the Container App probes in Challenge 1;
`/perftest/catalog` is what you hammer in [Challenge 2](../challenges/ch02.md).

## Test

```powershell
dotnet restore LegoCatalog.sln
dotnet test LegoCatalog.sln
```

## OpenTelemetry

Telemetry is exported only when `OTEL_EXPORTER_OTLP_ENDPOINT` is set. The app emits
standard ASP.NET Core, HTTP client, SQL Client, and .NET runtime instrumentation, plus its
own `catalog.import`, `catalog.query`, and `catalog.performance` spans with matching
metrics and structured logs. It identifies itself as `service.name=mh-catalog-dotnet` in
namespace `app-innovation`.

You point that endpoint at a collector in [Challenge 4](../challenges/ch04.md).

## Troubleshooting

- **`/healthz` OK but `/readyz` returns 503** — SQL Server is unreachable or the startup
  migration/import failed. Read the startup log.
- **Startup import rejected the document** — it validates the whole file before writing
  anything, so one bad ID, filename, category slug, or empty field fails the batch.
- **Image returns 404** — the file must exist under `CATALOG_IMAGES_PATH` with an exact
  lowercase `<productId>.png` name.
- **App won't start at all** — most often a missing `PERFTEST_API_KEY`, an out-of-range
  work factor, or one of the three telemetry identity variables.
