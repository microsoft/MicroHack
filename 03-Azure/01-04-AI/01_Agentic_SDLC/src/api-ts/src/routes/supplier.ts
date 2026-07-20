/**
 * @swagger
 * tags:
 *   name: Suppliers
 *   description: API endpoints for managing suppliers
 */

/**
 * @swagger
 * /api/suppliers:
 *   get:
 *     summary: Returns all suppliers
 *     tags: [Suppliers]
 *     responses:
 *       200:
 *         description: List of all suppliers
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/Supplier'
 *   post:
 *     summary: Create a new supplier
 *     tags: [Suppliers]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Supplier'
 *     responses:
 *       201:
 *         description: Supplier created successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Supplier'
 *
 * /api/suppliers/{id}:
 *   get:
 *     summary: Get a supplier by ID
 *     tags: [Suppliers]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Supplier ID
 *     responses:
 *       200:
 *         description: Supplier found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Supplier'
 *       404:
 *         description: Supplier not found
 *   put:
 *     summary: Update a supplier
 *     tags: [Suppliers]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Supplier ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Supplier'
 *     responses:
 *       200:
 *         description: Supplier updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Supplier'
 *       404:
 *         description: Supplier not found
 *   delete:
 *     summary: Delete a supplier
 *     tags: [Suppliers]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Supplier ID
 *     responses:
 *       204:
 *         description: Supplier deleted successfully
 *       404:
 *         description: Supplier not found
 *
 * /api/suppliers/{id}/status:
 *   get:
 *     summary: Get the status of a supplier
 *     tags: [Suppliers]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Supplier ID
 *     responses:
 *       200:
 *         description: Supplier status
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                   enum: [INACTIVE, APPROVED, PENDING]
 *       404:
 *         description: Supplier not found
 */

import express from 'express';
import { Supplier } from '../models/supplier';
import { getSuppliersRepository } from '../repositories/suppliersRepo';
import { handleDatabaseError, NotFoundError } from '../utils/errors';

const router = express.Router();

// Create a new supplier
router.post('/', async (req, res, next) => {
  try {
    const repo = await getSuppliersRepository();
    const newSupplier = await repo.create(req.body as Omit<Supplier, 'supplierId'>);
    res.status(201).json(newSupplier);
  } catch (error) {
    next(error);
  }
});

// Get all suppliers
router.get('/', async (req, res, next) => {
  try {
    const repo = await getSuppliersRepository();
    const suppliers = await repo.findAll();
    res.json(suppliers);
  } catch (error) {
    next(error);
  }
});

// Get a supplier by ID
router.get('/:id', async (req, res, next) => {
  try {
    const repo = await getSuppliersRepository();
    const supplier = await repo.findById(parseInt(req.params.id));
    if (supplier) {
      res.json(supplier);
    } else {
      res.status(404).send('Supplier not found');
    }
  } catch (error) {
    next(error);
  }
});


// Update a supplier by ID
router.put('/:id', async (req, res, next) => {
  try {
    const repo = await getSuppliersRepository();
    const updatedSupplier = await repo.update(parseInt(req.params.id), req.body);
    res.json(updatedSupplier);
  } catch (error) {
    if (error instanceof NotFoundError) {
      res.status(404).send('Supplier not found');
    } else {
      next(error);
    }
  }
});

// Delete a supplier by ID
router.delete('/:id', async (req, res, next) => {
  try {
    const repo = await getSuppliersRepository();
    await repo.delete(parseInt(req.params.id));
    res.status(204).send();
  } catch (error) {
    if (error instanceof NotFoundError) {
      res.status(404).send('Supplier not found');
    } else {
      next(error);
    }
  }
});

// Get supplier status by ID
router.get('/:id/status', async (req, res, next) => {
  try {
    const repo = await getSuppliersRepository();
    const supplier = await repo.findById(parseInt(req.params.id));
    if (!supplier) {
      res.status(404).send('Supplier not found');
      return;
    }

    const status = processSupplierStatus(supplier);

    res.json({ status });
  } catch (error) {
    next(error);
  }
});

// Misleading indentation example
function processSupplierStatus(supplier: Supplier): string {
  if (supplier.active)
    console.log('Supplier is active');
    return 'APPROVED';

  if (supplier.verified)
    console.log('Supplier verified');
  console.log('Setting up account'); // This also appears conditional but always executes

  return 'PENDING';

}

export default router;
