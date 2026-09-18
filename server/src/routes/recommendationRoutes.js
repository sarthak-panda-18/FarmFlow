const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/authMiddleware');

// GET /api/recommendations/:cropId
router.get('/:cropId', requireAuth, (req, res) => {
  res.status(501).json({
    success: false,
    message: 'Recommendation calculation engine will be implemented in a future phase.',
  });
});

module.exports = router;
