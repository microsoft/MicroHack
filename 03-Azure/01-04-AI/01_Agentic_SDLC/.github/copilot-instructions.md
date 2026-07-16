# OctoCAT Supply Chain Management Application – General Copilot Instructions

These are repository-wide guidelines. Path‑scoped files in `.github/instructions/*.instructions.md` provide focused guidance for specific areas (frontend, API, database).

## High-Level Architecture
Multi-language monorepo under `src/` implementing the OctoCAT Supply Chain app. It ships FOUR interchangeable implementations of the same OctoCAT Supply API plus a shared UI and database:
- `src/api-ts` Express REST API in TypeScript (SQLite persistence, repository pattern, Swagger docs)
- `src/api-cs` ASP.NET REST API in C#
- `src/api-py` FastAPI REST API in Python
- `src/api-java` Spring Boot REST API in Java
- `src/frontend` React + Vite + Tailwind UI (shared across all API variants)
- `src/database` SQLite schema — `src/database/migrations/` and `src/database/seed/`
- `src/Makefile` orchestrates install/build/test/dev across the languages

Refer to `src/docs/architecture.md` and `src/docs/sqlite-integration.md` for deeper details. Avoid restating them in reviews and link instead.

## General Review Guidance
When generating suggestions:
1. Prefer incremental, minimal diffs; preserve existing style and naming.
2. Surface security, correctness, and data integrity issues before micro-optimizations.
3. Encourage type safety (no `any` unless justified). Suggest adding/refining model or DTO types when gaps appear.
4. Reduce duplication: when the same logic appears in multiple places, suggest extracting it into a shared utility or repository method.
5. Ensure error handling uses existing custom error types where appropriate (e.g., NotFound, Validation, Conflict) and propagates consistent HTTP status codes via middleware.
6. Encourage tests: request unit tests for new repository logic and component tests (or at least React Testing Library coverage) for critical UI paths.
7. For performance concerns, highlight N+1 query patterns, unnecessary data loading, or large bundle additions.
8. Prefer environment variable driven configuration; avoid hard‑coded paths/secrets.

## Monorepo Workflow
- Build and test via the `src/Makefile` (run targets from `src/`): `make build` / `make test` / `make dev` cover all variants, and per-language targets like `make build-ts`, `make test-ts`, `make dev-ts` scope to one implementation.
- Install dependencies with the install targets: `make install` (everything) or per-language `make install-ts`, `make install-cs`, `make install-py`, `make install-java`, `make install-frontend`.
- Keep PRs scoped: code + tests + docs (architecture or build notes) when behavior changes.
- Update related instruction files if new folders or architectural slices are introduced.

## Do Not Repeat
Do not inline full API route or component files in review feedback unless absolutely necessary: quote only the lines requiring change. Summarize low‑impact nits.

## Escalation Order for Suggestions
1. Security / data integrity
2. Logical / functional correctness
3. Performance / scalability
4. Maintainability / duplication
5. Readability / consistency
6. Style / minor formatting

## Tone & Feedback Style
Be concise, actionable, and cite a rationale ("because" clause) for non-trivial recommendations. Offer one preferred solution; optionally a lightweight alternative.

---
If new subsystems are added (e.g., `mobile/`, `worker/`), create a new `*.instructions.md` with `applyTo` globs instead of bloating this file.