# OctoSupply Source Code

This directory contains the OctoSupply application source code, a full-stack supply chain management platform with multiple API language implementations and a shared React frontend. The source represents a production-quality demonstration application for cat tech products and serves as the foundation for this Hackathon.

## Directory Structure

### `/api-ts`
Express.js TypeScript backend API server (port **3000**)
- RESTful routes for products, orders, suppliers, branches, deliveries, and inventory
- SQLite database with migrations and seed data
- Comprehensive test coverage with Vitest
- TypeScript type definitions and validation

### `/api-cs`
ASP.NET Core .NET 10 backend API server (port **3000**)
- Port of the TypeScript API using C# records, repositories, and controllers
- Microsoft.Data.Sqlite with shared migration SQL
- Swashbuckle OpenAPI/Swagger documentation

### `/api-cs-tests`
C# test project for the .NET API
- xUnit-based tests for repository and API behavior
- Runs via `make test-cs`
- References `/api-cs` as the system under test

### `/api-py`
FastAPI backend API server (port **3000**)
- Port of the TypeScript API using Pydantic models, async repositories, and APIRouters
- aiosqlite with shared migration SQL
- FastAPI built-in OpenAPI/Swagger documentation

### `/api-java`
Spring Boot 3 backend API server (port **3000**)
- Port of the TypeScript API using Java records, JdbcTemplate repositories, and @RestControllers
- sqlite-jdbc with shared migration SQL
- SpringDoc OpenAPI documentation

### `/database`
Shared database schema — used by all API variants
- `migrations/` — SQL migration files applied in order at startup
- `seed/` — SQL seed data files for initial data population

### `/frontend`
React 18 TypeScript frontend application (port **5137**)
- Vite build tool for fast development and optimized production builds
- Tailwind CSS for styling
- Configurable API URL via `VITE_API_URL` environment variable (targets any API variant)

### `/docs`
Architecture and development documentation
- System architecture overview
- Database design and SQLite integration
- Build and deployment procedures

### `Makefile`
Cross-platform build automation supporting all language variants.

## Quick Start

```bash
# In the dev container, dependencies are installed during creation.

# Outside the dev container, install dependencies manually.
make install

# Start with TypeScript API (default, port 3000)
make dev

# Start with a specific API variant
make dev-ts            # TypeScript API (port 3000) + frontend
make dev-cs            # C# API       (port 3000) + frontend
make dev-py            # Python API   (port 3000) + frontend
make dev-java          # Java API     (port 3000) + frontend

# Start API only (no frontend)
make dev-api-ts
make dev-api-cs
make dev-api-py
make dev-api-java

# Install dependencies for a specific variant
make install-ts
make install-cs
make install-py
make install-java

# Build
make build-ts
make build-cs
make build-py
make build-java

# Test
make test-ts
make test-cs
make test-py
make test-java
```

## API Variants — Port Reference

| Variant    | Port | Framework             | Language   |
|------------|------|-----------------------|------------|
| TypeScript | 3000 | Express.js            | TypeScript |
| C#         | 3000 | ASP.NET Core .NET 10  | C#         |
| Python     | 3000 | FastAPI               | Python     |
| Java       | 3000 | Spring Boot 3         | Java       |
| Frontend   | 5137 | React 18 + Vite       | TypeScript |

All API variants expose the same REST endpoints and connect to a SQLite database at `./data/app.db` by default. Override with the `DB_FILE` environment variable.

Swagger/OpenAPI docs are available at `/api-docs` for each running API.

## Technology Stack

- **TypeScript API**: Node.js, Express.js, better-sqlite3
- **C# API**: .NET 10, ASP.NET Core, Microsoft.Data.Sqlite, Swashbuckle
- **Python API**: Python 3.11+, FastAPI, aiosqlite, Pydantic v2
- **Java API**: Java 21, Spring Boot 3, sqlite-jdbc, SpringDoc OpenAPI
- **Frontend**: React 18, Vite, Tailwind CSS, Playwright (E2E)
- **Database**: SQLite (shared schema in `/database`)
