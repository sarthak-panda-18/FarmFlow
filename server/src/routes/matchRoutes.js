const express = require('express');
const router = express.Router();
const {
  getFarmerMatches,
  getBuyerMatches,
  getMatchDetails,
} = require('../controllers/matchingController');
const { requireAuth } = require('../middleware/authMiddleware');
const { requireRole } = require('../middleware/roleMiddleware');

router.use(requireAuth);

// Farmer matches
router.get('/farmer', requireRole('FARMER'), getFarmerMatches);

// Buyer matches
router.get('/buyer', requireRole('BUYER'), getBuyerMatches);

// Single match detail
router.get('/:id', getMatchDetails);

module.exports = router;
