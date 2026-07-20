/**
 * @swagger
 * components:
 *   schemas:
 *     Order:
 *       type: object
 *       required:
 *         - orderId
 *         - branchId
 *         - orderDate
 *       properties:
 *         orderId:
 *           type: integer
 *           description: The unique identifier for the order
 *         branchId:
 *           type: integer
 *           description: The ID of the branch that placed the order
 *         orderDate:
 *           type: string
 *           format: date-time
 *           description: The date and time when the order was placed
 *         name:
 *           type: string
 *           description: The name of the order
 *         description:
 *           type: string
 *           description: Additional details about the order
 *         status:
 *           type: string
 *           description: The current status of the order
 *           enum: [pending, processing, shipped, delivered, cancelled]
 */
export interface Order {
  orderId: number;
  branchId: number;
  orderDate: string;
  name: string;
  description: string;
  status: string;
}
