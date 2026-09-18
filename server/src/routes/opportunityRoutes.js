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
  completeOpportunity,
} = require('../controllers/opportunityController');
const { requireAuth } = require('../middleware/authMiddleware');
const { requireRole } = require('../middleware/roleMiddleware');

router.use(requireAuth);

// Express Interest
router.post('/express-interest', requireRole('BUYER'), expressInterest);
router.post('/farmer-express-interest', requireRole('FARMER'), farmerExpressInterest);

// Discovery & Lists
router.get('/discover-crops', requireRole('BUYER'), getDiscoverableFarmerCrops);
router.get('/buyer-opportunities', requireRole('BUYER'), getBuyerOpportunities);
router.get('/farmer-opportunities', requireRole('FARMER'), getFarmerOpportunities);

// Single opportunity detail
router.get('/:id', getOpportunityById);

// Accept / Reject / Complete
router.post('/:id/accept', requireRole('FARMER'), acceptOpportunity);
router.post('/:id/reject', requireRole('FARMER'), rejectOpportunity);
router.post('/:id/complete', completeOpportunity);

module.exports = router;
