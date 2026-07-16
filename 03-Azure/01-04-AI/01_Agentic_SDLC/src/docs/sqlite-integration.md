# SQLite Database Integration

This document explains how to use the SQLite database integration in the OctoCAT Supply Chain Management API.

## Overview

The API has been migrated from in-memory data storage to a persistent SQLite database. This provides:

- **Data persistence** - Data survives server restarts
- **ACID transactions** - Reliable data consistency
- **Proper relationships** - Foreign key constraints between entities
- **Performance** - Indexed queries for better performance
- **Testing** - In-memory database for unit tests

## Database Structure

The database consists of the following tables:

- `suppliers` - Supplier information
- `headquarters` - Company headquarters data
- `branches` - Branch locations (linked to headquarters)
- `products` - Product catalog (linked to suppliers)
- `orders` - Customer orders (linked to branches)
- `order_details` - Order line items (linked to orders and products)
- `deliveries` - Delivery tracking (linked to suppliers)
- `order_detail_deliveries` - Junction table for order-delivery relationships
- `migrations` - Database schema version tracking

## Getting Started

### 1. Database Initialization

When you start the server for the first time, the database will be automatically initialized:

```bash
make dev
```

This will:

- Create the SQLite database file at `api/data/app.db`
- Run all pending migrations
- Seed the database with sample data (if empty)

### 2. Manual Database Management

You can also manage the database manually from the root directory:

```bash
# Initialize database with migrations and seed data
make db-init

# Run migrations only (no seeding)
make db-migrate

# Seed database only
make db-seed
```

Alternatively, if you're in the `api/` directory, you can use npm commands directly:

```bash
cd api
npm run db:init
npm run db:migrate
npm run db:seed
```

### 3. Database Location

The database file is stored at:

- **Development**: `api/data/app.db`
- **Testing**: In-memory (`:memory:`)

You can override the database location using the `DB_FILE` environment variable:

```bash
export DB_FILE=/path/to/your/database.db
```

## Repository Pattern

The API uses the Repository pattern to interact with the database:

### Using Repositories

```typescript
import { getSuppliersRepository } from './repositories/suppliersRepo';

const repo = await getSuppliersRepository();

// Get all suppliers
const suppliers = await repo.findAll();

// Get supplier by ID
const supplier = await repo.findById(1);

// Create new supplier
const newSupplier = await repo.create({
    name: 'New Supplier',
    description: 'Description',
    contactPerson: 'John Doe',
    email: 'john@example.com',
    phone: '555-1234'
});

// Update supplier
const updated = await repo.update(1, { name: 'Updated Name' });

// Delete supplier
await repo.delete(1);

// Search by name
const results = await repo.findByName('Tech');
```

### Repository Features

- **Type Safety** - Full TypeScript support
- **Error Handling** - Proper error types (NotFoundError, ValidationError, etc.)
- **SQL Injection Protection** - Parameterized queries
- **Automatic Mapping** - Converts between snake_case (database) and camelCase (JavaScript)

## Database Schema Management

### Migrations

Database schema changes are managed through migration files:

1. Create a new migration file: `api/sql/migrations/002_description.sql`
2. Add your SQL statements
3. Run migrations: `make db-migrate` (or `cd api && npm run db:migrate`)

Migration files are executed in order and tracked in the `migrations` table.

### Seed Data

Sample data is provided through seed files in `api/sql/seed/`:

- `001_suppliers.sql` - Supplier data
- `002_headquarters.sql` - Headquarters data
- `003_branches.sql` - Branch data
- `004_products.sql` - Product catalog

## Testing Strategy

### Unit Tests

Repositories are tested using mocked database connections:

```typescript
import { vi } from 'vitest';
import { SuppliersRepository } from '../repositories/suppliersRepo';

// Mock database
const mockDb = {
    run: vi.fn(),
    get: vi.fn(),
    all: vi.fn(),
    close: vi.fn()
};

// Test repository methods
const repo = new SuppliersRepository(mockDb);
```

### Integration Tests

For integration tests, use an in-memory database:

```typescript
import { getDatabase } from '../db/sqlite';

const db = await getDatabase(true); // true = test mode (in-memory)
```

## Configuration

Database configuration is managed in `api/src/db/config.ts`:

```typescript
export const DB_CONFIG = {
    DB_FILE: process.env.DB_FILE || './data/app.db',
    DB_ENGINE: process.env.DB_ENGINE || 'sqlite',
    ENABLE_WAL: process.env.DB_ENABLE_WAL !== 'false',
    TIMEOUT: parseInt(process.env.DB_TIMEOUT || '30000'),
    FOREIGN_KEYS: process.env.DB_FOREIGN_KEYS !== 'false'
};
```

### Environment Variables

- `DB_FILE` - Database file path (default: `./data/app.db`)
- `DB_ENGINE` - Database engine (default: `sqlite`)
- `DB_ENABLE_WAL` - Enable WAL mode (default: `true`)
- `DB_TIMEOUT` - Connection timeout in ms (default: `30000`)
- `DB_FOREIGN_KEYS` - Enable foreign key constraints (default: `true`)

## Error Handling

The system provides specialized error types:

- `DatabaseError` - General database errors
- `NotFoundError` - Entity not found (404)
- `ValidationError` - Invalid data (400)
- `ConflictError` - Constraint violations (409)

These errors are automatically handled by the Express error middleware and return appropriate HTTP status codes.

## Performance Considerations

The database includes several optimizations:

- **Indexes** - On foreign keys and frequently queried columns
- **WAL Mode** - Better concurrency for read/write operations
- **Connection Pooling** - Reuses database connections
- **Query Optimization** - Parameterized queries prevent SQL injection

## Backup and Recovery

Since SQLite stores data in a single file, backup is straightforward:

```bash
# Backup database
cp api/data/app.db api/data/app-backup-$(date +%Y%m%d).db

# Restore from backup
cp api/data/app-backup-20231225.db api/data/app.db
```

For production deployments, consider regular automated backups.

## Troubleshooting

### Common Issues

1. **Database locked**: Usually caused by long-running transactions or unclosed connections
   - Solution: Ensure all database operations are properly awaited and connections are closed

2. **Foreign key constraint errors**: Trying to reference non-existent records
   - Solution: Ensure referenced records exist before creating relationships

3. **Migration errors**: SQL syntax errors or conflicting schema changes
   - Solution: Check migration file syntax and ensure compatibility with existing schema

### Debug Mode

Enable verbose SQLite logging:

```bash
NODE_ENV=development make dev
```

This will show all SQL queries being executed.

## Next Steps

The current implementation includes:

- ✅ Complete SQLite infrastructure
- ✅ Suppliers repository and routes
- ✅ Migration and seeding system
- ✅ Unit tests with mocking

Still to implement:

- [ ] Repositories for remaining entities (products, orders, etc.)
- [ ] Route migration for remaining endpoints
- [ ] Integration tests
- [ ] Docker configuration updates
- [ ] Production deployment considerations
