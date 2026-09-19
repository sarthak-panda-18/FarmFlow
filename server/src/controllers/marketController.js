const MarketPrice = require('../models/MarketPrice');
const Crop = require('../models/Crop');
const BuyerRequirement = require('../models/BuyerRequirement');
const Notification = require('../models/Notification');
const { buildCommodityFilter } = require('../utils/commodityCategoryMapping');
const { getPricePrediction, checkMLHealth } = require('../services/mlService');

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

/**
 * @desc    Get market price trends comparing Current vs Previous observation with ±5% threshold calculation
 * @route   GET /api/markets/trends
 * @access  Public
 */
const getMarketTrends = async (req, res, next) => {
  try {
    const { commodity, category, state, district, market } = req.query;
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

    // Get list of distinct commodities matching filter
    const distinctCommodities = await MarketPrice.distinct('commodity', filter);

    const trends = [];

    for (const comm of distinctCommodities) {
      const commQuery = { ...filter, commodity: comm };
      // Fetch latest 2 chronological observations for this crop/market
      const observations = await MarketPrice.find(commQuery)
        .sort({ date: -1 })
        .limit(2)
        .lean();

      if (observations.length === 0) continue;

      const current = observations[0];
      const previous = observations.length > 1 ? observations[1] : null;

      const currentPrice = current.modalPrice;
      const previousPrice = previous ? previous.modalPrice : currentPrice;

      let percentageChange = 0;
      if (previous && previousPrice > 0) {
        percentageChange = Math.round(((currentPrice - previousPrice) / previousPrice) * 100 * 10) / 10;
      }

      const direction = percentageChange > 0 ? 'UP' : (percentageChange < 0 ? 'DOWN' : 'STABLE');
      const isAlertThresholdMet = Math.abs(percentageChange) >= 5.0;

      trends.push({
        commodity: current.commodity,
        variety: current.variety,
        grade: current.grade,
        market: current.market,
        district: current.district,
        state: current.state,
        currentPrice,
        previousPrice,
        priceDifference: currentPrice - previousPrice,
        percentageChange,
        percentageChangeFormatted: `${percentageChange >= 0 ? '+' : ''}${percentageChange.toFixed(1)}%`,
        direction,
        isAlertThresholdMet,
        unit: 'Quintal',
        priceUnit: '₹ / Quintal',
        currentDate: current.date ? current.date.toISOString().split('T')[0] : null,
        previousDate: previous && previous.date ? previous.date.toISOString().split('T')[0] : null,
      });
    }

    res.status(200).json({
      success: true,
      count: trends.length,
      data: trends,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Process & Trigger Market Price ±5% Alerts for relevant Farmers and Buyers
 * @route   POST /api/markets/trigger-alerts
 * @access  Public / Internal Cron
 */
const triggerMarketPriceAlerts = async (req, res, next) => {
  try {
    const { commodity } = req.body || {};
    let commodities = [];

    if (commodity && commodity.trim()) {
      commodities = [commodity.trim()];
    } else {
      const [fComms, bComms] = await Promise.all([
        Crop.find({ status: 'AVAILABLE' }).distinct('commodity'),
        BuyerRequirement.find({ status: 'ACTIVE' }).distinct('commodity'),
      ]);
      commodities = Array.from(new Set([...fComms, ...bComms]));
      if (commodities.length === 0) {
        commodities = await MarketPrice.distinct('commodity');
      }
    }

    const triggeredAlerts = [];

    for (const comm of commodities) {
      const markets = await MarketPrice.distinct('market', { commodity: comm });

      for (const mkt of markets) {
        const obs = await MarketPrice.find({ commodity: comm, market: mkt })
          .sort({ date: -1 })
          .limit(2)
          .lean();

        if (obs.length < 2) continue;

        const current = obs[0];
        const previous = obs[1];

        const currPrice = current.modalPrice;
        const prevPrice = previous.modalPrice;

        if (!prevPrice || prevPrice <= 0) continue;

        const pctChange = ((currPrice - prevPrice) / prevPrice) * 100;
        const absPct = Math.abs(pctChange);

        // THRESHOLD RULE: Strictly ±5% or more
        if (absPct < 5.0) continue;

        const formattedPct = `${pctChange >= 0 ? '+' : ''}${pctChange.toFixed(1)}%`;
        const directionWord = pctChange > 0 ? 'increased' : 'decreased';
        const dateStr = current.date ? current.date.toISOString().split('T')[0] : 'today';

        // Idempotent alert key to prevent duplicate notifications
        const alertKey = `MARKET_ALERT_${comm.toUpperCase()}_${mkt.toUpperCase()}_${dateStr}_${currPrice}`;

        // Find relevant Farmers with active crops for this commodity
        const relevantFarmers = await Crop.find({
          commodity: new RegExp(`^${comm.trim()}$`, 'i'),
          status: 'AVAILABLE',
        }).distinct('farmerId');

        // Find relevant Buyers with active requirements for this commodity
        const relevantBuyers = await BuyerRequirement.find({
          commodity: new RegExp(`^${comm.trim()}$`, 'i'),
          status: 'ACTIVE',
        }).distinct('buyerId');

        const alertMessage = `${comm} market price ${directionWord} by ${absPct.toFixed(1)}%.\n\nCurrent market reference price:\n₹${currPrice.toLocaleString('en-IN')} / Quintal\n\nPrevious market reference price:\n₹${prevPrice.toLocaleString('en-IN')} / Quintal`;

        // Dispatch to Farmers
        for (const fId of relevantFarmers) {
          const userAlertKey = `${alertKey}_FARMER_${fId}`;
          const exists = await Notification.findOne({ alertKey: userAlertKey });
          if (!exists) {
            await Notification.create({
              userId: fId,
              recipientRole: 'FARMER',
              type: 'MARKET_PRICE_ALERT',
              title: `Market Alert: ${comm} ${formattedPct}`,
              message: alertMessage,
              crop: comm,
              alertKey: userAlertKey,
              metadata: {
                commodity: comm,
                market: mkt,
                currentPrice: currPrice,
                previousPrice: prevPrice,
                percentageChange: pctChange,
                direction: pctChange > 0 ? 'UP' : 'DOWN',
                unit: 'Quintal',
              },
            });
            triggeredAlerts.push({ userId: fId, role: 'FARMER', commodity: comm, percentageChange: formattedPct });
          }
        }

        // Dispatch to Buyers
        for (const bId of relevantBuyers) {
          const userAlertKey = `${alertKey}_BUYER_${bId}`;
          const exists = await Notification.findOne({ alertKey: userAlertKey });
          if (!exists) {
            await Notification.create({
              userId: bId,
              recipientRole: 'BUYER',
              type: 'MARKET_PRICE_ALERT',
              title: `Market Alert: ${comm} ${formattedPct}`,
              message: alertMessage,
              crop: comm,
              alertKey: userAlertKey,
              metadata: {
                commodity: comm,
                market: mkt,
                currentPrice: currPrice,
                previousPrice: prevPrice,
                percentageChange: pctChange,
                direction: pctChange > 0 ? 'UP' : 'DOWN',
                unit: 'Quintal',
              },
            });
            triggeredAlerts.push({ userId: bId, role: 'BUYER', commodity: comm, percentageChange: formattedPct });
          }
        }
      }
    }

    res.status(200).json({
      success: true,
      message: `Processed market price alerts. Generated ${triggeredAlerts.length} notifications.`,
      triggeredCount: triggeredAlerts.length,
      alerts: triggeredAlerts,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get ML Price Prediction combined with actual market reference rate & trend
 * @route   GET /api/markets/prediction
 * @access  Public
 */
const getMarketPrediction = async (req, res, next) => {
  try {
    const { commodity, state, district, market, variety, grade, date } = req.query;

    if (!commodity || !commodity.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Commodity parameter is required for price prediction',
      });
    }

    const commName = commodity.trim();

    // 1. Fetch current actual reference market price from database
    const filter = {};
    const commFilter = buildCommodityFilter(commName);
    if (commFilter) Object.assign(filter, commFilter);

    if (state && state.trim()) filter.state = { $regex: new RegExp(`^${state.trim()}$`, 'i') };
    if (district && district.trim()) filter.district = { $regex: new RegExp(`^${district.trim()}$`, 'i') };
    if (market && market.trim()) filter.market = { $regex: new RegExp(`^${market.trim()}$`, 'i') };

    let actualRecord = await MarketPrice.findOne(filter).sort({ date: -1 }).lean();

    // Fallback if specific market/district not found
    if (!actualRecord && filter.market) {
      delete filter.market;
      actualRecord = await MarketPrice.findOne(filter).sort({ date: -1 }).lean();
    }
    if (!actualRecord && filter.district) {
      delete filter.district;
      actualRecord = await MarketPrice.findOne(filter).sort({ date: -1 }).lean();
    }
    if (!actualRecord && filter.state) {
      delete filter.state;
      actualRecord = await MarketPrice.findOne(filter).sort({ date: -1 }).lean();
    }

    const currentActualPrice = actualRecord ? actualRecord.modalPrice : null;

    // 2. Call Python FastAPI ML prediction service
    const predictionResult = await getPricePrediction({
      commodity: commName,
      state: state || actualRecord?.state,
      district: district || actualRecord?.district,
      market: market || actualRecord?.market,
      variety: variety || actualRecord?.variety,
      grade: grade || actualRecord?.grade,
      date,
    });

    if (!predictionResult.available || !predictionResult.success || !predictionResult.prediction) {
      // Graceful fallback response when ML service is offline
      return res.status(200).json({
        success: true,
        available: false,
        message: predictionResult.message || 'Market prediction is currently unavailable.',
        data: {
          commodity: commName,
          actualPrice: currentActualPrice,
          actualPriceUnit: 'Quintal',
          predictedPrice: null,
          predictedChangePercent: null,
          trend: 'UNAVAILABLE',
          isMlAvailable: false,
        },
      });
    }

    const predData = predictionResult.prediction;
    const predictedPrice = predData.predictedPrice;

    // 3. Compute predicted change percentage and trend relative to actual current market price
    let predictedChangePercent = null;
    let trend = 'STABLE';

    if (currentActualPrice !== null && currentActualPrice > 0) {
      predictedChangePercent =
        Math.round((((predictedPrice - currentActualPrice) / currentActualPrice) * 100) * 100) / 100;
      if (predictedChangePercent >= 1.0) {
        trend = 'INCREASING';
      } else if (predictedChangePercent <= -1.0) {
        trend = 'DECREASING';
      } else {
        trend = 'STABLE';
      }
    }

    res.status(200).json({
      success: true,
      available: true,
      data: {
        commodity: commName,
        state: predData.state,
        district: predData.district,
        market: predData.market,
        variety: predData.variety,
        grade: predData.grade,
        targetDate: predData.targetDate,
        actualPrice: currentActualPrice,
        actualPriceFormatted: currentActualPrice ? `₹${currentActualPrice.toLocaleString()} / Quintal` : null,
        predictedPrice,
        predictedPriceFormatted: `₹${predictedPrice.toLocaleString()} / Quintal`,
        unit: 'Quintal',
        predictedChangePercent,
        trend,
        isMlAvailable: true,
        modelVersion: predData.modelVersion,
      },
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
  getMarketTrends,
  triggerMarketPriceAlerts,
  searchMarkets,
  getMarketStats,
  getMarketPrediction,
};

