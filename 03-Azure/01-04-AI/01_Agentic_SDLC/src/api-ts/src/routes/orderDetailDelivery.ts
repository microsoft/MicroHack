/**
 * @swagger
 * tags:
 *   name: Order Detail Deliveries
 *   description: API endpoints for managing order detail deliveries
 */

/**
 * @swagger
 * /api/order-detail-deliveries:
 *   get:
 *     summary: Returns all order detail deliveries
 *     tags: [Order Detail Deliveries]
 *     responses:
 *       200:
 *         description: List of all order detail deliveries
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/OrderDetailDelivery'
 *   post:
 *     summary: Create a new order detail delivery
 *     tags: [Order Detail Deliveries]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/OrderDetailDelivery'
 *     responses:
 *       201:
 *         description: Order detail delivery created successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/OrderDetailDelivery'
 *
 * /api/order-detail-deliveries/{id}:
 *   get:
 *     summary: Get an order detail delivery by ID
 *     tags: [Order Detail Deliveries]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Order detail delivery ID
 *     responses:
 *       200:
 *         description: Order detail delivery found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/OrderDetailDelivery'
 *       404:
 *         description: Order detail delivery not found
 *   put:
 *     summary: Update an order detail delivery
 *     tags: [Order Detail Deliveries]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Order detail delivery ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/OrderDetailDelivery'
 *     responses:
 *       200:
 *         description: Order detail delivery updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/OrderDetailDelivery'
 *       404:
 *         description: Order detail delivery not found
 *   delete:
 *     summary: Delete an order detail delivery
 *     tags: [Order Detail Deliveries]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Order detail delivery ID
 *     responses:
 *       204:
 *         description: Order detail delivery deleted successfully
 *       404:
 *         description: Order detail delivery not found
 */

import express from 'express';
import { OrderDetailDelivery } from '../models/orderDetailDelivery';
import { getOrderDetailDeliveriesRepository } from '../repositories/orderDetailDeliveriesRepo';
import { NotFoundError } from '../utils/errors';

const router = express.Router();

// Create a new order detail delivery
router.post('/', async (req, res, next) => {
  try {
    const repo = await getOrderDetailDeliveriesRepository();
    const newOrderDetailDelivery = await repo.create(
      req.body as Omit<OrderDetailDelivery, 'orderDetailDeliveryId'>,
    );
    res.status(201).json(newOrderDetailDelivery);
  } catch (error) {
    next(error);
  }
});

// Get all order detail deliveries
router.get('/', async (req, res, next) => {
  try {
    const repo = await getOrderDetailDeliveriesRepository();
    const orderDetailDeliveries = await repo.findAll();
    res.json(orderDetailDeliveries);
  } catch (error) {
    next(error);
  }
});

// Get an order detail delivery by ID
router.get('/:id', async (req, res, next) => {
  try {
    const repo = await getOrderDetailDeliveriesRepository();
    const orderDetailDelivery = await repo.findById(parseInt(req.params.id));
    if (orderDetailDelivery) {
      res.json(orderDetailDelivery);
    } else {
      res.status(404).send('Order detail delivery not found');
    }
  } catch (error) {
    next(error);
  }
});

// Update an order detail delivery by ID
router.put('/:id', async (req, res, next) => {
  try {
    const repo = await getOrderDetailDeliveriesRepository();
    const updatedOrderDetailDelivery = await repo.update(parseInt(req.params.id), req.body);
    res.json(updatedOrderDetailDelivery);
  } catch (error) {
    if (error instanceof NotFoundError) {
      res.status(404).send('Order detail delivery not found');
    } else {
      next(error);
    }
  }
});

// Delete an order detail delivery by ID
router.delete('/:id', async (req, res, next) => {
  try {
    const repo = await getOrderDetailDeliveriesRepository();
    await repo.delete(parseInt(req.params.id));
    res.status(204).send();
  } catch (error) {
    if (error instanceof NotFoundError) {
      res.status(404).send('Order detail delivery not found');
    } else {
      next(error);
    }
  }
});

export default router;
