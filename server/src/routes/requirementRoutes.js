const express = require('express');
const router = express.Router();
const {
  createRequirement,
  getMyRequirements,
  getRequirementById,
  updateRequirement,
  cancelRequirement,
  deleteRequirement,
} = require('../controllers/requirementController');
const { requireAuth } = require('../middleware/authMiddleware');
const { requireRole } = require('../middleware/roleMiddleware');
const { requireVerified } = require('../middleware/verificationMiddleware');

// All requirement management routes require Auth + BUYER role
router.use(requireAuth);
router.use(requireRole('BUYER'));

// Read operations
router.get('/my', getMyRequirements);
router.get('/:id', getRequirementById);

// Protected write operations require complete account verification (phoneVerified + VERIFIED)
router.post('/', requireVerified, createRequirement);
router.put('/:id', requireVerified, updateRequirement);
router.patch('/:id/cancel', requireVerified, cancelRequirement);
router.delete('/:id', requireVerified, deleteRequirement);

module.exports = router;
