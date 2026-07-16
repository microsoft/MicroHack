/**
 * Database seeder for populating initial data
 */

import fs from 'fs';
import path from 'path';
import { getDatabase, DatabaseConnection } from './sqlite';

export class DatabaseSeeder {
  private db: DatabaseConnection;
  private seedsDir: string;

  constructor(db: DatabaseConnection, seedsDir: string = '../database/seed') {
    this.db = db;
    this.seedsDir = path.resolve(seedsDir);
  }

  /**
   * Check if database has been seeded
   */
  private async isSeeded(): Promise<boolean> {
    try {
      // Check if any suppliers exist (assuming suppliers are seeded first)
      const result = await this.db.get<{ count: number }>(
        'SELECT COUNT(*) as count FROM suppliers',
      );
      return (result?.count || 0) > 0;
    } catch {
      // If table doesn't exist, database is not seeded
      return false;
    }
  }

  /**
   * Get all seed files from the seeds directory
   */
  private getSeedFiles(): string[] {
    if (!fs.existsSync(this.seedsDir)) {
      console.log(`Seeds directory not found: ${this.seedsDir}. Skipping seeding.`);
      return [];
    }

    return fs
      .readdirSync(this.seedsDir)
      .filter((file) => file.endsWith('.sql'))
      .sort(); // Ensure predictable order
  }

  /**
   * Execute a seed file
   */
  private async executeSeedFile(filename: string): Promise<void> {
    const filePath = path.join(this.seedsDir, filename);
    const sql = fs.readFileSync(filePath, 'utf-8');

    console.log(`🌱 Seeding from: ${filename}`);

    try {
      // Split SQL into individual statements and execute each
      const statements = sql
        .split(';')
        .map((stmt) => stmt.trim())
        .filter((stmt) => stmt.length > 0);

      for (const statement of statements) {
        if (statement.trim()) {
          await this.db.run(statement);
        }
      }

      console.log(`✅ Seeded successfully: ${filename}`);
    } catch (error) {
      console.error(`❌ Failed to seed ${filename}:`, error);
      throw error;
    }
  }

  /**
   * Seed the database with initial data
   */
  public async seedDatabase(force: boolean = false): Promise<void> {
    console.log('🌱 Starting database seeding...');

    try {
      // Check if already seeded
      if (!force && (await this.isSeeded())) {
        console.log('✅ Database already seeded. Use force=true to re-seed.');
        return;
      }

      // Get all seed files
      const seedFiles = this.getSeedFiles();

      if (seedFiles.length === 0) {
        console.log('📝 No seed files found. Skipping seeding.');
        return;
      }

      console.log(`📋 Found ${seedFiles.length} seed file(s)`);

      // Execute each seed file
      for (const filename of seedFiles) {
        await this.executeSeedFile(filename);
      }

      console.log('🎉 Database seeding completed successfully!');
    } catch (error) {
      console.error('💥 Seeding failed:', error);
      throw error;
    }
  }

  /**
   * Clear all data from the database (useful for re-seeding)
   */
  public async clearDatabase(): Promise<void> {
    console.log('🧹 Clearing database...');

    try {
      // Get all table names
      const tables = await this.db.all<{ name: string }>(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name != 'migrations'",
      );

      // Disable foreign key constraints temporarily
      await this.db.run('PRAGMA foreign_keys = OFF');

      // Clear all tables
      for (const table of tables) {
        await this.db.run(`DELETE FROM ${table.name}`);
        console.log(`🗑️ Cleared table: ${table.name}`);
      }

      // Re-enable foreign key constraints
      await this.db.run('PRAGMA foreign_keys = ON');

      console.log('✅ Database cleared successfully');
    } catch (error) {
      console.error('❌ Failed to clear database:', error);
      throw error;
    }
  }
}

/**
 * Seed the database using the global database connection
 */
export async function seedDatabase(force: boolean = false, isTest: boolean = false): Promise<void> {
  const db = await getDatabase(isTest);
  const seedsDir = path.join(__dirname, '../../../database/seed');
  const seeder = new DatabaseSeeder(db, seedsDir);

  await seeder.seedDatabase(force);
}

/**
 * Clear and re-seed the database
 */
export async function reseedDatabase(isTest: boolean = false): Promise<void> {
  const db = await getDatabase(isTest);
  const seedsDir = path.join(__dirname, '../../../database/seed');
  const seeder = new DatabaseSeeder(db, seedsDir);

  await seeder.clearDatabase();
  await seeder.seedDatabase(true);
}
