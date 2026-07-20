/**
 * Repository for products data access
 */

import { getDatabase, DatabaseConnection } from '../db/sqlite';
import { Product } from '../models/product';
import { handleDatabaseError, NotFoundError } from '../utils/errors';
import { buildInsertSQL, buildUpdateSQL, objectToCamelCase, mapDatabaseRows, DatabaseRow } from '../utils/sql';

export class ProductsRepository {
  private db: DatabaseConnection;

  constructor(db: DatabaseConnection) {
    this.db = db;
  }

  /**
   * Get all products
   */
  async findAll(): Promise<Product[]> {
    try {
      const rows = await this.db.all<DatabaseRow>('SELECT * FROM products ORDER BY product_id');
      return mapDatabaseRows<Product>(rows);
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Get product by ID
   */
  async findById(id: number): Promise<Product | null> {
    try {
      const row = await this.db.get<DatabaseRow>('SELECT * FROM products WHERE product_id = ?', [id]);
      return row ? objectToCamelCase<Product>(row) : null;
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Create a new product
   */
  async create(product: Omit<Product, 'productId'>): Promise<Product> {
    try {
      const { sql, values } = buildInsertSQL('products', product);
      const result = await this.db.run(sql, values);

      const createdProduct = await this.findById(result.lastID || 0);
      if (!createdProduct) {
        throw new Error('Failed to retrieve created product');
      }

      return createdProduct;
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Update product by ID
   */
  async update(id: number, product: Partial<Omit<Product, 'productId'>>): Promise<Product> {
    try {
      const { sql, values } = buildUpdateSQL('products', product, 'product_id = ?');
      const result = await this.db.run(sql, [...values, id]);

      if (result.changes === 0) {
        throw new NotFoundError('Product', id);
      }

      const updatedProduct = await this.findById(id);
      if (!updatedProduct) {
        throw new Error('Failed to retrieve updated product');
      }

      return updatedProduct;
    } catch (error) {
      handleDatabaseError(error, 'Product', id);
    }
  }

  /**
   * Delete product by ID
   */
  async delete(id: number): Promise<void> {
    try {
      const result = await this.db.run('DELETE FROM products WHERE product_id = ?', [id]);

      if (result.changes === 0) {
        throw new NotFoundError('Product', id);
      }
    } catch (error) {
      handleDatabaseError(error, 'Product', id);
    }
  }

  /**
   * Check if product exists
   */
  async exists(id: number): Promise<boolean> {
    try {
      const result = await this.db.get<{ count: number }>(
        'SELECT COUNT(*) as count FROM products WHERE product_id = ?',
        [id],
      );
      return (result?.count || 0) > 0;
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Find products by supplier ID
   */
  async findBySupplierId(supplierId: number): Promise<Product[]> {
    try {
      const rows = await this.db.all<DatabaseRow>(
        'SELECT * FROM products WHERE supplier_id = ? ORDER BY name',
        [supplierId],
      );
      return mapDatabaseRows<Product>(rows);
    } catch (error) {
      handleDatabaseError(error);
    }
  }

  /**
   * Find products by name (partial match)
   */
  async findByName(name: string): Promise<Product[]> {
    try {
      const rows = await this.db.all<DatabaseRow>(
        `SELECT * FROM products WHERE name LIKE '%${name}%' ORDER BY name`,
      );
      return mapDatabaseRows<Product>(rows);
    } catch (error) {
      handleDatabaseError(error);
    }
  }
}

// Factory function to create repository instance
export async function createProductsRepository(
  isTest: boolean = false,
): Promise<ProductsRepository> {
  const db = await getDatabase(isTest);
  return new ProductsRepository(db);
}

// Singleton instance for default usage
let productsRepo: ProductsRepository | null = null;

export async function getProductsRepository(isTest: boolean = false): Promise<ProductsRepository> {
  const isTestEnv = isTest || process.env.NODE_ENV === 'test' || process.env.VITEST === 'true';
  if (isTestEnv) {
    // In tests, always return a fresh repository bound to the current in-memory DB
    return createProductsRepository(true);
  }
  if (!productsRepo) {
    productsRepo = await createProductsRepository(false);
  }
  return productsRepo;
}
