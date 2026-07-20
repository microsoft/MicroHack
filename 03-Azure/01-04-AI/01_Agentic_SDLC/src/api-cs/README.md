# OctoSupply API (C#)

ASP.NET Core (.NET 10) port of the OctoSupply API.

## Run

```bash
dotnet restore
dotnet run
```

Default API URL: `http://localhost:3000`

## Environment

- `PORT` (default: `3000`)
- `DB_FILE` (default: `./data/app.db`)
- `API_CORS_ORIGINS` (comma-separated override; optional)

## Database

On startup, the API applies SQL migrations from:

- `../database/migrations/*.sql`

and seeds from:

- `../database/seed/*.sql`

## OpenAPI

- OpenAPI JSON: `http://localhost:3000/api-docs.json`

## Tests

Run C# tests from the `src/` directory:

```bash
make test-cs
```
