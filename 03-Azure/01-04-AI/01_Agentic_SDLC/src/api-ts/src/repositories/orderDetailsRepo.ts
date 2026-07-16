/**
 * Repository for order details data access
 */

import { getDatabase, DatabaseConnection } from '../db/sqlite';
import { OrderDetail } from '../models/orderDetail';
import { handleDatabaseError, NotFoundError } from '../utils/errors';
import { buildInsertSQL, buildUpdateSQL, objectToCamelCase, mapDatabaseRows, DatabaseRow } from '../utils/sql';

export class OrderDetailsRepository {
  private db: DatabaseConnection;

  constructor(db: DatabaseConnection) {
    this.db = db;
  }

  /**
   * Get all order details
   */
  async findAll(): Promise<OrderDetail[]> {
    try {
      const rows = await this.db.all<DatabaseRow>('SELECT * FROM order_details ORDER BY order_detail_id');
      return mapDatabaseRows<OrderDetail>(rows);
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Get order detail by ID
   */
  async findById(id: number): Promise<OrderDetail | null> {
    try {
      const row = await this.db.get<DatabaseRow>('SELECT * FROM order_details WHERE order_detail_id = ?', [
        id,
      ]);
      return row ? objectToCamelCase<OrderDetail>(row) : null;
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Create a new order detail
   */
  async create(orderDetail: Omit<OrderDetail, 'orderDetailId'>): Promise<OrderDetail> {
    try {
      const { sql, values } = buildInsertSQL('order_details', orderDetail);
      const result = await this.db.run(sql, values);

      const createdOrderDetail = await this.findById(result.lastID || 0);
      if (!createdOrderDetail) {
        throw new Error('Failed to retrieve created order detail');
      }

      return createdOrderDetail;
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Update order detail by ID
   */
  async update(
    id: number,
    orderDetail: Partial<Omit<OrderDetail, 'orderDetailId'>>,
  ): Promise<OrderDetail> {
    try {
      const { sql, values } = buildUpdateSQL('order_details', orderDetail, 'order_detail_id = ?');
      const result = await this.db.run(sql, [...values, id]);

      if (result.changes === 0) {
        throw new NotFoundError('OrderDetail', id);
      }

      const updatedOrderDetail = await this.findById(id);
      if (!updatedOrderDetail) {
        throw new Error('Failed to retrieve updated order detail');
      }

      return updatedOrderDetail;
    } catch (error) {
      handleDatabaseError(error, 'OrderDetail', id);
    }
  }

  /**
   * Delete order detail by ID
   */
  async delete(id: number): Promise<void> {
    try {
      const result = await this.db.run('DELETE FROM order_details WHERE order_detail_id = ?', [id]);

      if (result.changes === 0) {
        throw new NotFoundError('OrderDetail', id);
      }
    } catch (error) {
      handleDatabaseError(error, 'OrderDetail', id);
    }
  }

  /**
   * Check if order detail exists
   */
  async exists(id: number): Promise<boolean> {
    try {
      const result = await this.db.get<{ count: number }>(
        'SELECT COUNT(*) as count FROM order_details WHERE order_detail_id = ?',
        [id],
      );
      return (result?.count || 0) > 0;
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Find order details by order ID
   */
  async findByOrderId(orderId: number): Promise<OrderDetail[]> {
    try {
      const rows = await this.db.all<DatabaseRow>(
        'SELECT * FROM order_details WHERE order_id = ? ORDER BY order_detail_id',
        [orderId],
      );
      return mapDatabaseRows<OrderDetail>(rows);
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Find order details by product ID
   */
  async findByProductId(productId: number): Promise<OrderDetail[]> {
    try {
      const rows = await this.db.all<DatabaseRow>(
        'SELECT * FROM order_details WHERE product_id = ? ORDER BY order_detail_id',
        [productId],
      );
      return mapDatabaseRows<OrderDetail>(rows);
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Calculate total value for an order
   */
  async getTotalValueByOrderId(orderId: number): Promise<number> {
    try {
      const result = await this.db.get<{ total: number }>(
        'SELECT SUM(quantity * unit_price) as total FROM order_details WHERE order_id = ?',
        [orderId],
      );
      return result?.total || 0;
    } catch (error) {
      handleDatabaseError(error);
    }
  }
}

// Factory function to create repository instance
export async function createOrderDetailsRepository(
  isTest: boolean = false,
): Promise<OrderDetailsRepository> {
  const db = await getDatabase(isTest);
  return new OrderDetailsRepository(db);
}

// Singleton instance for default usage
let orderDetailsRepo: OrderDetailsRepository | null = null;

export async function getOrderDetailsRepository(
  isTest: boolean = false,
): Promise<OrderDetailsRepository> {
  if (!orderDetailsRepo) {
    orderDetailsRepo = await createOrderDetailsRepository(isTest);
  }
  return orderDetailsRepo;
}
