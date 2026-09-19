const express = require('express');
const router = express.Router();
const dealController = require('../controllers/dealController');
const { requireAuth } = require('../middleware/authMiddleware');
const { requireRole } = require('../middleware/roleMiddleware');

// All deal routes require authentication
router.use(requireAuth);

// Deal Creation & Listings
router.post('/', dealController.createDealFromOpportunity);
router.get('/farmer', requireRole('FARMER', 'ADMIN'), dealController.getFarmerDeals);
router.get('/buyer', requireRole('BUYER', 'ADMIN'), dealController.getBuyerDeals);

// Single Deal Details & Official Deal Agreement
router.get('/:id', dealController.getDealById);
router.get('/:id/agreement', dealController.getDealAgreement);
router.post('/:id/agreement/accept', dealController.acceptDealAgreement);
router.patch('/:id/agreement', dealController.updateDealAgreement);

// Deal Lifecycle & Logistics
router.patch('/:id/status', dealController.updateDealStatus);
router.patch('/:id/logistics', dealController.updateDealLogistics);
router.patch('/:id/deliver', dealController.markDelivered);
router.patch('/:id/cancel', dealController.cancelDeal);

// Phase 10: External Payment Status Tracking
router.patch('/:id/payment/report', dealController.reportPaymentMade);
router.post('/:id/payment/report', dealController.reportPaymentMade);
router.patch('/:id/payment/confirm', dealController.confirmPaymentReceived);
router.post('/:id/payment/confirm', dealController.confirmPaymentReceived);
router.patch('/:id/payment/dispute', dealController.disputePayment);
router.post('/:id/payment/dispute', dealController.disputePayment);

// Phase 12: Ratings & Feedback
router.post('/:id/ratings', dealController.rateDeal);

module.exports = router;
