# OctoSupply API (Python)

FastAPI port of the OctoSupply API.

## Run

```bash
pip install -r requirements.txt
uvicorn main:app --reload --port 3000
```

Default API URL: `http://localhost:3000`

## Environment

- `PORT` (used by Makefile/uvicorn command, default `3000`)
- `DB_FILE` (default: `./data/app.db`)
- `API_CORS_ORIGINS` (comma-separated override; optional)
- `DB_MIGRATIONS_DIR` (optional override for migrations directory)

## Database

On startup, the API applies SQL migrations from:

- `../database/migrations/*.sql`

and seeds from:

- `../database/seed/*.sql`

## OpenAPI

- OpenAPI JSON: `http://localhost:3000/openapi.json`
- Swagger UI: `http://localhost:3000/docs`
