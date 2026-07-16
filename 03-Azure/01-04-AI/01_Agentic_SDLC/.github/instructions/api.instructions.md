---
description: "Guidance for editing and reviewing API code changes in the API."
applyTo: "src/api-ts/**, src/api-cs/**, src/api-py/**, src/api-java/**, src/database/migrations/**, src/database/seed/**"
---
# API Review Guidance
Focus on correctness, security, data integrity, and consistency in the API and SQLite repository layer. The same OctoCAT Supply API is implemented in four languages — TypeScript/Express (`src/api-ts`), C#/ASP.NET (`src/api-cs`), Python/FastAPI (`src/api-py`), and Java/Spring (`src/api-java`) — so apply this guidance to whichever stack the change targets.

## API Principles

- Keep controllers (routes) thin: validation + orchestration; move logic to repositories/services.
- Use parameterized SQL always; never build raw query strings with user input.
- Return proper HTTP status codes via shared error classes (NotFound, Validation, Conflict).
- Preserve consistent naming: idiomatic casing in code models (e.g., camelCase in TypeScript) mapped reliably to snake_case SQL columns.
- Keep the API surface documented (Swagger/OpenAPI). Update the spec when adding/modifying endpoints.

## Review Checklist
1. Input validation: basic type/shape checks before hitting DB; reject ambiguous/partial updates.
2. Error propagation: repository throws domain errors -> middleware -> correct status.
3. Transactions: group multi-table writes that must succeed or fail together.
4. Performance: watch for N+1 loops over rows triggering per-row SELECT; prefer JOIN queries.
5. Migrations: every schema change accompanied by new sequential SQL file; no edits to prior migrations.
6. Seed adjustments when adding required NOT NULL columns or reference data.
7. Swagger updated: new routes, models, examples, response codes.

## Data Integrity
- Enforce foreign keys (ensure config keeps them ON) & add indexes for new FK columns.
- Use CHECK constraints or application validation for domain rules (e.g., quantity >= 0).

## Testing Guidance
- Add unit tests for new repository methods (happy path + error cases) using in-memory DB.
- For route additions, integration test hitting the real app (e.g., supertest for Express, WebApplicationFactory for ASP.NET, TestClient for FastAPI, MockMvc for Spring) verifying status + response shape.

## Security Considerations
- Sanitize / constrain pagination (max limits) to avoid table scans.
- Do not leak internal error stacks in production responses.
- CORS: restrict origins if production hardened later.

## Example Feedback Style
"`ordersRepo.findWithDetails()` issues one SELECT per order detail (N+1). Consider a single JOIN query returning flattened rows then post-process."