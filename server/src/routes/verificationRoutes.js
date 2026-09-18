const express = require('express');
const router = express.Router();
const {
  submitFarmerVerification,
  submitBuyerVerification,
  getVerificationStatus,
  adminUpdateStatus,
} = require('../controllers/verificationController');
const { requireAuth } = require('../middleware/authMiddleware');
const { requireRole } = require('../middleware/roleMiddleware');

// All verification routes require authentication
router.use(requireAuth);

router.get('/status', getVerificationStatus);
router.post('/farmer', requireRole('FARMER'), submitFarmerVerification);
router.post('/buyer', requireRole('BUYER'), submitBuyerVerification);
router.patch('/admin/user/:userId/status', adminUpdateStatus);

module.exports = router;
