/**
 * Repository for branches data access
 */

import { getDatabase, DatabaseConnection } from '../db/sqlite';
import { Branch } from '../models/branch';
import { handleDatabaseError, NotFoundError } from '../utils/errors';
import { buildInsertSQL, buildUpdateSQL, objectToCamelCase, mapDatabaseRows, DatabaseRow } from '../utils/sql';

export class BranchesRepository {
  private db: DatabaseConnection;

  constructor(db: DatabaseConnection) {
    this.db = db;
  }

  /**
   * Get all branches
   */
  async findAll(): Promise<Branch[]> {
    try {
      const rows = await this.db.all<DatabaseRow>('SELECT * FROM branches ORDER BY branch_id');
      return mapDatabaseRows<Branch>(rows);
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Get branch by ID
   */
  async findById(id: number): Promise<Branch | null> {
    try {
      const row = await this.db.get<DatabaseRow>('SELECT * FROM branches WHERE branch_id = ?', [id]);
      return row ? objectToCamelCase<Branch>(row) : null;
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Create a new branch
   */
  async create(branch: Omit<Branch, 'branchId'>): Promise<Branch> {
    try {
      const { sql, values } = buildInsertSQL('branches', branch);
      const result = await this.db.run(sql, values);

      const createdBranch = await this.findById(result.lastID || 0);
      if (!createdBranch) {
        throw new Error('Failed to retrieve created branch');
      }

      return createdBranch;
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Update branch by ID
   */
  async update(id: number, branch: Partial<Omit<Branch, 'branchId'>>): Promise<Branch> {
    try {
      const { sql, values } = buildUpdateSQL('branches', branch, 'branch_id = ?');
      const result = await this.db.run(sql, [...values, id]);

      if (result.changes === 0) {
        throw new NotFoundError('Branch', id);
      }

      const updatedBranch = await this.findById(id);
      if (!updatedBranch) {
        throw new Error('Failed to retrieve updated branch');
      }

      return updatedBranch;
    } catch (error) {
      handleDatabaseError(error, 'Branch', id);
    }
  }

  /**
   * Delete branch by ID
   */
  async delete(id: number): Promise<void> {
    try {
      const result = await this.db.run('DELETE FROM branches WHERE branch_id = ?', [id]);

      if (result.changes === 0) {
        throw new NotFoundError('Branch', id);
      }
    } catch (error) {
      handleDatabaseError(error, 'Branch', id);
    }
  }

  /**
   * Check if branch exists
   */
  async exists(id: number): Promise<boolean> {
    try {
      const result = await this.db.get<{ count: number }>(
        'SELECT COUNT(*) as count FROM branches WHERE branch_id = ?',
        [id],
      );
      return (result?.count || 0) > 0;
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Find branches by headquarters ID
   */
  async findByHeadquartersId(headquartersId: number): Promise<Branch[]> {
    try {
      const rows = await this.db.all<DatabaseRow>(
        'SELECT * FROM branches WHERE headquarters_id = ? ORDER BY name',
        [headquartersId],
      );
      return mapDatabaseRows<Branch>(rows);
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Find branches by name (partial match)
   */
  async findByName(name: string): Promise<Branch[]> {
    try {
      const rows = await this.db.all<DatabaseRow>(
        'SELECT * FROM branches WHERE name LIKE ? ORDER BY name',
        [`%${name}%`],
      );
      return mapDatabaseRows<Branch>(rows);
    } catch (error) {
      handleDatabaseError(error);
    }
  }
}

// Factory function to create repository instance
export async function createBranchesRepository(
  isTest: boolean = false,
): Promise<BranchesRepository> {
  const db = await getDatabase(isTest);
  return new BranchesRepository(db);
}

// Singleton instance for default usage
let branchesRepo: BranchesRepository | null = null;

export async function getBranchesRepository(isTest: boolean = false): Promise<BranchesRepository> {
  const isTestEnv = isTest || process.env.NODE_ENV === 'test' || process.env.VITEST === 'true';
  if (isTestEnv) {
    // In tests, always return a fresh repository bound to the current in-memory DB
    return createBranchesRepository(true);
  }
  if (!branchesRepo) {
    branchesRepo = await createBranchesRepository(false);
  }
  return branchesRepo;
}
