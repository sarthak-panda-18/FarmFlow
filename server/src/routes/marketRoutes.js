const express = require('express');
const router = express.Router();
const {
  getReferencePrice,
  getMarketPrices,
  getMarketPriceHistory,
  getCategoryPrices,
  getMarketTrends,
  triggerMarketPriceAlerts,
  searchMarkets,
  getMarketStats,
} = require('../controllers/marketController');

// Public market price endpoints
router.get('/reference-price', getReferencePrice);
router.get('/latest', getReferencePrice);
router.get('/prices', getMarketPrices);
router.get('/trends', getMarketTrends);
router.post('/trigger-alerts', triggerMarketPriceAlerts);
router.get('/history', getMarketPriceHistory);
router.get('/category/:category', getCategoryPrices);
router.get('/search', searchMarkets);
router.get('/stats', getMarketStats);

module.exports = router;

