# ch01-A · Java — solution artifacts

Finished application overlays for the [Java walkthrough](../java.md). The repository's root
`java/` remains the Java 17 / Spring Boot 3.5.16 baseline. No VM changes are needed,
and Challenge 0 is not a prerequisite for this local walkthrough.

Paths under `app/` mirror `java/`. Apply them **to a separate working copy**, not to
the baseline checkout:

```bash
# Run from the repository root. Choose an absolute, private working directory.
export WORKSHOP="$HOME/microhack-java-workshop"
mkdir -p "$WORKSHOP/java" "$WORKSHOP/data"
rsync -a --exclude target java/ "$WORKSHOP/java/"
rsync -a data/ "$WORKSHOP/data/"
cp -R walkthrough/ch01-A/java/app/. "$WORKSHOP/java/"
```

Only `app/` is an application overlay. Infrastructure remains in [`bicep/`](./bicep/README.md).

## Step 1 — Java 21 and Spring Boot 4

| Overlay | Change |
| --- | --- |
| `app/pom.xml` | Java 21, Spring Boot **4.0.8**, modular MVC/Flyway/test starters; Boot-managed PostgreSQL JDBC and Testcontainers |
| `app/src/main/.../TomcatPathConfiguration.java` | Boot 4 Tomcat package relocation; existing path validation retained |
| `app/src/main/.../CatalogDocumentParser.java` | Jackson 3 immutable `JsonMapper`, streaming APIs and exception handling; strict document validation retained |
| `app/src/test/...` | Jackson 3, relocated MVC/REST test support and Testcontainers 2 imports |
| `app/Dockerfile`, `app/.dockerignore` | Multi-stage Linux JDK 21 build / JRE 21 runtime; non-root user and external data |

This is a real Boot 4 upgrade; the Java-21-only / Boot-3.5 fallback was **not** needed.
Routes, templates, Flyway migration and database schema are unchanged. Existing
OpenTelemetry/logging versions are retained to preserve the telemetry contract.

### Restore the existing suite's shared fixtures

The baseline tests still reference `workshop/contracts/` and
`tests/acceptance/fixtures/`, which were removed from this workshop checkout. Restore
only those six JSON files into the working copy, unchanged from the recorded repository
revision; do not invent replacement vectors or disable the tests:

```bash
git archive 4dd5788ccf24a76c15fa43a2571efa0bb7fc5bf0 \
  workshop/contracts/identity-vectors.json \
  workshop/contracts/normalization-vectors.json \
  workshop/contracts/text-validation-vectors.json \
  tests/acceptance/fixtures \
  | tar -x -C "$WORKSHOP"
```

If that historical revision is unavailable in your clone, obtain those exact fixtures
from the facilitator before running the complete suite. `ConformanceVectorTest`
walks upward to find `workshop/contracts`; mounting just `java/` is insufficient.

### Test with JDK 21

With JDK 21, Docker and `unzip` available:

```bash
cd "$WORKSHOP/java"
./mvnw test
./mvnw package
```

On a machine with an older host JDK, use the Maven/JDK 21 image instead:

```bash
mkdir -p "$WORKSHOP/runtime-files"
docker run --rm --name mh-ch01-java-maven-test \
  -v "$WORKSHOP:/workspace" \
  -v mh-ch01-java-maven-cache:/root/.m2 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal \
  -e TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock \
  -e JAVA_TOOL_OPTIONS=-Djava.io.tmpdir=/workspace/runtime-files \
  -w /workspace/java \
  maven:3.9-eclipse-temurin-21 mvn -B -ntp verify
```

The socket and host override are for **Docker Desktop**: Testcontainers creates the
PostgreSQL container in the host daemon, whose published ports must be reached through
`host.docker.internal`, not the Maven container's `localhost`. Native Linux may need
`--add-host=host.docker.internal:host-gateway`.

The Maven image already contains Maven. Use `mvn` inside it: its lack of `unzip`
causes the baseline wrapper to download a tarball while validating the ZIP checksum.
The wrapper's ZIP checksum is correct; do not remove checksum validation.

### Start the source application locally

Create a private environment file **outside the repository**, for example
`"$WORKSHOP/local.env"`, with mode `600`. Supply real random local-only values for
the three secret placeholders below; use the same password for PostgreSQL and JDBC.

```dotenv
POSTGRES_DB=catalog
POSTGRES_USER=catalog
POSTGRES_PASSWORD=<local-database-password>
CATALOG_DATABASE_HOST=mh-ch01-java-postgres
CATALOG_DATABASE_PORT=5432
CATALOG_DATABASE_NAME=catalog
CATALOG_DATABASE_USERNAME=catalog
CATALOG_DATABASE_PASSWORD=<same-local-database-password>
CATALOG_DATABASE_SSL_MODE=disable
CATALOG_IMAGES_PATH=/data/images
CATALOG_SEED_PATH=/data/catalog.json
CATALOG_STARTUP_IMPORT_ENABLED=true
PERFTEST_API_KEY=<random-local-api-key>
PERFTEST_WORK_FACTOR=1
OTEL_SERVICE_VERSION=ch01-java21-boot4.0.8
DEPLOYMENT_ENVIRONMENT=lab
CONTAINER_APP_REVISION=ch01-local
OTEL_SDK_DISABLED=true
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
```

The existing application validates `OTEL_EXPORTER_OTLP_ENDPOINT` even when the SDK is
disabled, so keep that local placeholder endpoint. No collector is required when
`OTEL_SDK_DISABLED=true`.

```bash
chmod 600 "$WORKSHOP/local.env"
docker network create mh-ch01-java-net
docker run -d --name mh-ch01-java-postgres --network mh-ch01-java-net \
  --env-file "$WORKSHOP/local.env" \
  -p 127.0.0.1:55432:5432 \
  -v mh-ch01-java-pgdata:/var/lib/postgresql postgres:18

docker run -d --name mh-ch01-java-source --network mh-ch01-java-net \
  --env-file "$WORKSHOP/local.env" -p 127.0.0.1:8081:8080 \
  -v "$WORKSHOP:/workspace" -v "$WORKSHOP/data:/data:ro" \
  -v mh-ch01-java-maven-cache:/root/.m2 \
  -e JAVA_TOOL_OPTIONS=-Djava.io.tmpdir=/workspace/runtime-files \
  -w /workspace/java \
  maven:3.9-eclipse-temurin-21 mvn -B -ntp spring-boot:run

curl --fail --retry 15 --retry-delay 2 --retry-all-errors http://localhost:8081/readyz
```

Open <http://localhost:8081/>. Flyway creates the unchanged schema and startup import
loads the mounted seed. These named resources are separate from any existing workshop
containers; do not remove or replace other people's resources.

## Step 3 — build and run the container

Build with `java/` as the context, not the repository root:

```bash
docker build -t mh-ch01-java:boot4-local "$WORKSHOP/java"
docker run -d --name mh-ch01-java-app --network mh-ch01-java-net \
  --env-file "$WORKSHOP/local.env" -p 127.0.0.1:8080:8080 \
  -v "$WORKSHOP/data:/data:ro" mh-ch01-java:boot4-local

curl --fail --retry 15 --retry-delay 2 --retry-all-errors http://localhost:8080/readyz
curl --fail http://localhost:8080/healthz
docker exec mh-ch01-java-postgres psql -U catalog -d catalog -Atc \
  'SELECT count(*) FROM figures; SELECT count(*) FROM categories;'
```

The local build uses the Docker host's native architecture (ARM64 in this walkthrough).
Use `--platform linux/amd64` when you specifically need an AMD64 target. ACR builds
the Azure deployment image on Linux AMD64.
The build skips tests because the full suite needs Docker and repository-level fixtures;
run the `verify` command above **before** building.

The runtime listens on **8080**, runs as **UID/GID 10001**, and contains only the
application JAR plus the JRE. JSON and photographs are not baked into the image:
the `/data` bind mount is read-only. The Dockerfile uses an ordinary `RUN` so the
walkthrough's `az acr build` works with ACR Tasks' default builder; it does not require
a BuildKit-only cache mount.

For walkthrough step 2, make a **separate private env file** with the managed
PostgreSQL host, database, credentials and `CATALOG_DATABASE_SSL_MODE=require`
(or stricter verified TLS). Then recreate only the relevant application container
with that file. `localhost` from an application container is not the host database.
No Azure resource operations are performed by these instructions.

## Verified result — 9 September 2026

- Temurin **21.0.12**, Maven **3.9.16**, Spring Boot **4.0.8**; PostgreSQL **18.6**.
- `mvn -B -ntp verify`: **34 tests, zero failures/errors/skips**, including all six
  PostgreSQL Testcontainers integration tests.
- Both source-run port **8081** and runtime-image port **8080**: **198 figures and
  20 categories**; name search, category slug/display-name filtering, figure detail,
  PNG bytes identical to the mounted original, `/healthz` and `/readyz` all passed.
- Runtime image verified as `linux/arm64`, UID/GID `10001:10001`; `/data` read-only.
- The Maven application also ran locally against managed PostgreSQL **16.15**:
  **198 figures / 20 categories**, working catalog routes, and TLS 1.3 database sessions.
- ACR Tasks built the portable Dockerfile for Linux AMD64 and pushed
  `lego-catalog/app:latest`; no local image push substituted for `az acr build`.
- The root `java/` baseline remained unchanged.

Local credentials and execution logs belong in the private working directory, not in
this solution folder. See [the Bicep instructions](./bicep/README.md) for the Azure
deployment, storage upload, image-pull identity and scale-to-zero steps.

### Azure exit criteria

The completed deployment in `rg-user001` used PostgreSQL B1ms and a Container App
with 1 CPU / 2 GiB, read-only Azure Files mounts and managed-identity image pull.
All 198 catalog IDs matched the seed; the page exposed 20 categories. Search,
category slug/display-name filtering, detail, photograph bytes, `/healthz` and
`/readyz` passed.

At **21:33:32 UTC**, the active revision naturally reached **zero replicas**.
After a second zero-replica observation, the next request returned ready with
**HTTP 200 in 29.74 seconds**; all 198 figures remained available. Scaling stayed
configured at **0-3**, without forcing it down for the demonstration.

The dated deployment URL and technical decisions are recorded in
[`docs/ImplementationLog.md`](../../../docs/ImplementationLog.md). Azure resources
remain available for the next challenge; temporary local containers were stopped.
