const express = require('express');
const router = express.Router();
const { rateBuyer, rateFarmer, getUserRating } = require('../controllers/ratingController');
const { requireAuth } = require('../middleware/authMiddleware');
const { requireRole } = require('../middleware/roleMiddleware');

// Public rating stats lookup
router.get('/user/:id', getUserRating);

// Protected rating endpoints
router.post('/farmer-to-buyer', requireAuth, requireRole('FARMER'), rateBuyer);
router.post('/buyer-to-farmer', requireAuth, requireRole('BUYER'), rateFarmer);

module.exports = router;
