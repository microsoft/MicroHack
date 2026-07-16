/**
 * @swagger
 * components:
 *   schemas:
 *     Headquarters:
 *       type: object
 *       required:
 *         - headquartersId
 *         - name
 *       properties:
 *         headquartersId:
 *           type: integer
 *           description: The unique identifier for the headquarters
 *         name:
 *           type: string
 *           description: The name of the headquarters
 *         address:
 *           type: string
 *           description: Main office address of the headquarters
 *         phone:
 *           type: string
 *           description: Contact phone number for the headquarters
 *         description:
 *           type: string
 *           description: Additional details about the headquarters
 *         contactPerson:
 *           type: string
 *           description: Name of the primary contact person
 *         email:
 *           type: string
 *           format: email
 *           description: Contact email for the headquarters
 *         city:
 *           type: string
 *           description: City where the headquarters is located
 *         country:
 *           type: string
 *           description: Country where the headquarters is located
 *         floorCount:
 *           type: integer
 *           description: Number of floors in the headquarters building
 *         capacity:
 *           type: integer
 *           description: Total capacity of the headquarters
 */
export interface Headquarters {
  headquartersId: number;
  name: string;
  description: string;
  address: string;
  contactPerson: string;
  email: string;
  phone: string;
  city?: string;
  country?: string;
  floorCount?: number;
  capacity?: number;
}
