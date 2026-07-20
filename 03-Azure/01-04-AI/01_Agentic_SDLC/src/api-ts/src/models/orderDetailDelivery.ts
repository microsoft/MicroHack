/**
 * @swagger
 * components:
 *   schemas:
 *     OrderDetailDelivery:
 *       type: object
 *       required:
 *         - orderDetailDeliveryId
 *         - orderDetailId
 *         - deliveryId
 *       properties:
 *         orderDetailDeliveryId:
 *           type: integer
 *           description: The unique identifier for the order detail delivery
 *         orderDetailId:
 *           type: integer
 *           description: The ID of the related order detail
 *         deliveryId:
 *           type: integer
 *           description: The ID of the related delivery
 *         quantity:
 *           type: integer
 *           description: The quantity of items in this delivery
 *         notes:
 *           type: string
 *           description: Additional notes about this delivery
 */
export interface OrderDetailDelivery {
  orderDetailDeliveryId: number;
  orderDetailId: number;
  deliveryId: number;
  quantity: number;
  notes: string;
}
