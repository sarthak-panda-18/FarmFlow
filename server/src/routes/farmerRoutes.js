const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/authMiddleware');
const { requireRole } = require('../middleware/roleMiddleware');

// POST /api/farmers/crops
router.post('/crops', requireAuth, requireRole('FARMER'), (req, res) => {
  res.status(501).json({
    success: false,
    message: 'Crop listing creation will be implemented in a future phase.',
  });
});

// GET /api/farmers/crops
router.get('/crops', requireAuth, requireRole('FARMER'), (req, res) => {
  res.status(501).json({
    success: false,
    message: 'Farmer crop listings retrieval will be implemented in a future phase.',
  });
});

// GET /api/farmers/recommendations
router.get('/recommendations', requireAuth, requireRole('FARMER'), (req, res) => {
  res.status(501).json({
    success: false,
    message: 'Farmer recommendations endpoint will be implemented in a future phase.',
  });
});

module.exports = router;
