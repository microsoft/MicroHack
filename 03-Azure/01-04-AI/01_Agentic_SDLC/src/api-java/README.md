# OctoSupply API (Java)

Spring Boot 3 port of the OctoSupply API.

## Run

```bash
mvn spring-boot:run
```

Default API URL: `http://localhost:3000`

## Environment

- `PORT` (default: `3000`)
- `DB_FILE` (default: `./data/app.db`)
- `API_CORS_ORIGINS` (comma-separated override; optional)
- `DB_MIGRATIONS_DIR` (optional override for migrations directory)

## Database

On startup, the API applies SQL migrations from:

- `../database/migrations/*.sql`

and seeds from:

- `../database/seed/*.sql`

## OpenAPI

- OpenAPI JSON: `http://localhost:3000/api-docs.json`
- Swagger UI: `http://localhost:3000/api-docs`
