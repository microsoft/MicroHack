/**
 * Repository for headquarters data access
 */

import { getDatabase, DatabaseConnection } from '../db/sqlite';
import { Headquarters } from '../models/headquarters';
import { handleDatabaseError, NotFoundError } from '../utils/errors';
import { buildInsertSQL, buildUpdateSQL, objectToCamelCase, mapDatabaseRows, DatabaseRow } from '../utils/sql';

export class HeadquartersRepository {
  private db: DatabaseConnection;

  constructor(db: DatabaseConnection) {
    this.db = db;
  }

  /**
   * Get all headquarters
   */
  async findAll(): Promise<Headquarters[]> {
    try {
      const rows = await this.db.all<DatabaseRow>('SELECT * FROM headquarters ORDER BY headquarters_id');
      return mapDatabaseRows<Headquarters>(rows);
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Get headquarters by ID
   */
  async findById(id: number): Promise<Headquarters | null> {
    try {
      const row = await this.db.get<DatabaseRow>('SELECT * FROM headquarters WHERE headquarters_id = ?', [
        id,
      ]);
      return row ? objectToCamelCase<Headquarters>(row) : null;
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Create a new headquarters
   */
  async create(headquarters: Omit<Headquarters, 'headquartersId'>): Promise<Headquarters> {
    try {
      const { sql, values } = buildInsertSQL('headquarters', headquarters);
      const result = await this.db.run(sql, values);

      const createdHeadquarters = await this.findById(result.lastID || 0);
      if (!createdHeadquarters) {
        throw new Error('Failed to retrieve created headquarters');
      }

      return createdHeadquarters;
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Update headquarters by ID
   */
  async update(
    id: number,
    headquarters: Partial<Omit<Headquarters, 'headquartersId'>>,
  ): Promise<Headquarters> {
    try {
      const { sql, values } = buildUpdateSQL('headquarters', headquarters, 'headquarters_id = ?');
      const result = await this.db.run(sql, [...values, id]);

      if (result.changes === 0) {
        throw new NotFoundError('Headquarters', id);
      }

      const updatedHeadquarters = await this.findById(id);
      if (!updatedHeadquarters) {
        throw new Error('Failed to retrieve updated headquarters');
      }

      return updatedHeadquarters;
    } catch (error) {
      handleDatabaseError(error, 'Headquarters', id);
    }
  }

  /**
   * Delete headquarters by ID
   */
  async delete(id: number): Promise<void> {
    try {
      const result = await this.db.run('DELETE FROM headquarters WHERE headquarters_id = ?', [id]);

      if (result.changes === 0) {
        throw new NotFoundError('Headquarters', id);
      }
    } catch (error) {
      handleDatabaseError(error, 'Headquarters', id);
    }
  }

  /**
   * Check if headquarters exists
   */
  async exists(id: number): Promise<boolean> {
    try {
      const result = await this.db.get<{ count: number }>(
        'SELECT COUNT(*) as count FROM headquarters WHERE headquarters_id = ?',
        [id],
      );
      return (result?.count || 0) > 0;
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Find headquarters by name (partial match)
   */
  async findByName(name: string): Promise<Headquarters[]> {
    try {
      const rows = await this.db.all<DatabaseRow>(
        'SELECT * FROM headquarters WHERE name LIKE ? ORDER BY name',
        [`%${name}%`],
      );
      return mapDatabaseRows<Headquarters>(rows);
    } catch (error) {
      handleDatabaseError(error);
    }
  }
}

// Factory function to create repository instance
export async function createHeadquartersRepository(
  isTest: boolean = false,
): Promise<HeadquartersRepository> {
  const db = await getDatabase(isTest);
  return new HeadquartersRepository(db);
}

// Singleton instance for default usage
let headquartersRepo: HeadquartersRepository | null = null;

export async function getHeadquartersRepository(
  isTest: boolean = false,
): Promise<HeadquartersRepository> {
  if (!headquartersRepo) {
    headquartersRepo = await createHeadquartersRepository(isTest);
  }
  return headquartersRepo;
}
