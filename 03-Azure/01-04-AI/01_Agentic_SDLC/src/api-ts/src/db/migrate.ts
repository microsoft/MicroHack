/**
 * Database migration runner
 */

import fs from 'fs';
import path from 'path';
import { getDatabase, DatabaseConnection } from './sqlite';

interface Migration {
  version: number;
  filename: string;
  sql: string;
}

export class MigrationRunner {
  private db: DatabaseConnection;
  private migrationsDir: string;

  constructor(db: DatabaseConnection, migrationsDir: string = '../database/migrations') {
    this.db = db;
    this.migrationsDir = path.resolve(migrationsDir);
  }

  /**
   * Initialize the migrations table
   */
  private async initializeMigrationsTable(): Promise<void> {
    const sql = `
            CREATE TABLE IF NOT EXISTS migrations (
                version INTEGER PRIMARY KEY,
                filename TEXT NOT NULL,
                applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );
        `;

    await this.db.run(sql);
  }

  /**
   * Get all migration files from the migrations directory
   */
  private getMigrationFiles(): Migration[] {
    if (!fs.existsSync(this.migrationsDir)) {
      throw new Error(`Migrations directory not found: ${this.migrationsDir}`);
    }

    const files = fs
      .readdirSync(this.migrationsDir)
      .filter((file) => file.endsWith('.sql'))
      .sort();

    return files.map((filename) => {
      const version = this.extractVersionFromFilename(filename);
      const filePath = path.join(this.migrationsDir, filename);
      const sql = fs.readFileSync(filePath, 'utf-8');

      return {
        version,
        filename,
        sql,
      };
    });
  }

  /**
   * Extract version number from migration filename
   * Expected format: 001_description.sql
   */
  private extractVersionFromFilename(filename: string): number {
    const match = filename.match(/^(\d+)_/);
    if (!match) {
      throw new Error(
        `Invalid migration filename format: ${filename}. Expected format: 001_description.sql`,
      );
    }
    return parseInt(match[1], 10);
  }

  /**
   * Get applied migrations from the database
   */
  private async getAppliedMigrations(): Promise<number[]> {
    const rows = await this.db.all<{ version: number }>(
      'SELECT version FROM migrations ORDER BY version',
    );
    return rows.map((row) => row.version);
  }

  /**
   * Apply a single migration
   */
  private async applyMigration(migration: Migration): Promise<void> {
    console.log(`Applying migration ${migration.version}: ${migration.filename}`);

    try {
      // Split SQL into individual statements and execute each
      const statements = migration.sql
        .split(';')
        .map((stmt) => stmt.trim())
        .filter((stmt) => stmt.length > 0);

      for (const statement of statements) {
        if (statement.trim()) {
          await this.db.run(statement);
        }
      }

      // Record the migration as applied
      await this.db.run('INSERT INTO migrations (version, filename) VALUES (?, ?)', [
        migration.version,
        migration.filename,
      ]);

      console.log(`✅ Migration ${migration.version} applied successfully`);
    } catch (error) {
      console.error(`❌ Failed to apply migration ${migration.version}: ${error}`);
      throw error;
    }
  }

  /**
   * Run all pending migrations
   */
  public async runMigrations(): Promise<void> {
    console.log('🚀 Starting database migration...');

    try {
      // Initialize migrations table
      await this.initializeMigrationsTable();

      // Get all migrations and applied migrations
      const availableMigrations = this.getMigrationFiles();
      const appliedMigrations = await this.getAppliedMigrations();

      // Find pending migrations
      const pendingMigrations = availableMigrations.filter(
        (migration) => !appliedMigrations.includes(migration.version),
      );

      if (pendingMigrations.length === 0) {
        console.log('✅ No pending migrations. Database is up to date.');
        return;
      }

      console.log(`📋 Found ${pendingMigrations.length} pending migration(s)`);

      // Apply each pending migration
      for (const migration of pendingMigrations) {
        await this.applyMigration(migration);
      }

      console.log('🎉 All migrations completed successfully!');
    } catch (error) {
      console.error('💥 Migration failed:', error);
      throw error;
    }
  }

  /**
   * Get the current database version
   */
  public async getCurrentVersion(): Promise<number> {
    await this.initializeMigrationsTable();

    const result = await this.db.get<{ version: number }>(
      'SELECT MAX(version) as version FROM migrations',
    );

    return result?.version || 0;
  }
}

/**
 * Run migrations using the global database connection
 */
export async function runMigrations(isTest: boolean = false): Promise<void> {
  const db = await getDatabase(isTest);
  const migrationsDir = path.join(__dirname, '../../../database/migrations');
  const runner = new MigrationRunner(db, migrationsDir);

  await runner.runMigrations();
}
