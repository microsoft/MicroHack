/**
 * @swagger
 * components:
 *   schemas:
 *     OrderDetail:
 *       type: object
 *       required:
 *         - orderDetailId
 *         - orderId
 *         - productId
 *         - quantity
 *         - unitPrice
 *       properties:
 *         orderDetailId:
 *           type: integer
 *           description: The unique identifier for the order detail
 *         orderId:
 *           type: integer
 *           description: The ID of the parent order
 *         productId:
 *           type: integer
 *           description: The ID of the product ordered
 *         quantity:
 *           type: integer
 *           description: The quantity of products ordered
 *         unitPrice:
 *           type: number
 *           format: float
 *           description: The price per unit
 *         notes:
 *           type: string
 *           description: Additional notes for the order detail
 */
export interface OrderDetail {
  orderDetailId: number;
  orderId: number;
  productId: number;
  quantity: number;
  unitPrice: number;
  notes: string;
}
