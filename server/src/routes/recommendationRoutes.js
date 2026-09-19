const express = require('express');
const router = express.Router();
const {
  getCropRecommendations,
  getFarmerRecommendations,
  getOpportunityRecommendations,
} = require('../controllers/recommendationController');
const { requireAuth } = require('../middleware/authMiddleware');
const { requireRole } = require('../middleware/roleMiddleware');

router.use(requireAuth);
router.use(requireRole('FARMER'));

// GET /api/recommendations/farmer - All recommendations for farmer's active crops
router.get('/farmer', getFarmerRecommendations);

// GET /api/recommendations/crop/:cropId - Recommendations for a specific crop
router.get('/crop/:cropId', getCropRecommendations);

// GET /api/recommendations/:cropId - Alias for direct crop ID route
router.get('/:cropId', (req, res, next) => {
  if (req.params.cropId === 'farmer') {
    return getFarmerRecommendations(req, res, next);
  }
  return getCropRecommendations(req, res, next);
});

// GET /api/recommendations/opportunity/:id - Recommendations for crop linked to opportunity
router.get('/opportunity/:id', getOpportunityRecommendations);

module.exports = router;
