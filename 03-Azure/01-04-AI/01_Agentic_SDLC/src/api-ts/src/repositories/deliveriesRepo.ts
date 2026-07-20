/**
 * Repository for deliveries data access
 */

import { getDatabase, DatabaseConnection } from '../db/sqlite';
import { Delivery } from '../models/delivery';
import { handleDatabaseError, NotFoundError } from '../utils/errors';
import { buildInsertSQL, buildUpdateSQL, objectToCamelCase, mapDatabaseRows, DatabaseRow } from '../utils/sql';

export class DeliveriesRepository {
  private db: DatabaseConnection;

  constructor(db: DatabaseConnection) {
    this.db = db;
  }

  /**
   * Get all deliveries
   */
  async findAll(): Promise<Delivery[]> {
    try {
      const rows = await this.db.all<DatabaseRow>('SELECT * FROM deliveries ORDER BY delivery_id');
      return mapDatabaseRows<Delivery>(rows);
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Get delivery by ID
   */
  async findById(id: number): Promise<Delivery | null> {
    try {
      const row = await this.db.get<DatabaseRow>('SELECT * FROM deliveries WHERE delivery_id = ?', [id]);
      return row ? objectToCamelCase<Delivery>(row) : null;
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Create a new delivery
   */
  async create(delivery: Omit<Delivery, 'deliveryId'>): Promise<Delivery> {
    try {
      const { sql, values } = buildInsertSQL('deliveries', delivery);
      const result = await this.db.run(sql, values);

      const createdDelivery = await this.findById(result.lastID || 0);
      if (!createdDelivery) {
        throw new Error('Failed to retrieve created delivery');
      }

      return createdDelivery;
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Update delivery by ID
   */
  async update(id: number, delivery: Partial<Omit<Delivery, 'deliveryId'>>): Promise<Delivery> {
    try {
      const { sql, values } = buildUpdateSQL('deliveries', delivery, 'delivery_id = ?');
      const result = await this.db.run(sql, [...values, id]);

      if (result.changes === 0) {
        throw new NotFoundError('Delivery', id);
      }

      const updatedDelivery = await this.findById(id);
      if (!updatedDelivery) {
        throw new Error('Failed to retrieve updated delivery');
      }

      return updatedDelivery;
    } catch (error) {
      handleDatabaseError(error, 'Delivery', id);
    }
  }

  /**
   * Delete delivery by ID
   */
  async delete(id: number): Promise<void> {
    try {
      const result = await this.db.run('DELETE FROM deliveries WHERE delivery_id = ?', [id]);

      if (result.changes === 0) {
        throw new NotFoundError('Delivery', id);
      }
    } catch (error) {
      handleDatabaseError(error, 'Delivery', id);
    }
  }

  /**
   * Check if delivery exists
   */
  async exists(id: number): Promise<boolean> {
    try {
      const result = await this.db.get<{ count: number }>(
        'SELECT COUNT(*) as count FROM deliveries WHERE delivery_id = ?',
        [id],
      );
      return (result?.count || 0) > 0;
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Find deliveries by supplier ID
   */
  async findBySupplierId(supplierId: number): Promise<Delivery[]> {
    try {
      const rows = await this.db.all<DatabaseRow>(
        'SELECT * FROM deliveries WHERE supplier_id = ? ORDER BY delivery_date DESC',
        [supplierId],
      );
      return mapDatabaseRows<Delivery>(rows);
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Find deliveries by status
   */
  async findByStatus(status: string): Promise<Delivery[]> {
    try {
      const rows = await this.db.all<DatabaseRow>(
        'SELECT * FROM deliveries WHERE status = ? ORDER BY delivery_date DESC',
        [status],
      );
      return mapDatabaseRows<Delivery>(rows);
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Find deliveries by date range
   */
  async findByDateRange(startDate: string, endDate: string): Promise<Delivery[]> {
    try {
      const rows = await this.db.all<DatabaseRow>(
        'SELECT * FROM deliveries WHERE delivery_date >= ? AND delivery_date <= ? ORDER BY delivery_date DESC',
        [startDate, endDate],
      );
      return mapDatabaseRows<Delivery>(rows);
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Update delivery status
   */
  async updateStatus(id: number, status: string): Promise<Delivery> {
    try {
      return await this.update(id, { status });
    } catch (error) {
      handleDatabaseError(error, 'Delivery', id);
    }
  }
}

// Factory function to create repository instance
export async function createDeliveriesRepository(
  isTest: boolean = false,
): Promise<DeliveriesRepository> {
  const db = await getDatabase(isTest);
  return new DeliveriesRepository(db);
}

// Singleton instance for default usage
let deliveriesRepo: DeliveriesRepository | null = null;

export async function getDeliveriesRepository(
  isTest: boolean = false,
): Promise<DeliveriesRepository> {
  const isTestEnv = isTest || process.env.NODE_ENV === 'test' || process.env.VITEST === 'true';
  if (isTestEnv) {
    return createDeliveriesRepository(true);
  }
  if (!deliveriesRepo) {
    deliveriesRepo = await createDeliveriesRepository(false);
  }
  return deliveriesRepo;
}
