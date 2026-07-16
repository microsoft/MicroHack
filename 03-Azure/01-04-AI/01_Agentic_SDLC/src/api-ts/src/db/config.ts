/**
 * Database configuration settings
 */

export const DB_CONFIG = {
  // Database file path - defaults to './data/app.db' but can be overridden by environment
  DB_FILE: process.env.DB_FILE || './data/app.db',

  // Database engine - currently supports SQLite
  DB_ENGINE: process.env.DB_ENGINE || 'sqlite',

  // Enable WAL mode for better concurrency
  ENABLE_WAL: process.env.DB_ENABLE_WAL !== 'false',

  // Connection timeout in milliseconds
  TIMEOUT: parseInt(process.env.DB_TIMEOUT || '30000'),

  // Enable foreign key constraints
  FOREIGN_KEYS: process.env.DB_FOREIGN_KEYS !== 'false',
};

// Test database configuration for unit tests
export const TEST_DB_CONFIG = {
  ...DB_CONFIG,
  DB_FILE: ':memory:', // Use in-memory database for tests
};
