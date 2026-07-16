/**
 * Repository for order detail deliveries data access
 */

import { getDatabase, DatabaseConnection } from '../db/sqlite';
import { OrderDetailDelivery } from '../models/orderDetailDelivery';
import { handleDatabaseError, NotFoundError } from '../utils/errors';
import { buildInsertSQL, buildUpdateSQL, objectToCamelCase, mapDatabaseRows, DatabaseRow } from '../utils/sql';

export class OrderDetailDeliveriesRepository {
  private db: DatabaseConnection;

  constructor(db: DatabaseConnection) {
    this.db = db;
  }

  /**
   * Get all order detail deliveries
   */
  async findAll(): Promise<OrderDetailDelivery[]> {
    try {
      const rows = await this.db.all<DatabaseRow>(
        'SELECT * FROM order_detail_deliveries ORDER BY order_detail_delivery_id',
      );
      return mapDatabaseRows<OrderDetailDelivery>(rows);
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Get order detail delivery by ID
   */
  async findById(id: number): Promise<OrderDetailDelivery | null> {
    try {
      const row = await this.db.get<DatabaseRow>(
        'SELECT * FROM order_detail_deliveries WHERE order_detail_delivery_id = ?',
        [id],
      );
      return row ? objectToCamelCase<OrderDetailDelivery>(row) : null;
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Create a new order detail delivery
   */
  async create(
    orderDetailDelivery: Omit<OrderDetailDelivery, 'orderDetailDeliveryId'>,
  ): Promise<OrderDetailDelivery> {
    try {
      const { sql, values } = buildInsertSQL('order_detail_deliveries', orderDetailDelivery);
      const result = await this.db.run(sql, values);

      const createdOrderDetailDelivery = await this.findById(result.lastID || 0);
      if (!createdOrderDetailDelivery) {
        throw new Error('Failed to retrieve created order detail delivery');
      }

      return createdOrderDetailDelivery;
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Update order detail delivery by ID
   */
  async update(
    id: number,
    orderDetailDelivery: Partial<Omit<OrderDetailDelivery, 'orderDetailDeliveryId'>>,
  ): Promise<OrderDetailDelivery> {
    try {
      const { sql, values } = buildUpdateSQL(
        'order_detail_deliveries',
        orderDetailDelivery,
        'order_detail_delivery_id = ?',
      );
      const result = await this.db.run(sql, [...values, id]);

      if (result.changes === 0) {
        throw new NotFoundError('OrderDetailDelivery', id);
      }

      const updatedOrderDetailDelivery = await this.findById(id);
      if (!updatedOrderDetailDelivery) {
        throw new Error('Failed to retrieve updated order detail delivery');
      }

      return updatedOrderDetailDelivery;
    } catch (error) {
      handleDatabaseError(error, 'OrderDetailDelivery', id);
    }
  }

  /**
   * Delete order detail delivery by ID
   */
  async delete(id: number): Promise<void> {
    try {
      const result = await this.db.run(
        'DELETE FROM order_detail_deliveries WHERE order_detail_delivery_id = ?',
        [id],
      );

      if (result.changes === 0) {
        throw new NotFoundError('OrderDetailDelivery', id);
      }
    } catch (error) {
      handleDatabaseError(error, 'OrderDetailDelivery', id);
    }
  }

  /**
   * Check if order detail delivery exists
   */
  async exists(id: number): Promise<boolean> {
    try {
      const result = await this.db.get<{ count: number }>(
        'SELECT COUNT(*) as count FROM order_detail_deliveries WHERE order_detail_delivery_id = ?',
        [id],
      );
      return (result?.count || 0) > 0;
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Find order detail deliveries by order detail ID
   */
  async findByOrderDetailId(orderDetailId: number): Promise<OrderDetailDelivery[]> {
    try {
      const rows = await this.db.all<DatabaseRow>(
        'SELECT * FROM order_detail_deliveries WHERE order_detail_id = ? ORDER BY order_detail_delivery_id',
        [orderDetailId],
      );
      return mapDatabaseRows<OrderDetailDelivery>(rows);
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Find order detail deliveries by delivery ID
   */
  async findByDeliveryId(deliveryId: number): Promise<OrderDetailDelivery[]> {
    try {
      const rows = await this.db.all<DatabaseRow>(
        'SELECT * FROM order_detail_deliveries WHERE delivery_id = ? ORDER BY order_detail_delivery_id',
        [deliveryId],
      );
      return mapDatabaseRows<OrderDetailDelivery>(rows);
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Get total quantity delivered for an order detail
   */
  async getTotalQuantityByOrderDetailId(orderDetailId: number): Promise<number> {
    try {
      const result = await this.db.get<{ total: number }>(
        'SELECT SUM(quantity) as total FROM order_detail_deliveries WHERE order_detail_id = ?',
        [orderDetailId],
      );
      return result?.total || 0;
    } catch (error) {
      handleDatabaseError(error);
    }
  }
}

// Factory function to create repository instance
export async function createOrderDetailDeliveriesRepository(
  isTest: boolean = false,
): Promise<OrderDetailDeliveriesRepository> {
  const db = await getDatabase(isTest);
  return new OrderDetailDeliveriesRepository(db);
}

// Singleton instance for default usage
let orderDetailDeliveriesRepo: OrderDetailDeliveriesRepository | null = null;

export async function getOrderDetailDeliveriesRepository(
  isTest: boolean = false,
): Promise<OrderDetailDeliveriesRepository> {
  if (!orderDetailDeliveriesRepo) {
    orderDetailDeliveriesRepo = await createOrderDetailDeliveriesRepository(isTest);
  }
  return orderDetailDeliveriesRepo;
}
