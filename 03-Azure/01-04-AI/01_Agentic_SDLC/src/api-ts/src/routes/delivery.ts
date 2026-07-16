/**
 * @swagger
 * tags:
 *   name: Deliveries
 *   description: API endpoints for managing deliveries
 */

/**
 * @swagger
 * /api/deliveries:
 *   get:
 *     summary: Returns all deliveries
 *     tags: [Deliveries]
 *     responses:
 *       200:
 *         description: List of all deliveries
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/Delivery'
 *   post:
 *     summary: Create a new delivery
 *     tags: [Deliveries]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Delivery'
 *     responses:
 *       201:
 *         description: Delivery created successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Delivery'
 *
 * /api/deliveries/{id}:
 *   get:
 *     summary: Get a delivery by ID
 *     tags: [Deliveries]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Delivery ID
 *     responses:
 *       200:
 *         description: Delivery found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Delivery'
 *       404:
 *         description: Delivery not found
 *   put:
 *     summary: Update a delivery
 *     tags: [Deliveries]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Delivery ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Delivery'
 *     responses:
 *       200:
 *         description: Delivery updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Delivery'
 *       404:
 *         description: Delivery not found
 *   delete:
 *     summary: Delete a delivery
 *     tags: [Deliveries]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Delivery ID
 *     responses:
 *       204:
 *         description: Delivery deleted successfully
 *       404:
 *         description: Delivery not found
 *
 * /api/deliveries/{id}/status:
 *   put:
 *     summary: Update the status of a delivery
 *     tags: [Deliveries]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Delivery ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - status
 *             properties:
 *               status:
 *                 type: string
 *                 description: The new status of the delivery
 *               deliveryPartner:
 *                 type: string
 *                 description: Optional delivery partner to notify via the notify-service about the status update
 *     responses:
 *       200:
 *         description: Delivery status updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               oneOf:
 *                 - $ref: '#/components/schemas/Delivery'
 *                 - type: object
 *                   properties:
 *                     delivery:
 *                       $ref: '#/components/schemas/Delivery'
 *                     commandOutput:
 *                       type: string
 *                       description: Output from the notify-service command
 *       404:
 *         description: Delivery not found
 *       500:
 *         description: Error executing notify command
 */

import express from 'express';
import { Delivery } from '../models/delivery';
import { exec } from 'child_process';
import { getDeliveriesRepository } from '../repositories/deliveriesRepo';
import { NotFoundError } from '../utils/errors';


const router = express.Router();

// Create a new delivery
router.post('/', async (req, res, next) => {
  try {
    const repo = await getDeliveriesRepository();
    const newDelivery = await repo.create(req.body as Omit<Delivery, 'deliveryId'>);
    res.status(201).json(newDelivery);
  } catch (error) {
    next(error);
  }
});

// Get all deliveries
router.get('/', async (req, res, next) => {
  try {
    const repo = await getDeliveriesRepository();
    const deliveries = await repo.findAll();
    res.json(deliveries);
  } catch (error) {
    next(error);
  }
});

// Get a delivery by ID
router.get('/:id', async (req, res, next) => {
  try {
    const repo = await getDeliveriesRepository();
    const delivery = await repo.findById(parseInt(req.params.id));
    if (delivery) {
      res.json(delivery);
    } else {
      res.status(404).send('Delivery not found');
    }
  } catch (error) {
    next(error);
  }
});

// Update the status of a delivery
router.put('/:id/status', async (req, res, next) => {
  try {
    const { status, deliveryPartner } = req.body;
    const repo = await getDeliveriesRepository();
    const delivery = await repo.findById(parseInt(req.params.id));

    if (delivery) {
      const updatedDelivery = await repo.updateStatus(parseInt(req.params.id), status);

      if (deliveryPartner) {
        exec(`notify ${deliveryPartner}`, (error, stdout) => {
          if (error) {
            console.error(`Error executing command: ${error}`);
            return res.status(500).json({ error: error.message });
          }
          res.json({ delivery: updatedDelivery, commandOutput: stdout });
        });
      } else {
        res.json(updatedDelivery);
      }
    } else {
      res.status(404).send('Delivery not found');
    }
  } catch (error) {
    if (error instanceof NotFoundError) {
      res.status(404).send('Delivery not found');
    } else {
      next(error);
    }
  }
});

// Update a delivery by ID
router.put('/:id', async (req, res, next) => {
  try {
    const repo = await getDeliveriesRepository();
    const updatedDelivery = await repo.update(parseInt(req.params.id), req.body);
    res.json(updatedDelivery);
  } catch (error) {
    if (error instanceof NotFoundError) {
      res.status(404).send('Delivery not found');
    } else {
      next(error);
    }
  }
});

// Delete a delivery by ID
router.delete('/:id', async (req, res, next) => {
  try {
    const repo = await getDeliveriesRepository();
    await repo.delete(parseInt(req.params.id));
    res.status(204).send();
  } catch (error) {
    if (error instanceof NotFoundError) {
      res.status(404).send('Delivery not found');
    } else {
      next(error);
    }
  }
});

export default router;
