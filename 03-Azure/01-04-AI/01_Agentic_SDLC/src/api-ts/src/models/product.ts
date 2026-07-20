/**
 * @swagger
 * components:
 *   schemas:
 *     Product:
 *       type: object
 *       required:
 *         - productId
 *         - supplierId
 *         - name
 *         - price
 *         - sku
 *         - unit
 *       properties:
 *         productId:
 *           type: integer
 *           description: The unique identifier for the product
 *         supplierId:
 *           type: integer
 *           description: The ID of the supplier providing this product
 *         name:
 *           type: string
 *           description: The name of the product
 *         description:
 *           type: string
 *           description: Detailed description of the product
 *         price:
 *           type: number
 *           format: float
 *           description: The current price of the product
 *         sku:
 *           type: string
 *           description: Stock keeping unit code for the product
 *         unit:
 *           type: string
 *           description: Unit of measure for the product (e.g., "piece")
 *         imgName:
 *           type: string
 *           description: Filename of the product image
 *         discount:
 *           type: number
 *           format: float
 *           description: Discount percentage (if applicable) expressed as a decimal (e.g., 0.25 for 25%)
 */
export interface Product {
  productId: number;
  supplierId: number;
  name: string;
  description: string;
  price: number;
  sku: string;
  unit: string;
  imgName: string;
  discount?: number;
}
