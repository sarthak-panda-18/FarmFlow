const MarketPrice = require('../models/MarketPrice');
const { buildCommodityFilter } = require('../utils/commodityCategoryMapping');

/**
 * @desc    Get single reference market price for a crop/commodity
 * @route   GET /api/markets/reference-price
 * @access  Public
 */
const getReferencePrice = async (req, res, next) => {
  try {
    const { commodity, state, district, market } = req.query;

    if (!commodity || !commodity.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Commodity parameter is required',
      });
    }

    const filter = {};
    const commodityFilter = buildCommodityFilter(commodity);
    if (commodityFilter) {
      Object.assign(filter, commodityFilter);
    }

    if (state && state.trim()) {
      filter.state = { $regex: new RegExp(`^${state.trim()}$`, 'i') };
    }
    if (district && district.trim()) {
      filter.district = { $regex: new RegExp(`^${district.trim()}$`, 'i') };
    }
    if (market && market.trim()) {
      filter.market = { $regex: new RegExp(`^${market.trim()}$`, 'i') };
    }

    // Attempt to find exact matching location record first, then fallback to broader location
    let record = await MarketPrice.findOne(filter).sort({ date: -1 }).lean();

    // Fallback 1: Drop market filter if provided and not found
    if (!record && filter.market) {
      delete filter.market;
      record = await MarketPrice.findOne(filter).sort({ date: -1 }).lean();
    }

    // Fallback 2: Drop district filter if not found
    if (!record && filter.district) {
      delete filter.district;
      record = await MarketPrice.findOne(filter).sort({ date: -1 }).lean();
    }

    // Fallback 3: Drop state filter if not found
    if (!record && filter.state) {
      delete filter.state;
      record = await MarketPrice.findOne(filter).sort({ date: -1 }).lean();
    }

    if (!record) {
      return res.status(200).json({
        success: true,
        data: null,
        message: 'Market price unavailable',
      });
    }

    res.status(200).json({
      success: true,
      data: {
        id: record._id,
        commodity: record.commodity,
        variety: record.variety,
        grade: record.grade,
        modalPrice: record.modalPrice,
        referencePrice: record.modalPrice,
        minPrice: record.minPrice,
        maxPrice: record.maxPrice,
        unit: 'Quintal',
        state: record.state,
        district: record.district,
        market: record.market,
        date: record.date ? record.date.toISOString().split('T')[0] : null,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get paginated, filtered, sorted market prices
 * @route   GET /api/markets/prices
 * @access  Public
 */
const getMarketPrices = async (req, res, next) => {
  try {
    const {
      commodity,
      category,
      state,
      district,
      market,
      variety,
      grade,
      fromDate,
      toDate,
      page = 1,
      limit = 20,
      sortBy = 'date',
      order = 'desc',
    } = req.query;

    const filter = {};

    if (commodity && commodity.trim()) {
      const commFilter = buildCommodityFilter(commodity.trim());
      if (commFilter) Object.assign(filter, commFilter);
    } else if (category && category.trim()) {
      const catFilter = buildCommodityFilter(category.trim());
      if (catFilter) Object.assign(filter, catFilter);
    }

    if (state && state.trim()) {
      filter.state = { $regex: new RegExp(`^${state.trim()}$`, 'i') };
    }
    if (district && district.trim()) {
      filter.district = { $regex: new RegExp(`^${district.trim()}$`, 'i') };
    }
    if (market && market.trim()) {
      filter.market = { $regex: new RegExp(`^${market.trim()}$`, 'i') };
    }
    if (variety && variety.trim()) {
      filter.variety = variety.trim();
    }
    if (grade && grade.trim()) {
      filter.grade = grade.trim();
    }

    if (fromDate || toDate) {
      filter.date = {};
      if (fromDate) filter.date.$gte = new Date(fromDate);
      if (toDate) filter.date.$lte = new Date(toDate);
    }

    // Pagination bounds
    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    // Allowed sort fields whitelist
    const allowedSortFields = ['date', 'minPrice', 'maxPrice', 'modalPrice', 'commodity', 'market', 'state'];
    const sortField = allowedSortFields.includes(sortBy) ? sortBy : 'date';
    const sortOrder = order === 'asc' ? 1 : -1;
    const sortOptions = {};
    sortOptions[sortField] = sortOrder;

    const [total, records] = await Promise.all([
      MarketPrice.countDocuments(filter),
      MarketPrice.find(filter)
        .sort(sortOptions)
        .skip(skip)
        .limit(limitNum)
        .select('-__v')
        .lean(),
    ]);

    const formattedRecords = records.map((r) => ({
      id: r._id,
      state: r.state,
      district: r.district,
      market: r.market,
      commodity: r.commodity,
      variety: r.variety,
      grade: r.grade,
      minPrice: r.minPrice,
      maxPrice: r.maxPrice,
      modalPrice: r.modalPrice,
      date: r.date ? r.date.toISOString().split('T')[0] : null,
    }));

    res.status(200).json({
      success: true,
      page: pageNum,
      limit: limitNum,
      total,
      pages: Math.ceil(total / limitNum),
      data: formattedRecords,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Search markets, commodities, districts, and states
 * @route   GET /api/markets/search
 * @access  Public
 */
const searchMarkets = async (req, res, next) => {
  try {
    const { q, commodity, state, district, market, page = 1, limit = 20 } = req.query;
    const filter = {};

    if (q && q.trim()) {
      const qTerm = q.trim();
      const commFilter = buildCommodityFilter(qTerm);

      filter.$or = [
        commFilter ? commFilter : { commodity: new RegExp(qTerm, 'i') },
        { market: new RegExp(qTerm, 'i') },
        { district: new RegExp(qTerm, 'i') },
        { state: new RegExp(qTerm, 'i') },
      ];
    }

    if (commodity && commodity.trim()) {
      const commFilter = buildCommodityFilter(commodity.trim());
      if (commFilter) Object.assign(filter, commFilter);
    }

    if (state && state.trim()) {
      filter.state = new RegExp(state.trim(), 'i');
    }
    if (district && district.trim()) {
      filter.district = new RegExp(district.trim(), 'i');
    }
    if (market && market.trim()) {
      filter.market = new RegExp(market.trim(), 'i');
    }

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    const [total, records] = await Promise.all([
      MarketPrice.countDocuments(filter),
      MarketPrice.find(filter)
        .sort({ date: -1 })
        .skip(skip)
        .limit(limitNum)
        .lean(),
    ]);

    const formattedRecords = records.map((r) => ({
      id: r._id,
      state: r.state,
      district: r.district,
      market: r.market,
      commodity: r.commodity,
      variety: r.variety,
      grade: r.grade,
      minPrice: r.minPrice,
      maxPrice: r.maxPrice,
      modalPrice: r.modalPrice,
      date: r.date ? r.date.toISOString().split('T')[0] : null,
    }));

    res.status(200).json({
      success: true,
      page: pageNum,
      limit: limitNum,
      total,
      pages: Math.ceil(total / limitNum),
      data: formattedRecords,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get dataset statistics (calculated dynamically from MongoDB)
 * @route   GET /api/markets/stats
 * @access  Public
 */
const getMarketStats = async (req, res, next) => {
  try {
    const [
      totalRecords,
      uniqueCommodities,
      uniqueMarkets,
      uniqueStates,
      uniqueDistricts,
      dateRange,
    ] = await Promise.all([
      MarketPrice.countDocuments(),
      MarketPrice.distinct('commodity'),
      MarketPrice.distinct('market'),
      MarketPrice.distinct('state'),
      MarketPrice.distinct('district'),
      MarketPrice.aggregate([
        {
          $group: {
            _id: null,
            earliestDate: { $min: '$date' },
            latestDate: { $max: '$date' },
          },
        },
      ]),
    ]);

    const earliest = dateRange.length > 0 && dateRange[0].earliestDate ? dateRange[0].earliestDate.toISOString().split('T')[0] : null;
    const latest = dateRange.length > 0 && dateRange[0].latestDate ? dateRange[0].latestDate.toISOString().split('T')[0] : null;

    res.status(200).json({
      success: true,
      data: {
        totalRecords,
        uniqueCommodities: uniqueCommodities.length,
        uniqueMarkets: uniqueMarkets.length,
        uniqueStates: uniqueStates.length,
        uniqueDistricts: uniqueDistricts.length,
        earliestDate: earliest,
        latestDate: latest,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get historical prices for commodity / market for chart & trend analysis
 * @route   GET /api/markets/history
 * @access  Public
 */
const getMarketPriceHistory = async (req, res, next) => {
  try {
    const { commodity, state, district, market, limit = 30 } = req.query;

    if (!commodity || !commodity.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Commodity parameter is required',
      });
    }

    const filter = {};
    const commFilter = buildCommodityFilter(commodity.trim());
    if (commFilter) Object.assign(filter, commFilter);

    if (state && state.trim()) {
      filter.state = { $regex: new RegExp(`^${state.trim()}$`, 'i') };
    }
    if (district && district.trim()) {
      filter.district = { $regex: new RegExp(`^${district.trim()}$`, 'i') };
    }
    if (market && market.trim()) {
      filter.market = { $regex: new RegExp(`^${market.trim()}$`, 'i') };
    }

    const limitNum = Math.min(100, Math.max(5, parseInt(limit, 10) || 30));

    // Get latest records ordered chronologically for charts
    let records = await MarketPrice.find(filter)
      .sort({ date: -1 })
      .limit(limitNum)
      .select('commodity state district market minPrice maxPrice modalPrice date')
      .lean();

    // Fallback if specific market/district had no records
    if (records.length === 0 && filter.market) {
      delete filter.market;
      records = await MarketPrice.find(filter)
        .sort({ date: -1 })
        .limit(limitNum)
        .select('commodity state district market minPrice maxPrice modalPrice date')
        .lean();
    }
    if (records.length === 0 && filter.district) {
      delete filter.district;
      records = await MarketPrice.find(filter)
        .sort({ date: -1 })
        .limit(limitNum)
        .select('commodity state district market minPrice maxPrice modalPrice date')
        .lean();
    }
    if (records.length === 0 && filter.state) {
      delete filter.state;
      records = await MarketPrice.find(filter)
        .sort({ date: -1 })
        .limit(limitNum)
        .select('commodity state district market minPrice maxPrice modalPrice date')
        .lean();
    }

    // Sort ascending by date for chronological trend chart
    records.sort((a, b) => new Date(a.date) - new Date(b.date));

    const formatted = records.map((r) => ({
      id: r._id,
      commodity: r.commodity,
      state: r.state,
      district: r.district,
      market: r.market,
      minPrice: r.minPrice,
      maxPrice: r.maxPrice,
      modalPrice: r.modalPrice,
      date: r.date ? r.date.toISOString().split('T')[0] : null,
    }));

    res.status(200).json({
      success: true,
      count: formatted.length,
      data: formatted,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get latest prices for all commodities in a specific category (e.g. Vegetables, Pulses)
 * @route   GET /api/markets/category/:category
 * @access  Public
 */
const getCategoryPrices = async (req, res, next) => {
  try {
    const { category } = req.params;
    const { state, district } = req.query;

    if (!category || !category.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Category parameter is required',
      });
    }

    const { CATEGORY_MAP } = require('../utils/commodityCategoryMapping');
    const catKey = category.trim().toLowerCase();
    const commodities = CATEGORY_MAP[catKey];

    if (!commodities || commodities.length === 0) {
      return res.status(200).json({
        success: true,
        category: category.trim(),
        count: 0,
        data: [],
      });
    }

    // For each commodity in category, fetch the latest reference record
    const pricePromises = commodities.map(async (commodity) => {
      const filter = { commodity };
      if (state && state.trim()) {
        filter.state = { $regex: new RegExp(`^${state.trim()}$`, 'i') };
      }
      if (district && district.trim()) {
        filter.district = { $regex: new RegExp(`^${district.trim()}$`, 'i') };
      }

      let record = await MarketPrice.findOne(filter).sort({ date: -1 }).lean();
      if (!record && (filter.district || filter.state)) {
        record = await MarketPrice.findOne({ commodity }).sort({ date: -1 }).lean();
      }

      if (!record) return null;

      return {
        id: record._id,
        commodity: record.commodity,
        variety: record.variety,
        grade: record.grade,
        modalPrice: record.modalPrice,
        minPrice: record.minPrice,
        maxPrice: record.maxPrice,
        state: record.state,
        district: record.district,
        market: record.market,
        date: record.date ? record.date.toISOString().split('T')[0] : null,
      };
    });

    const results = (await Promise.all(pricePromises)).filter(Boolean);

    res.status(200).json({
      success: true,
      category: category.trim(),
      count: results.length,
      data: results,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getReferencePrice,
  getMarketPrices,
  getMarketPriceHistory,
  getCategoryPrices,
  searchMarkets,
  getMarketStats,
};

