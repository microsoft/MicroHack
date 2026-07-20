/**
 * @swagger
 * tags:
 *   name: Order Details
 *   description: API endpoints for managing order details
 */

/**
 * @swagger
 * /api/order-details:
 *   get:
 *     summary: Returns all order details
 *     tags: [Order Details]
 *     responses:
 *       200:
 *         description: List of all order details
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/OrderDetail'
 *   post:
 *     summary: Create a new order detail
 *     tags: [Order Details]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/OrderDetail'
 *     responses:
 *       201:
 *         description: Order detail created successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/OrderDetail'
 *
 * /api/order-details/{id}:
 *   get:
 *     summary: Get an order detail by ID
 *     tags: [Order Details]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Order detail ID
 *     responses:
 *       200:
 *         description: Order detail found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/OrderDetail'
 *       404:
 *         description: Order detail not found
 *   put:
 *     summary: Update an order detail
 *     tags: [Order Details]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Order detail ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/OrderDetail'
 *     responses:
 *       200:
 *         description: Order detail updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/OrderDetail'
 *       404:
 *         description: Order detail not found
 *   delete:
 *     summary: Delete an order detail
 *     tags: [Order Details]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Order detail ID
 *     responses:
 *       204:
 *         description: Order detail deleted successfully
 *       404:
 *         description: Order detail not found
 */

import express from 'express';
import { OrderDetail } from '../models/orderDetail';
import { getOrderDetailsRepository } from '../repositories/orderDetailsRepo';
import { NotFoundError } from '../utils/errors';

const router = express.Router();

// Create a new order detail
router.post('/', async (req, res, next) => {
  try {
    const repo = await getOrderDetailsRepository();
    const newOrderDetail = await repo.create(req.body as Omit<OrderDetail, 'orderDetailId'>);
    res.status(201).json(newOrderDetail);
  } catch (error) {
    next(error);
  }
});

// Get all order details
router.get('/', async (req, res, next) => {
  try {
    const repo = await getOrderDetailsRepository();
    const orderDetails = await repo.findAll();
    res.json(orderDetails);
  } catch (error) {
    next(error);
  }
});

// Get an order detail by ID
router.get('/:id', async (req, res, next) => {
  try {
    const repo = await getOrderDetailsRepository();
    const orderDetail = await repo.findById(parseInt(req.params.id));
    if (orderDetail) {
      res.json(orderDetail);
    } else {
      res.status(404).send('Order detail not found');
    }
  } catch (error) {
    next(error);
  }
});

// Update an order detail by ID
router.put('/:id', async (req, res, next) => {
  try {
    const repo = await getOrderDetailsRepository();
    const updatedOrderDetail = await repo.update(parseInt(req.params.id), req.body);
    res.json(updatedOrderDetail);
  } catch (error) {
    if (error instanceof NotFoundError) {
      res.status(404).send('Order detail not found');
    } else {
      next(error);
    }
  }
});

// Delete an order detail by ID
router.delete('/:id', async (req, res, next) => {
  try {
    const repo = await getOrderDetailsRepository();
    await repo.delete(parseInt(req.params.id));
    res.status(204).send();
  } catch (error) {
    if (error instanceof NotFoundError) {
      res.status(404).send('Order detail not found');
    } else {
      next(error);
    }
  }
});

export default router;
