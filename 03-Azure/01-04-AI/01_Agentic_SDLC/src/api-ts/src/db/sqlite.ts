/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * SQLite database connection and helper functions
 */

import Database from 'better-sqlite3';
import fs from 'fs';
import path from 'path';
import { DB_CONFIG, TEST_DB_CONFIG } from './config';

/*
 * Database connection and query execution
 * Wraps better-sqlite3 Database to maintain API compatibility
 */
class DatabaseConnection {
  public db: Database.Database;

  constructor(db: Database.Database) {
    this.db = db;
  }

  /**
   * Execute a SQL statement that modifies data (INSERT, UPDATE, DELETE)
   * @param sql SQL statement to execute
   * @param params Parameters to bind to the SQL statement
   * @returns Object containing lastID (for INSERT) and number of changes
   * @throws Error if lastInsertRowid exceeds JavaScript's safe integer range
   * @note better-sqlite3 returns lastInsertRowid as number | bigint. We convert bigint to number
   *       and validate it's within safe integer range to prevent silent truncation.
   */
  public run(sql: string, params: unknown[] = []): Promise<{ lastID?: number; changes: number }> {
    const info = this.db.prepare(sql).run(...(params as any[]));
    const lastID = info.lastInsertRowid;
    
    // Convert bigint to number with safety check to prevent silent truncation
    if (typeof lastID === 'bigint') {
      if (lastID > Number.MAX_SAFE_INTEGER || lastID < Number.MIN_SAFE_INTEGER) {
        throw new Error(`Row ID ${lastID} exceeds safe integer range (${Number.MIN_SAFE_INTEGER} to ${Number.MAX_SAFE_INTEGER})`);
      }
      return Promise.resolve({ lastID: Number(lastID), changes: info.changes });
    }
    
    return Promise.resolve({ lastID, changes: info.changes });
  }

  public get<T = unknown>(sql: string, params: unknown[] = []): Promise<T | undefined> {
    const row = this.db.prepare(sql).get(...(params as any[]));
    return Promise.resolve(row as T | undefined);
  }

  public all<T = unknown>(sql: string, params: unknown[] = []): Promise<T[]> {
    const rows = this.db.prepare(sql).all(...(params as any[]));
    return Promise.resolve(rows as T[]);
  }

  public close(): Promise<void> {
    this.db.close();
    return Promise.resolve();
  }
}

class SQLiteHelper {
  private static instance: SQLiteHelper;
  private connection: Database.Database | null = null;

  private constructor() {}

  public static getInstance(): SQLiteHelper {
    if (!SQLiteHelper.instance) {
      SQLiteHelper.instance = new SQLiteHelper();
    }
    return SQLiteHelper.instance;
  }

  /**
   * Initialize database connection
   */
  public async connect(isTest: boolean = false): Promise<DatabaseConnection> {
    const config = isTest ? TEST_DB_CONFIG : DB_CONFIG;

    // Ensure data directory exists for file-based databases
    if (config.DB_FILE !== ':memory:') {
      const dataDir = path.dirname(config.DB_FILE);
      if (!fs.existsSync(dataDir)) {
        fs.mkdirSync(dataDir, { recursive: true });
      }
    }

    try {
      // better-sqlite3 constructor options
      const options: Database.Options = {
        verbose: process.env.NODE_ENV === 'development' ? console.log : undefined,
        timeout: config.TIMEOUT
      };

      this.connection = new Database(config.DB_FILE, options);

      // Configure database settings
      this.setupDatabase(config);

      const wrappedConnection = this.wrapConnection(this.connection);
      return wrappedConnection;
    } catch (err) {
      throw new Error(`Failed to connect to database: ${(err as Error).message}`);
    }
  }

  /**
   * Configure database settings
   */
  private setupDatabase(config: typeof DB_CONFIG): void {
    if (!this.connection) return;

    // Enable foreign key constraints
    if (config.FOREIGN_KEYS) {
      try {
        this.connection.pragma('foreign_keys = ON');
      } catch (err) {
        throw new Error(`Failed to enable foreign key constraints: ${(err as Error).message}`);
      }
    }

    // Enable WAL mode for better concurrency (only for file databases)
    if (config.ENABLE_WAL && config.DB_FILE !== ':memory:') {
      try {
        this.connection.pragma('journal_mode = WAL');
      } catch (err) {
        throw new Error(`Failed to enable WAL mode: ${(err as Error).message}`);
      }
    }
  }

  /**
   * Wrap the database connection with promisified methods
   */
  private wrapConnection(db: Database.Database): DatabaseConnection {
    return new DatabaseConnection(db);
  }

  /**
   * Close database connection
   */
  public async close(): Promise<void> {
    if (this.connection) {
      try {
        this.connection.close();
        this.connection = null;
      } catch (err) {
        throw new Error(`Failed to close database: ${(err as Error).message}`);
      }
    }
  }
}

// Global database connection instance
let dbConnection: DatabaseConnection | null = null;

/**
 * Get the global database connection
 */
export async function getDatabase(isTest: boolean = false): Promise<DatabaseConnection> {
  if (!dbConnection) {
    const helper = SQLiteHelper.getInstance();
    dbConnection = await helper.connect(isTest);
  }
  return dbConnection;
}

/**
 * Close the global database connection
 */
export async function closeDatabase(): Promise<void> {
  if (dbConnection) {
    await dbConnection.close();
    dbConnection = null;
  }
}

export { SQLiteHelper, DatabaseConnection };
