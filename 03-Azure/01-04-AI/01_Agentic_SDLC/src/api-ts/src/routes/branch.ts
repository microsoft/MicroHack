/**
 * @swagger
 * tags:
 *   name: Branches
 *   description: API endpoints for managing branches
 */

/**
 * @swagger
 * /api/branches:
 *   get:
 *     summary: Returns all branches
 *     tags: [Branches]
 *     responses:
 *       200:
 *         description: List of all branches
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/Branch'
 *   post:
 *     summary: Create a new branch
 *     tags: [Branches]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Branch'
 *     responses:
 *       201:
 *         description: Branch created successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Branch'
 *
 * /api/branches/{id}:
 *   get:
 *     summary: Get a branch by ID
 *     tags: [Branches]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Branch ID
 *     responses:
 *       200:
 *         description: Branch found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Branch'
 *       404:
 *         description: Branch not found
 *   put:
 *     summary: Update a branch
 *     tags: [Branches]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Branch ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Branch'
 *     responses:
 *       200:
 *         description: Branch updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Branch'
 *       404:
 *         description: Branch not found
 *   delete:
 *     summary: Delete a branch
 *     tags: [Branches]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Branch ID
 *     responses:
 *       204:
 *         description: Branch deleted successfully
 *       404:
 *         description: Branch not found
 */

import express from 'express';
import { Branch } from '../models/branch';
import { getBranchesRepository } from '../repositories/branchesRepo';
import { NotFoundError } from '../utils/errors';

const router = express.Router();

// Create a new branch
router.post('/', async (req, res, next) => {
  try {
    const repo = await getBranchesRepository();
    const newBranch = await repo.create(req.body as Omit<Branch, 'branchId'>);
    res.status(201).json(newBranch);
  } catch (error) {
    next(error);
  }
});

// Get all branches
router.get('/', async (req, res, next) => {
  try {
    const repo = await getBranchesRepository();
    const branches = await repo.findAll();
    res.json(branches);
  } catch (error) {
    next(error);
  }
});

// Get a branch by ID
router.get('/:id', async (req, res, next) => {
  try {
    const repo = await getBranchesRepository();
    const branch = await repo.findById(parseInt(req.params.id));
    if (branch) {
      res.json(branch);
    } else {
      res.status(404).send('Branch not found');
    }
  } catch (error) {
    next(error);
  }
});

// Update a branch by ID
router.put('/:id', async (req, res, next) => {
  try {
    const repo = await getBranchesRepository();
    const updatedBranch = await repo.update(parseInt(req.params.id), req.body);
    res.json(updatedBranch);
  } catch (error) {
    if (error instanceof NotFoundError) {
      res.status(404).send('Branch not found');
    } else {
      next(error);
    }
  }
});

// Delete a branch by ID
router.delete('/:id', async (req, res, next) => {
  try {
    const repo = await getBranchesRepository();
    await repo.delete(parseInt(req.params.id));
    res.status(204).send();
  } catch (error) {
    if (error instanceof NotFoundError) {
      res.status(404).send('Branch not found');
    } else {
      next(error);
    }
  }
});

export default router;
