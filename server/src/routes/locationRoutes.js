const express = require('express');
const router = express.Router();
const {
  updateMyLocation,
  getMyLocation,
  getNearbyFarmers,
  getNearbyBuyers,
  getNearbyMarkets,
} = require('../controllers/locationController');
const { requireAuth } = require('../middleware/authMiddleware');

// User location endpoints
router.get('/me', requireAuth, getMyLocation);
router.put('/', requireAuth, updateMyLocation);

// Geospatial Discovery
router.get('/nearby-farmers', requireAuth, getNearbyFarmers);
router.get('/nearby-buyers', requireAuth, getNearbyBuyers);
router.get('/nearby-markets', getNearbyMarkets);

module.exports = router;
