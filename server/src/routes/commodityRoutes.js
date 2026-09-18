const express = require('express');
const router = express.Router();
const {
  getCommodities,
  getCategories,
  getStates,
  getDistricts,
  getMarkets,
  getVarieties,
  getGrades,
} = require('../controllers/commodityController');

// Commodity & Location Catalog Endpoints
router.get('/', getCommodities);
router.get('/categories', getCategories);
router.get('/states', getStates);
router.get('/districts', getDistricts);
router.get('/markets', getMarkets);
router.get('/varieties', getVarieties);
router.get('/grades', getGrades);

// ML Crop Name matching placeholder
router.post('/predict-name', (req, res) => {
  res.status(501).json({
    success: false,
    message: 'ML crop-name prediction endpoint will be implemented in Phase 4.',
  });
});

module.exports = router;
