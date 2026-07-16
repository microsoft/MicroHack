---
description: "Guidance for editing and reviewing database schema changes in the API."
applyTo: "src/database/migrations/**, src/database/seed/**, src/api-ts/src/db/**"
---
# Database & Schema Review Guidance
Specialized guidance for SQLite schema evolution, migrations, and seed strategy.

## Migration Principles
- Immutable historical migrations: never modify existing files—add a new sequential file.
- Each migration file must be idempotent or guarded (e.g., `IF NOT EXISTS`) where feasible.
- Provide matching DOWN/rollback strategy if environment supports manual reversal (comment rationale if impossible).

## Schema Design Checklist
1. Foreign keys defined with ON DELETE / ON UPDATE behavior explicitly (avoid silent cascades unless intended).
2. Indexes on: foreign key columns, high-selectivity WHERE predicates, and composite indexes for frequent multi-column filters.
3. Use CHECK constraints for domain invariants (non-negative quantities, valid enum sets) instead of only application code.
4. Avoid over-normalization that complicates queries without clear benefit.
5. Prefer INTEGER primary keys (auto-increment) unless natural key is stable & required.

## Performance & Optimization
- Evaluate query plans for slow endpoints (add covering indexes as needed).
- Consider partial indexes only if table sizes grow significantly; otherwise keep simple.

## Seeding Guidelines
- Deterministic: ensure seeds produce same IDs each run (explicit INSERT IDs) when referenced.
- Keep seed data minimal but illustrative; large sample volumes belong in fixtures.
- Update seeds when adding NOT NULL columns without defaults; ensure referential order.

## Review Red Flags
- Dropping and recreating tables for simple column additions (prefer ALTER when supported semantics suffice).
- Adding wide TEXT columns without need; consider normalization or constraints.
- Missing transaction around multi-statement data migrations altering existing rows.

## Testing
- Use in-memory DB for unit tests; ensure migrations run before repository tests.

## Example Feedback Style
"Migration 005 adds `order_status` but seeds not updated; existing seed inserts will violate NOT NULL. Add default or modify seed file."