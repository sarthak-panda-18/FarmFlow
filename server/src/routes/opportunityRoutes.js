const express = require('express');
const router = express.Router();
const {
  expressInterest,
  farmerExpressInterest,
  getFarmerOpportunities,
  getBuyerOpportunities,
  getDiscoverableFarmerCrops,
  getOpportunityById,
  acceptOpportunity,
  rejectOpportunity,
  cancelOpportunity,
  completeOpportunity,
} = require('../controllers/opportunityController');
const { requireAuth } = require('../middleware/authMiddleware');
const { requireRole } = require('../middleware/roleMiddleware');

router.use(requireAuth);

// Express Interest
router.post('/', requireRole('BUYER'), expressInterest);
router.post('/express-interest', requireRole('BUYER'), expressInterest);
router.post('/farmer-express-interest', requireRole('FARMER'), farmerExpressInterest);

// Discovery & Lists
router.get('/discover-crops', requireRole('BUYER'), getDiscoverableFarmerCrops);
router.get('/buyer-opportunities', requireRole('BUYER'), getBuyerOpportunities);
router.get('/farmer-opportunities', requireRole('FARMER'), getFarmerOpportunities);

const {
  getCropRecommendations,
  getOpportunityRecommendations,
} = require('../controllers/recommendationController');

// Single opportunity detail
router.get('/:id', getOpportunityById);

// Recommendations
router.get('/crop/:cropId/recommendations', requireRole('FARMER'), getCropRecommendations);
router.get('/:id/recommendations', requireRole('FARMER'), getOpportunityRecommendations);

// Accept
router.post('/:id/accept', acceptOpportunity);
router.patch('/:id/accept', acceptOpportunity);

// Reject
router.post('/:id/reject', rejectOpportunity);
router.patch('/:id/reject', rejectOpportunity);

// Cancel
router.post('/:id/cancel', cancelOpportunity);
router.patch('/:id/cancel', cancelOpportunity);

// Complete
router.post('/:id/complete', completeOpportunity);
router.patch('/:id/complete', completeOpportunity);

module.exports = router;

