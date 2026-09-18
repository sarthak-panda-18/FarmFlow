const express = require('express');
const router = express.Router();
const {
  createCrop,
  getMyCrops,
  getCropById,
  updateCrop,
  deleteCrop,
} = require('../controllers/cropController');
const { requireAuth } = require('../middleware/authMiddleware');
const { requireRole } = require('../middleware/roleMiddleware');
const { requireVerified } = require('../middleware/verificationMiddleware');

// All crop management routes require Auth + FARMER role
router.use(requireAuth);
router.use(requireRole('FARMER'));

// Read operations
router.get('/my', getMyCrops);
router.get('/:id', getCropById);

// Protected write operations require complete account verification (phoneVerified + VERIFIED)
router.post('/', requireVerified, createCrop);
router.put('/:id', requireVerified, updateCrop);
router.delete('/:id', requireVerified, deleteCrop);

module.exports = router;
