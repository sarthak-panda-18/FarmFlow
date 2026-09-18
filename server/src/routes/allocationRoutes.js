const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/authMiddleware');

// POST /api/allocations/plan
router.post('/plan', requireAuth, (req, res) => {
  res.status(501).json({
    success: false,
    message: 'Partial quantity allocation optimization will be implemented in a future phase.',
  });
});

module.exports = router;
