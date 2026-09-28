# Lego Catalog — Java / PostgreSQL baseline

This is the legacy application you are modernizing: a deliberately monolithic Spring Boot 3
application on Java 17, backed by PostgreSQL, both installed on the same Windows VM. It
uses Spring MVC, Thymeleaf, JPA, and a Flyway migration.

It deliberately ships **no Dockerfile and no Azure infrastructure**. Creating those is your
job in [Challenge 1](../challenges/ch01.md).

## Prerequisites

- Microsoft OpenJDK 17
- PostgreSQL 18 — a local service, or Docker if you prefer a container
- The catalog data in `data/catalog.json` and `data/images/`

All of this is preinstalled on the workshop VM, where PostgreSQL runs as the
`postgresql-x64-18` Windows service. The Maven Wrapper (`./mvnw`) downloads Maven for you.

Working on your own Mac instead? The JDK cask needs an interactive `sudo`, so the tarball
is easier:

```bash
mkdir -p ~/.local/jdk && cd ~/.local/jdk
curl -sSL -o msjdk17.tar.gz "https://aka.ms/download-jdk/microsoft-jdk-17-macos-aarch64.tar.gz"
tar xzf msjdk17.tar.gz
export JAVA_HOME=~/.local/jdk/$(ls ~/.local/jdk | grep jdk-17)/Contents/Home
```

Check `java -version` before building. An older JDK earlier on your `PATH` is the most
common cause of a confusing Maven failure here.

## Configuration

Supply every secret outside source control.

| Variable | Purpose |
| --- | --- |
| `CATALOG_DATABASE_HOST` | PostgreSQL host |
| `CATALOG_DATABASE_PORT` | Optional port; defaults to `5432` |
| `CATALOG_DATABASE_NAME` | Database name |
| `CATALOG_DATABASE_USERNAME` | Database application identity |
| `CATALOG_DATABASE_PASSWORD` | Database password |
| `CATALOG_DATABASE_SSL_MODE` | JDBC SSL mode; use `disable` only locally, `require` against Azure |
| `CATALOG_IMAGES_PATH` | Directory holding the figure images |
| `CATALOG_SEED_PATH` | Path to `catalog.json` |
| `CATALOG_STARTUP_IMPORT_ENABLED` | `true` or `false`; defaults to `true` |
| `PERFTEST_API_KEY` | Key required by `GET /perftest/catalog` |
| `PERFTEST_WORK_FACTOR` | Optional integer 1–25; defaults to `10` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLP endpoint; telemetry is only exported when this is set |
| `OTEL_SERVICE_VERSION` | Version identity of what is running |
| `DEPLOYMENT_ENVIRONMENT` | Use `lab` |
| `CONTAINER_APP_REVISION` | Revision identity; use a local label during development |

The telemetry identity variables have no defaults and the app will refuse to start without
them — that is intentional, so a running instance can always tell you which build it is.
When you containerize in Challenge 1, remember to set them in the Container App. The
standard `OTEL_*` variables also work for protocol, headers, TLS, sampling, and timeouts;
set `OTEL_SDK_DISABLED=true` when you deliberately run without a collector.

## Run it

On the workshop VM PostgreSQL is already there, so skip the `docker run`. On your own
machine:

```bash
docker run -d --name mh-java-postgres \
  -e POSTGRES_DB=catalog \
  -e POSTGRES_USER=catalog \
  -e POSTGRES_PASSWORD="<local-password>" \
  -p 5432:5432 postgres:18

export CATALOG_DATABASE_HOST=localhost
export CATALOG_DATABASE_PORT=5432
export CATALOG_DATABASE_NAME=catalog
export CATALOG_DATABASE_USERNAME=catalog
export CATALOG_DATABASE_PASSWORD="<local-password>"
export CATALOG_DATABASE_SSL_MODE=disable
export CATALOG_IMAGES_PATH="../data/images"
export CATALOG_SEED_PATH="../data/catalog.json"
export PERFTEST_API_KEY="<pick-a-local-key>"
export OTEL_SERVICE_VERSION="local"
export DEPLOYMENT_ENVIRONMENT=lab
export CONTAINER_APP_REVISION=local
export OTEL_SDK_DISABLED=true

./mvnw spring-boot:run
```

Flyway creates the schema and the startup import loads 198 figures across 20 categories.
Open <http://localhost:8080/>.

## Routes

| Route | Behavior |
| --- | --- |
| `GET /` | Catalog list; `search` matches on name, `category` accepts a slug or display name |
| `GET /figure/{id}` | Detail page, or 404 |
| `GET /images/{filename}` | PNG bytes, or 404; path traversal is rejected |
| `GET /import` | Upload form |
| `POST /import` | Validates the uploaded document and inserts new figures in a transaction |
| `GET /healthz` | Liveness — is the process up |
| `GET /readyz` | Readiness — database connectivity plus startup migration/import state |
| `GET /perftest/catalog` | Bounded database work behind an `x-api-key` header, for load testing |

`/healthz` and `/readyz` are what you wire into the Container App probes in Challenge 1;
`/perftest/catalog` is what you hammer in [Challenge 2](../challenges/ch02.md).

## Test and package

```bash
./mvnw test
./mvnw package
java -jar target/catalog-java-1.0.0.jar
```

## See how it behaves when the database goes away

Worth doing before Challenge 1, so the probe behavior in Container Apps makes sense:

```bash
docker stop mh-java-postgres
curl -i http://localhost:8080/healthz   # still 200 — the process is fine
curl -i http://localhost:8080/readyz    # 503 — the dependency is not
docker start mh-java-postgres
curl -i http://localhost:8080/readyz    # back to 200
```

## Troubleshooting

- **`/healthz` OK but `/readyz` returns 503** — PostgreSQL is unreachable, or Flyway/the
  startup import failed. Read the startup log.
- **Startup import rejected the document** — it validates the whole file before writing
  anything, so one bad ID, filename, category slug, or empty field fails the batch.
- **Image returns 404** — the file must exist under `CATALOG_IMAGES_PATH` with an exact
  lowercase `<productId>.png` name.
- **App won't start at all** — most often a missing `PERFTEST_API_KEY`, an out-of-range
  work factor, or one of the telemetry identity variables.
- **Maven fails immediately** — check `java -version` is 17.
