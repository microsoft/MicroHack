/**
 * @swagger
 * components:
 *   schemas:
 *     Supplier:
 *       type: object
 *       required:
 *         - supplierId
 *         - name
 *       properties:
 *         supplierId:
 *           type: integer
 *           description: The unique identifier for the supplier
 *         name:
 *           type: string
 *           description: The name of the supplier
 *         contactPerson:
 *           type: string
 *           description: Name of the primary contact person
 *         email:
 *           type: string
 *           format: email
 *           description: Contact email for the supplier
 *         phone:
 *           type: string
 *           description: Contact phone number for the supplier
 *         description:
 *           type: string
 *           description: Additional details about the supplier
 *         active:
 *           type: boolean
 *           description: Whether the supplier is active
 *         verified:
 *           type: boolean
 *           description: Whether the supplier is verified
 */
export interface Supplier {
  supplierId: number;
  name: string;
  description: string;
  contactPerson: string;
  email: string;
  phone: string;
  active: boolean;
  verified: boolean;
}
