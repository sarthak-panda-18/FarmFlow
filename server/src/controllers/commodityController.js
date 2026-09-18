const MarketPrice = require('../models/MarketPrice');

/**
 * @desc    Get unique commodities list from imported AGMARKNET dataset
 * @route   GET /api/commodities
 * @access  Public
 */
const getCommodities = async (req, res, next) => {
  try {
    const commodities = await MarketPrice.distinct('commodity');
    commodities.sort((a, b) => a.localeCompare(b));

    res.status(200).json({
      success: true,
      count: commodities.length,
      data: commodities,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get unique states list
 * @route   GET /api/commodities/states
 * @access  Public
 */
const getStates = async (req, res, next) => {
  try {
    const states = await MarketPrice.distinct('state');
    states.sort((a, b) => a.localeCompare(b));

    res.status(200).json({
      success: true,
      count: states.length,
      data: states,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get unique districts list (optional filter by state)
 * @route   GET /api/commodities/districts
 * @access  Public
 */
const getDistricts = async (req, res, next) => {
  try {
    const { state } = req.query;
    const filter = {};
    if (state && state.trim().length > 0) {
      filter.state = state.trim();
    }

    const districts = await MarketPrice.distinct('district', filter);
    districts.sort((a, b) => a.localeCompare(b));

    res.status(200).json({
      success: true,
      count: districts.length,
      data: districts,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get unique markets list (optional filter by district and state)
 * @route   GET /api/commodities/markets
 * @access  Public
 */
const getMarkets = async (req, res, next) => {
  try {
    const { state, district } = req.query;
    const filter = {};
    if (state && state.trim().length > 0) {
      filter.state = state.trim();
    }
    if (district && district.trim().length > 0) {
      filter.district = district.trim();
    }

    const markets = await MarketPrice.distinct('market', filter);
    markets.sort((a, b) => a.localeCompare(b));

    res.status(200).json({
      success: true,
      count: markets.length,
      data: markets,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get unique crop varieties for a commodity
 * @route   GET /api/commodities/varieties
 * @access  Public
 */
const getVarieties = async (req, res, next) => {
  try {
    const { commodity } = req.query;
    const filter = {};
    if (commodity && commodity.trim().length > 0) {
      filter.commodity = commodity.trim();
    }

    const varieties = await MarketPrice.distinct('variety', filter);
    varieties.sort((a, b) => a.localeCompare(b));

    res.status(200).json({
      success: true,
      count: varieties.length,
      data: varieties,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get unique quality grades for a commodity
 * @route   GET /api/commodities/grades
 * @access  Public
 */
const getGrades = async (req, res, next) => {
  try {
    const { commodity } = req.query;
    const filter = {};
    if (commodity && commodity.trim().length > 0) {
      filter.commodity = commodity.trim();
    }

    const grades = await MarketPrice.distinct('grade', filter);
    grades.sort((a, b) => a.localeCompare(b));

    res.status(200).json({
      success: true,
      count: grades.length,
      data: grades,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get agricultural categories with their mapped AGMARKNET commodities
 * @route   GET /api/commodities/categories
 * @access  Public
 */
const getCategories = async (req, res, next) => {
  try {
    const { CATEGORY_MAP } = require('../utils/commodityCategoryMapping');
    const categories = [
      { id: 'all', name: 'All Categories' },
      { id: 'vegetables', name: 'Vegetables', commodities: CATEGORY_MAP.vegetables },
      { id: 'pulses', name: 'Pulses', commodities: CATEGORY_MAP.pulses },
      { id: 'cereals', name: 'Cereals & Grains', commodities: CATEGORY_MAP.cereals },
      { id: 'fruits', name: 'Fruits', commodities: CATEGORY_MAP.fruits },
      { id: 'oilseeds', name: 'Oilseeds', commodities: CATEGORY_MAP.oilseeds },
      { id: 'commercial', name: 'Commercial Crops', commodities: CATEGORY_MAP.commercial },
    ];

    res.status(200).json({
      success: true,
      count: categories.length,
      data: categories,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getCommodities,
  getCategories,
  getStates,
  getDistricts,
  getMarkets,
  getVarieties,
  getGrades,
};
