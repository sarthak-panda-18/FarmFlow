const mongoose = require('mongoose');
const User = require('../models/User');
const Crop = require('../models/Crop');
const BuyerRequirement = require('../models/BuyerRequirement');
const MarketPrice = require('../models/MarketPrice');
const {
  calculateHaversineDistance,
  buildGoogleMapsUrl,
} = require('../utils/geoUtils');
const { buildCommodityFilter } = require('../utils/commodityCategoryMapping');
const { getPricePrediction } = require('../services/mlService');
const { getUserRatingStats } = require('../utils/ratingHelper');
const { resolvePartyLocation } = require('../utils/locationResolver');

const DEFAULT_MAX_MATCH_DISTANCE_KM = 100;
const STANDARD_TRANSPORT_RATE_PER_KM = 25; // ₹25/km standard road transport rate

/**
 * Safely converts an ObjectId, string, or entity reference to a string without throwing on null/undefined.
 */
const safeId = (val, fallback = '') => {
  if (val === null || val === undefined) return fallback;
  if (typeof val === 'object' && val._id) return String(val._id);
  return String(val);
};

/**
 * Safely formats a Date or date string to YYYY-MM-DD or returns null.
 */
const safeIsoDate = (dateVal) => {
  if (!dateVal) return null;
  if (dateVal instanceof Date) {
    return !isNaN(dateVal.getTime()) ? dateVal.toISOString().split('T')[0] : null;
  }
  const parsed = new Date(dateVal);
  return !isNaN(parsed.getTime()) ? parsed.toISOString().split('T')[0] : null;
};

/**
 * Normalizes quantity to Quintals for standard agricultural comparison
 */
const toQuintals = (qty, unit) => {
  const q = Number(qty) || 0;
  const u = (unit ? String(unit) : 'quintal').toLowerCase().trim();
  if (u === 'kg') return q / 100;
  if (u === 'tonne' || u === 'ton' || u === 't') return q * 10;
  return q; // quintal
};

/**
 * Normalizes price to per-Quintal for standard agricultural comparison
 */
const toPricePerQuintal = (price, unit) => {
  const p = Number(price) || 0;
  const u = (unit ? String(unit) : 'quintal').toLowerCase().trim();
  if (u === 'kg') return p * 100;
  if (u === 'tonne' || u === 'ton' || u === 't') return p / 10;
  return p; // already per quintal
};

/**
 * Calculates transparent multi-factor compatibility score (0 - 100%)
 */
const calculateMatchScore = ({
  farmerQty = 0,
  buyerQty = 0,
  farmerPricePerQ = 0,
  buyerPricePerQ = 0,
  marketRefPricePerQ = 0,
  distanceKm = null,
  maxDistanceKm = DEFAULT_MAX_MATCH_DISTANCE_KM,
  harvestDate = null,
  requiredByDate = null,
} = {}) => {
  let score = 0;
  const breakdown = {};

  const fQty = Number(farmerQty) || 0;
  const bQty = Number(buyerQty) || 0;
  const fPrice = Number(farmerPricePerQ) || 0;
  const bPrice = Number(buyerPricePerQ) || 0;
  const refPricePerQ = Number(marketRefPricePerQ) || 0;

  // 1. Quantity Compatibility (Max 30 pts)
  const minQty = Math.min(fQty, bQty);
  const maxQty = Math.max(fQty, bQty);
  const qtyRatio = maxQty > 0 ? minQty / maxQty : 0;
  const qtyScore = Math.round(qtyRatio * 30 * 10) / 10;
  score += qtyScore;
  breakdown.quantityScore = qtyScore;
  breakdown.quantityMatch = fQty >= bQty ? 'FULL_MATCH' : 'PARTIAL_MATCH';

  // 2. Price Compatibility (Max 35 pts)
  let priceScore = 0;
  const refPrice = refPricePerQ > 0 ? refPricePerQ : Math.max(fPrice, bPrice, 1);

  if (bPrice >= fPrice && fPrice > 0) {
    priceScore = 35;
    breakdown.priceStatus = 'COMPATIBLE_BUYER_HIGH';
  } else if (fPrice > 0 && bPrice > 0) {
    const diff = fPrice - bPrice;
    const diffRatio = diff / refPrice;
    priceScore = Math.max(0, Math.round((1 - Math.min(1, diffRatio)) * 35 * 10) / 10);
    breakdown.priceStatus = diffRatio <= 0.1 ? 'COMPATIBLE_CLOSE' : 'PRICE_GAP';
  } else {
    priceScore = 20;
    breakdown.priceStatus = 'PRICE_NOT_SPECIFIED';
  }
  score += priceScore;
  breakdown.priceScore = priceScore;

  // 3. Distance Score (Max 25 pts)
  let distScore = 12.5; // neutral default if distance unknown
  if (distanceKm !== null && distanceKm !== undefined) {
    const dMax = Number(maxDistanceKm) || DEFAULT_MAX_MATCH_DISTANCE_KM;
    const distRatio = Math.max(0, 1 - distanceKm / dMax);
    distScore = Math.round(distRatio * 25 * 10) / 10;
    breakdown.distanceStatus =
      distanceKm <= dMax ? 'WITHIN_PREFERRED_RANGE' : 'OUTSIDE_PREFERRED_RANGE';
  } else {
    breakdown.distanceStatus = 'DISTANCE_UNKNOWN';
  }
  score += distScore;
  breakdown.distanceScore = distScore;

  // 4. Timing / Date Compatibility (Max 10 pts)
  let dateScore = 10;
  if (harvestDate && requiredByDate) {
    const hDate = new Date(harvestDate);
    const rDate = new Date(requiredByDate);
    if (!isNaN(hDate.getTime()) && !isNaN(rDate.getTime())) {
      if (hDate <= rDate) {
        dateScore = 10;
        breakdown.dateStatus = 'READY_ON_TIME';
      } else {
        const diffDays = Math.ceil((hDate - rDate) / (1000 * 60 * 60 * 24));
        dateScore = diffDays <= 7 ? 5 : 0;
        breakdown.dateStatus = diffDays <= 7 ? 'SLIGHT_DELAY' : 'HARVEST_AFTER_REQUIRED';
      }
    } else {
      breakdown.dateStatus = 'DATE_NOT_SPECIFIED';
    }
  } else {
    breakdown.dateStatus = 'DATE_NOT_SPECIFIED';
  }
  score += dateScore;
  breakdown.dateScore = dateScore;

  const totalScore = Math.min(100, Math.max(0, Math.round(score)));

  let compatibilityLabel = 'Partial Match';
  if (totalScore >= 75) {
    compatibilityLabel = 'High Compatibility';
  } else if (totalScore >= 50) {
    compatibilityLabel = 'Moderate Compatibility';
  }

  return {
    score: totalScore,
    compatibility: compatibilityLabel,
    breakdown,
  };
};

/**
 * Generates true, transparent data-driven explanation bullets for the top recommended buyer.
 */
const generateDataDrivenReasons = (topBuyer, allBuyers = []) => {
  if (!topBuyer) return [];

  const reasons = [];
  const netVal = Number(topBuyer.netValue) || 0;
  const netValPerQ = Number(topBuyer.netValuePerQ) || 0;
  const expectedPrice = Number(topBuyer.buyerExpectedPrice) || 0;

  // 1. Net economic outcome
  reasons.push(
    `Highest expected net value of ₹${netVal.toLocaleString('en-IN')} (₹${netValPerQ.toLocaleString('en-IN')}/Quintal)`
  );

  // 2. Selling price / ML Comparison
  if (
    topBuyer.mlPrediction &&
    topBuyer.mlPrediction.available &&
    topBuyer.mlPrediction.comparison === 'ABOVE_FORECAST'
  ) {
    const predPrice = Number(topBuyer.mlPrediction.predictedPrice) || 0;
    reasons.push(
      `Offered price of ₹${expectedPrice}/Q exceeds ML market benchmark (₹${predPrice}/Q)`
    );
  } else {
    const otherSellingPrices = allBuyers
      .filter((b) => b && b.id !== topBuyer.id && typeof b.buyerExpectedPrice === 'number')
      .map((b) => b.buyerExpectedPrice);
    if (
      otherSellingPrices.length > 0 &&
      expectedPrice >= Math.max(...otherSellingPrices)
    ) {
      reasons.push(
        `Highest offered price of ₹${expectedPrice.toLocaleString('en-IN')}/Quintal`
      );
    } else {
      reasons.push(
        `Competitive offered price of ₹${expectedPrice.toLocaleString('en-IN')}/Quintal`
      );
    }
  }

  // 3. Transportation cost & distance
  if (topBuyer.isTransportAvailable && topBuyer.transportationCost !== null && topBuyer.transportationCost !== undefined) {
    const tCost = Number(topBuyer.transportationCost) || 0;
    const otherBuyersWithTransport = allBuyers.filter(
      (b) => b && b.id !== topBuyer.id && b.isTransportAvailable && b.transportationCost !== null && b.transportationCost !== undefined
    );

    const distStr = topBuyer.distanceKm != null ? ` (${Number(topBuyer.distanceKm).toFixed(1)} km away)` : '';

    if (otherBuyersWithTransport.length > 0) {
      const minOtherTransport = Math.min(...otherBuyersWithTransport.map((b) => Number(b.transportationCost) || 0));
      if (tCost <= minOtherTransport) {
        reasons.push(`Lowest transportation cost of ₹${tCost.toLocaleString('en-IN')}${distStr}`);
      } else {
        reasons.push(`Estimated transportation cost: ₹${tCost.toLocaleString('en-IN')}${distStr}`);
      }
    } else {
      reasons.push(`Estimated transportation cost: ₹${tCost.toLocaleString('en-IN')}${distStr}`);
    }
  }

  // 4. Quantity capability
  const farmerAvail = Number(topBuyer.farmerAvailableQty) || 0;
  const buyerReq = Number(topBuyer.buyerRequiredQty) || 0;
  if (farmerAvail >= buyerReq && buyerReq > 0) {
    reasons.push(`Full lot purchase matching ${buyerReq} Quintals demanded`);
  } else {
    reasons.push(`Can absorb available supply of ${farmerAvail} Quintals`);
  }

  // 5. Trust / Rating
  const buyerAvgRating = Number(topBuyer.buyerRating?.averageRating ?? topBuyer.buyerRating?.rating) || 0;
  const buyerRatingsCount = Number(topBuyer.buyerRating?.totalRatings ?? topBuyer.buyerRating?.ratingCount) || 0;
  if (buyerRatingsCount > 0 && buyerAvgRating >= 4.0) {
    reasons.push(
      `Verified buyer with ${buyerAvgRating.toFixed(1)}★ rating (${buyerRatingsCount} verified reviews)`
    );
  }

  return reasons;
};

/**
 * Deterministically sorts matched buyers by Net Value descending.
 * Tie-breakers: 1. Higher match score, 2. Lower transport cost, 3. Shorter distance, 4. Better buyer rating
 */
const sortMatchedBuyerRecommendations = (buyers) => {
  return [...buyers].sort((a, b) => {
    // 1. Complete transport data prioritized if net values are otherwise tied
    if (a.isTransportAvailable && !b.isTransportAvailable) return -1;
    if (!a.isTransportAvailable && b.isTransportAvailable) return 1;

    // 2. Primary: Expected Net Value (descending)
    const netValA = Number(a?.netValue) || 0;
    const netValB = Number(b?.netValue) || 0;
    if (netValB !== netValA) {
      return netValB - netValA;
    }

    // 3. Secondary Tie-breaker: Match Compatibility Score
    const scoreA = Number(a?.matchScore) || 0;
    const scoreB = Number(b?.matchScore) || 0;
    if (scoreB !== scoreA) {
      return scoreB - scoreA;
    }

    // 4. Tertiary Tie-breaker: Lower Transportation Cost
    const tA = (a.transportationCost !== null && a.transportationCost !== undefined) ? Number(a.transportationCost) : Infinity;
    const tB = (b.transportationCost !== null && b.transportationCost !== undefined) ? Number(b.transportationCost) : Infinity;
    if (tA !== tB) {
      return tA - tB;
    }

    // 5. Quaternary Tie-breaker: Shorter Distance
    const dA = (a.distanceKm !== null && a.distanceKm !== undefined) ? Number(a.distanceKm) : Infinity;
    const dB = (b.distanceKm !== null && b.distanceKm !== undefined) ? Number(b.distanceKm) : Infinity;
    if (dA !== dB) {
      return dA - dB;
    }

    // 6. Quinary Tie-breaker: Buyer Rating
    const rA = Number(a.buyerRating?.averageRating ?? a.buyerRating?.rating) || 0;
    const rB = Number(b.buyerRating?.averageRating ?? b.buyerRating?.rating) || 0;
    if (rB !== rA) {
      return rB - rA;
    }

    // 7. Stable fallback
    return String(a?.id || '').localeCompare(String(b?.id || ''));
  });
};

/**
 * @desc    Get matching Buyer requirements for authenticated Farmer's active crops
 * @route   GET /api/matches/farmer
 * @access  Private (FARMER)
 */
const getFarmerMatches = async (req, res, next) => {
  try {
    const farmerId = req.user?.id || req.user?.userId || req.user?._id;
    if (!farmerId) {
      return res.status(401).json({ success: false, message: 'Unauthorized: User not identified' });
    }

    const {
      cropId,
      maxDistance,
      commodity,
      limit = 50,
    } = req.query;
    const maxDistKm = (maxDistance !== undefined && maxDistance !== null && maxDistance !== '')
      ? Number(maxDistance)
      : null;

    // Fetch Farmer profile to get location
    const farmer = await User.findById(farmerId).lean();
    if (!farmer) {
      return res
        .status(404)
        .json({ success: false, message: 'Farmer account not found' });
    }

    // Fetch Farmer's active crops
    const cropQuery = { farmerId, status: 'AVAILABLE' };
    if (
      cropId &&
      cropId !== 'undefined' &&
      cropId !== 'null' &&
      mongoose.Types.ObjectId.isValid(cropId)
    ) {
      cropQuery._id = cropId;
    }
    if (commodity && typeof commodity === 'string' && commodity.trim()) {
      const commFilter = buildCommodityFilter(commodity.trim());
      if (commFilter) Object.assign(cropQuery, commFilter);
    }

    const farmerCrops = await Crop.find(cropQuery).lean();
    if (!farmerCrops || farmerCrops.length === 0) {
      return res.status(200).json({
        success: true,
        count: 0,
        totalMatches: 0,
        message: 'No active crops found for matching',
        data: [],
      });
    }

    // Get today's date for expiration checking
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const matches = [];

    // For each active crop, find matching active buyer requirements
    for (const crop of farmerCrops) {
      if (!crop) continue;
      const comm = crop.commodity ? String(crop.commodity).trim() : '';
      const commFilter = comm ? buildCommodityFilter(comm) : null;
      const reqQuery = {
        status: 'ACTIVE',
        requiredByDate: { $gte: today },
      };
      if (farmerId) {
        reqQuery.buyerId = { $ne: farmerId };
      }
      if (commFilter) Object.assign(reqQuery, commFilter);

      const buyerReqs = await BuyerRequirement.find(reqQuery)
        .populate('buyerId', 'name businessName location address city district state phone')
        .lean();

      // Fetch AGMARKNET reference market price for this commodity
      const refPriceRecord = await MarketPrice.findOne(commFilter || (comm ? { commodity: comm } : {}))
        .sort({ date: -1 })
        .lean();

      const marketModalPrice = (refPriceRecord && typeof refPriceRecord.modalPrice === 'number') ? refPriceRecord.modalPrice : 0;

      // Query ML model price prediction as an advisory recommendation signal
      let mlPrediction = null;
      if (crop.commodity) {
        try {
          const mlRes = await getPricePrediction({
            commodity: crop.commodity,
            state: crop.state || undefined,
            district: crop.district || undefined,
            market: crop.market || undefined,
            variety: crop.variety || undefined,
            grade: crop.grade || undefined,
            date: safeIsoDate(crop.harvestDate) || undefined,
          });

          if (mlRes && mlRes.success && mlRes.prediction) {
            mlPrediction = mlRes.prediction;
          }
        } catch (mlErr) {
          mlPrediction = null;
        }
      }

      // Resolve Farmer pickup location accurately
      const farmerLoc = resolvePartyLocation({
        user: farmer,
        crop,
        partyLabel: `${farmer?.name || 'Farmer'} (Pickup Location)`,
      });

      const farmerQty = toQuintals(crop.quantity, crop.quantityUnit);
      const farmerPricePerQ = toPricePerQuintal(crop.expectedPrice, crop.quantityUnit);

      for (const reqItem of buyerReqs) {
        if (!reqItem) continue;
        const buyer = reqItem.buyerId && typeof reqItem.buyerId === 'object' ? reqItem.buyerId : null;

        // Resolve Buyer delivery location accurately
        const buyerLoc = resolvePartyLocation({
          user: buyer,
          requirement: reqItem,
          partyLabel: `${buyer?.businessName || buyer?.name || 'Buyer'} (Delivery Location)`,
        });

        let distanceKm = null;
        if (
          farmerLoc?.latitude !== null &&
          farmerLoc?.latitude !== undefined &&
          farmerLoc?.longitude !== null &&
          farmerLoc?.longitude !== undefined &&
          buyerLoc?.latitude !== null &&
          buyerLoc?.latitude !== undefined &&
          buyerLoc?.longitude !== null &&
          buyerLoc?.longitude !== undefined
        ) {
          distanceKm = calculateHaversineDistance(
            farmerLoc.latitude,
            farmerLoc.longitude,
            buyerLoc.latitude,
            buyerLoc.longitude
          );
        }

        // Apply Max Distance filter: only filter out when distance is known and exceeds maxDistKm
        if (maxDistKm !== null && !isNaN(maxDistKm) && distanceKm !== null && distanceKm !== undefined && distanceKm > maxDistKm) {
          continue;
        }

        const buyerQty = toQuintals(reqItem.quantity, reqItem.quantityUnit);
        const buyerPricePerQ = toPricePerQuintal(reqItem.offeredPrice, reqItem.quantityUnit);

        const matchScoreResult = calculateMatchScore({
          farmerQty,
          buyerQty,
          farmerPricePerQ,
          buyerPricePerQ,
          marketRefPricePerQ: marketModalPrice,
          distanceKm,
          maxDistanceKm: maxDistKm || DEFAULT_MAX_MATCH_DISTANCE_KM,
          harvestDate: crop.harvestDate,
          requiredByDate: reqItem.requiredByDate,
        });

        // Economic calculation: Quantity basis strictly in Quintals
        const matchedQty = Math.min(farmerQty, buyerQty) > 0 ? Math.min(farmerQty, buyerQty) : farmerQty;
        const totalSellingPrice = Math.round(matchedQty * buyerPricePerQ * 100) / 100;

        // Transportation cost handling
        let transportationCost = null;
        let isTransportAvailable = false;

        if (
          reqItem.transportCost !== undefined &&
          reqItem.transportCost !== null &&
          Number(reqItem.transportCost) >= 0
        ) {
          transportationCost = Number(reqItem.transportCost);
          isTransportAvailable = true;
        } else if (distanceKm !== null && distanceKm !== undefined) {
          // Standard road transport rate (₹25/km)
          transportationCost = Math.round(distanceKm * STANDARD_TRANSPORT_RATE_PER_KM * 100) / 100;
          isTransportAvailable = true;
        } else {
          transportationCost = null;
          isTransportAvailable = false;
        }

        // Other costs (loading, packaging, handling, APMC fees)
        const otherCosts = Math.max(0, Number(reqItem.otherCosts) || 0);

        // Net Economic Value = Selling Price - Transportation Cost - Other Costs
        const actualTransport = isTransportAvailable && transportationCost !== null ? transportationCost : 0;
        const totalNetValue = Math.round((totalSellingPrice - actualTransport - otherCosts) * 100) / 100;
        const netValuePerQ = matchedQty > 0 ? Math.round((totalNetValue / matchedQty) * 100) / 100 : buyerPricePerQ;

        // Fetch Buyer rating stats
        let buyerRating = { rating: 0, averageRating: 0, ratingCount: 0, totalRatings: 0, displayRating: 'New Buyer', label: 'No ratings yet' };
        if (buyer?._id) {
          try {
            const rawStats = await getUserRatingStats(buyer._id, 'BUYER');
            if (rawStats) {
              const avg = Number(rawStats.rating ?? rawStats.averageRating) || 0;
              const count = Number(rawStats.ratingCount ?? rawStats.totalRatings) || 0;
              buyerRating = {
                rating: avg,
                averageRating: avg,
                ratingCount: count,
                totalRatings: count,
                displayRating: rawStats.displayRating || (count > 0 ? `${avg} ⭐` : 'New Buyer'),
                label: rawStats.label || (count > 0 ? `${avg} (${count} ratings)` : 'No ratings yet'),
              };
            }
          } catch (_) {
            // Keep default rating object
          }
        }

        // ML signal comparison
        let mlSignal = null;
        if (mlPrediction && mlPrediction.predictedPrice > 0) {
          const diff = buyerPricePerQ - mlPrediction.predictedPrice;
          const diffPct = (diff / mlPrediction.predictedPrice) * 100;
          let comparison = 'AT_FORECAST';
          if (diffPct >= 2.5) comparison = 'ABOVE_FORECAST';
          else if (diffPct <= -2.5) comparison = 'BELOW_FORECAST';

          mlSignal = {
            available: true,
            predictedPrice: mlPrediction.predictedPrice,
            formattedPrice:
              mlPrediction.formattedPrice ||
              `₹${Math.round(mlPrediction.predictedPrice).toLocaleString('en-IN')} / Quintal`,
            unit: 'Quintal',
            difference: Math.round(diff * 100) / 100,
            differencePercent: Math.round(diffPct * 10) / 10,
            comparison,
          };
        } else {
          mlSignal = {
            available: false,
            predictedPrice: null,
            comparison: 'UNAVAILABLE',
          };
        }

        const buyerName = buyer?.businessName || buyer?.name || 'Verified Buyer';
        const cropIdStr = safeId(crop._id);
        const reqIdStr = safeId(reqItem._id);
        const buyerIdStr = safeId(buyer?._id || reqItem.buyerId);

        matches.push({
          id: `FMATCH_${cropIdStr}_${reqIdStr}`,
          cropId: cropIdStr,
          cropName: crop.cropName || crop.commodity || 'Crop',
          commodity: crop.commodity || 'N/A',
          farmerAvailableQty: crop.quantity || 0,
          farmerUnit: crop.quantityUnit || 'quintal',
          farmerExpectedPrice: crop.expectedPrice || 0,
          requirementId: reqIdStr,
          buyerId: buyerIdStr,
          buyerName,
          buyerBusinessName: buyer?.businessName || '',
          buyerRequiredQty: reqItem.quantity || 0,
          buyerUnit: reqItem.quantityUnit || 'quintal',
          buyerExpectedPrice: reqItem.offeredPrice || 0,
          marketReferencePrice: marketModalPrice,
          marketReferenceUnit: 'Quintal',
          marketSource: refPriceRecord
            ? `${refPriceRecord.market || ''} (${refPriceRecord.state || ''})`.trim() || 'AGMARKNET Dataset'
            : 'AGMARKNET Dataset',
          distanceKm,
          location: buyerLoc.address || (reqItem.district && reqItem.state ? `${reqItem.district}, ${reqItem.state}` : 'Location not specified'),
          buyerCoordinates:
            buyerLoc.latitude !== null && buyerLoc.longitude !== null
              ? { latitude: buyerLoc.latitude, longitude: buyerLoc.longitude }
              : null,
          googleMapsUrl: buyerLoc.mapsUrl || '',
          requiredByDate: safeIsoDate(reqItem.requiredByDate),
          harvestDate: safeIsoDate(crop.harvestDate),
          matchScore: matchScoreResult.score,
          compatibility: matchScoreResult.compatibility,
          breakdown: matchScoreResult.breakdown,
          // Economic calculations
          unitPrice: buyerPricePerQ,
          matchedQty,
          sellingPrice: totalSellingPrice,
          transportationCost,
          isTransportAvailable,
          otherCosts,
          netValue: totalNetValue,
          netValuePerQ,
          buyerRating,
          mlPrediction: mlSignal,
          status: 'POTENTIAL',
        });
      }
    }

    // Deterministic ranking by Net Value
    const sortedMatches = sortMatchedBuyerRecommendations(matches);

    // Apply ranking and data-driven explanations
    const rankedMatches = sortedMatches.map((match, idx) => {
      const isTop = idx === 0;
      return {
        ...match,
        rank: idx + 1,
        isRecommended: isTop,
        recommendationReasons: isTop
          ? generateDataDrivenReasons(match, sortedMatches)
          : [],
      };
    });

    const paginated = rankedMatches.slice(0, parseInt(limit, 10) || 50);

    res.status(200).json({
      success: true,
      count: paginated.length,
      totalMatches: rankedMatches.length,
      maxDistanceKm: maxDistKm,
      data: paginated,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get matching Farmer crops for authenticated Buyer's active requirements
 * @route   GET /api/matches/buyer
 * @access  Private (BUYER)
 */
const getBuyerMatches = async (req, res, next) => {
  try {
    const buyerId = req.user?.id || req.user?.userId || req.user?._id;
    if (!buyerId) {
      return res.status(401).json({ success: false, message: 'Unauthorized: User not identified' });
    }

    const {
      requirementId,
      maxDistance,
      commodity,
      limit = 50,
    } = req.query;
    const maxDistKm = (maxDistance !== undefined && maxDistance !== null && maxDistance !== '')
      ? Number(maxDistance)
      : null;

    const buyer = await User.findById(buyerId).lean();
    if (!buyer) {
      return res
        .status(404)
        .json({ success: false, message: 'Buyer account not found' });
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const reqQuery = { buyerId, status: 'ACTIVE', requiredByDate: { $gte: today } };
    if (
      requirementId &&
      requirementId !== 'undefined' &&
      requirementId !== 'null' &&
      mongoose.Types.ObjectId.isValid(requirementId)
    ) {
      reqQuery._id = requirementId;
    }
    if (commodity && typeof commodity === 'string' && commodity.trim()) {
      const commFilter = buildCommodityFilter(commodity.trim());
      if (commFilter) Object.assign(reqQuery, commFilter);
    }

    const buyerReqs = await BuyerRequirement.find(reqQuery).lean();
    if (!buyerReqs || buyerReqs.length === 0) {
      return res.status(200).json({
        success: true,
        count: 0,
        totalMatches: 0,
        message: 'No active buyer requirements found for matching',
        data: [],
      });
    }

    const matches = [];

    for (const reqItem of buyerReqs) {
      if (!reqItem) continue;
      const comm = reqItem.commodity ? String(reqItem.commodity).trim() : '';
      const commFilter = comm ? buildCommodityFilter(comm) : null;
      const cropQuery = {
        status: 'AVAILABLE',
      };
      if (buyerId) {
        cropQuery.farmerId = { $ne: buyerId };
      }
      if (commFilter) Object.assign(cropQuery, commFilter);

      const availableCrops = await Crop.find(cropQuery)
        .populate('farmerId', 'name location address city district state phone')
        .lean();

      const refPriceRecord = await MarketPrice.findOne(commFilter || (comm ? { commodity: comm } : {}))
        .sort({ date: -1 })
        .lean();

      const marketModalPrice = (refPriceRecord && typeof refPriceRecord.modalPrice === 'number') ? refPriceRecord.modalPrice : 0;

      const buyerLoc = resolvePartyLocation({
        user: buyer,
        requirement: reqItem,
        partyLabel: `${buyer.businessName || buyer.name || 'Buyer'} (Delivery Location)`,
      });

      const buyerQty = toQuintals(reqItem.quantity, reqItem.quantityUnit);
      const buyerPricePerQ = toPricePerQuintal(reqItem.offeredPrice, reqItem.quantityUnit);

      for (const crop of availableCrops) {
        if (!crop) continue;
        const farmer = crop.farmerId && typeof crop.farmerId === 'object' ? crop.farmerId : null;
        const farmerLoc = resolvePartyLocation({
          user: farmer,
          crop,
          partyLabel: `${farmer?.name || 'Farmer'} (Pickup Location)`,
        });

        let distanceKm = null;
        if (
          buyerLoc?.latitude !== null &&
          buyerLoc?.latitude !== undefined &&
          buyerLoc?.longitude !== null &&
          buyerLoc?.longitude !== undefined &&
          farmerLoc?.latitude !== null &&
          farmerLoc?.latitude !== undefined &&
          farmerLoc?.longitude !== null &&
          farmerLoc?.longitude !== undefined
        ) {
          distanceKm = calculateHaversineDistance(
            buyerLoc.latitude,
            buyerLoc.longitude,
            farmerLoc.latitude,
            farmerLoc.longitude
          );
        }

        // Apply Max Distance filter: only filter out when distance is known and exceeds maxDistKm
        if (maxDistKm !== null && !isNaN(maxDistKm) && distanceKm !== null && distanceKm !== undefined && distanceKm > maxDistKm) {
          continue;
        }

        const farmerQty = toQuintals(crop.quantity, crop.quantityUnit);
        const farmerPricePerQ = toPricePerQuintal(crop.expectedPrice, crop.quantityUnit);

        const matchScoreResult = calculateMatchScore({
          farmerQty,
          buyerQty,
          farmerPricePerQ,
          buyerPricePerQ,
          marketRefPricePerQ: marketModalPrice,
          distanceKm,
          maxDistanceKm: maxDistKm || DEFAULT_MAX_MATCH_DISTANCE_KM,
          harvestDate: crop.harvestDate,
          requiredByDate: reqItem.requiredByDate,
        });

        const farmerName = farmer?.name || 'Verified Farmer';
        const cropIdStr = safeId(crop._id);
        const reqIdStr = safeId(reqItem._id);
        const farmerIdStr = safeId(farmer?._id || crop.farmerId);

        matches.push({
          id: `BMATCH_${reqIdStr}_${cropIdStr}`,
          requirementId: reqIdStr,
          commodity: reqItem.commodity || crop.commodity || 'N/A',
          buyerRequiredQty: reqItem.quantity || 0,
          buyerUnit: reqItem.quantityUnit || 'quintal',
          buyerExpectedPrice: reqItem.offeredPrice || 0,
          cropId: cropIdStr,
          cropName: crop.cropName || crop.commodity || 'Crop',
          farmerId: farmerIdStr,
          farmerName,
          farmerAvailableQty: crop.quantity || 0,
          farmerUnit: crop.quantityUnit || 'quintal',
          farmerExpectedPrice: crop.expectedPrice || 0,
          marketReferencePrice: marketModalPrice,
          marketReferenceUnit: 'Quintal',
          marketSource: refPriceRecord
            ? `${refPriceRecord.market || ''} (${refPriceRecord.state || ''})`.trim() || 'AGMARKNET Dataset'
            : 'AGMARKNET Dataset',
          distanceKm,
          location: farmerLoc.address || (crop.district && crop.state ? `${crop.district}, ${crop.state}` : 'Location not specified'),
          farmerCoordinates:
            farmerLoc.latitude !== null && farmerLoc.longitude !== null
              ? { latitude: farmerLoc.latitude, longitude: farmerLoc.longitude }
              : null,
          googleMapsUrl: farmerLoc.mapsUrl || '',
          harvestDate: safeIsoDate(crop.harvestDate),
          requiredByDate: safeIsoDate(reqItem.requiredByDate),
          matchScore: matchScoreResult.score,
          compatibility: matchScoreResult.compatibility,
          breakdown: matchScoreResult.breakdown,
          status: 'POTENTIAL',
        });
      }
    }

    matches.sort((a, b) => {
      const scoreA = Number(a?.matchScore) || 0;
      const scoreB = Number(b?.matchScore) || 0;
      if (scoreB !== scoreA) return scoreB - scoreA;
      if (a.distanceKm !== null && a.distanceKm !== undefined && b.distanceKm !== null && b.distanceKm !== undefined) {
        return Number(a.distanceKm) - Number(b.distanceKm);
      }
      return String(a?.id || '').localeCompare(String(b?.id || ''));
    });

    const paginated = matches.slice(0, parseInt(limit, 10) || 50);

    res.status(200).json({
      success: true,
      count: paginated.length,
      totalMatches: matches.length,
      maxDistanceKm: maxDistKm,
      data: paginated,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get single match details by ID
 * @route   GET /api/matches/:id
 * @access  Private
 */
const getMatchDetails = async (req, res, next) => {
  try {
    const { id } = req.params;
    if (!id || typeof id !== 'string') {
      return res.status(400).json({ success: false, message: 'Invalid match ID' });
    }

    const parts = id.split('_');
    if (parts.length < 3) {
      return res
        .status(400)
        .json({ success: false, message: 'Invalid match ID format' });
    }

    const isFarmerOrigin = parts[0] === 'FMATCH';
    const cropId = isFarmerOrigin ? parts[1] : parts[2];
    const reqId = isFarmerOrigin ? parts[2] : parts[1];

    if (!mongoose.Types.ObjectId.isValid(cropId) || !mongoose.Types.ObjectId.isValid(reqId)) {
      return res.status(400).json({ success: false, message: 'Invalid ID in match key' });
    }

    const [crop, reqItem] = await Promise.all([
      Crop.findById(cropId).populate('farmerId', 'name location address city district state phone'),
      BuyerRequirement.findById(reqId).populate('buyerId', 'name businessName location address city district state phone'),
    ]);

    if (!crop || !reqItem) {
      return res.status(404).json({
        success: false,
        message: 'Crop or Requirement not found for this match',
      });
    }

    const comm = crop.commodity ? String(crop.commodity).trim() : '';
    const refPriceRecord = await MarketPrice.findOne(comm ? { commodity: comm } : {})
      .sort({ date: -1 })
      .lean();

    const marketModalPrice = (refPriceRecord && typeof refPriceRecord.modalPrice === 'number') ? refPriceRecord.modalPrice : 0;

    const farmerLoc = resolvePartyLocation({
      user: crop.farmerId,
      crop,
      partyLabel: `${crop.farmerId?.name || 'Farmer'} (Pickup Location)`,
    });

    const buyerLoc = resolvePartyLocation({
      user: reqItem.buyerId,
      requirement: reqItem,
      partyLabel: `${reqItem.buyerId?.businessName || reqItem.buyerId?.name || 'Buyer'} (Delivery Location)`,
    });

    let distanceKm = null;
    if (
      farmerLoc?.latitude !== null &&
      farmerLoc?.latitude !== undefined &&
      farmerLoc?.longitude !== null &&
      farmerLoc?.longitude !== undefined &&
      buyerLoc?.latitude !== null &&
      buyerLoc?.latitude !== undefined &&
      buyerLoc?.longitude !== null &&
      buyerLoc?.longitude !== undefined
    ) {
      distanceKm = calculateHaversineDistance(
        farmerLoc.latitude,
        farmerLoc.longitude,
        buyerLoc.latitude,
        buyerLoc.longitude
      );
    }

    const farmerQty = toQuintals(crop.quantity, crop.quantityUnit);
    const buyerQty = toQuintals(reqItem.quantity, reqItem.quantityUnit);
    const farmerPricePerQ = toPricePerQuintal(crop.expectedPrice, crop.quantityUnit);
    const buyerPricePerQ = toPricePerQuintal(reqItem.offeredPrice, reqItem.quantityUnit);

    const matchScoreResult = calculateMatchScore({
      farmerQty,
      buyerQty,
      farmerPricePerQ,
      buyerPricePerQ,
      marketRefPricePerQ: marketModalPrice,
      distanceKm,
      harvestDate: crop.harvestDate,
      requiredByDate: reqItem.requiredByDate,
    });

    const isFarmer = req.user?.role === 'FARMER';
    const targetLoc = isFarmer ? buyerLoc : farmerLoc;

    res.status(200).json({
      success: true,
      data: {
        id,
        crop: {
          id: safeId(crop._id),
          commodity: crop.commodity || '',
          cropName: crop.cropName || '',
          variety: crop.variety || '',
          grade: crop.grade || '',
          quantity: crop.quantity || 0,
          quantityUnit: crop.quantityUnit || 'quintal',
          expectedPrice: crop.expectedPrice || 0,
          harvestDate: safeIsoDate(crop.harvestDate),
          farmerName: crop.farmerId?.name || 'Farmer',
          state: crop.state || '',
          district: crop.district || '',
        },
        requirement: {
          id: safeId(reqItem._id),
          commodity: reqItem.commodity || '',
          quantity: reqItem.quantity || 0,
          quantityUnit: reqItem.quantityUnit || 'quintal',
          offeredPrice: reqItem.offeredPrice || 0,
          requiredByDate: safeIsoDate(reqItem.requiredByDate),
          buyerName: reqItem.buyerId?.businessName || reqItem.buyerId?.name || 'Buyer',
          state: reqItem.state || '',
          district: reqItem.district || '',
        },
        marketReferencePrice: marketModalPrice,
        marketSource: refPriceRecord
          ? `${refPriceRecord.market || ''} (${refPriceRecord.state || ''})`.trim() || 'AGMARKNET Dataset'
          : 'AGMARKNET Dataset',
        distanceKm,
        googleMapsUrl: targetLoc?.mapsUrl || '',
        matchScore: matchScoreResult.score,
        compatibility: matchScoreResult.compatibility,
        breakdown: matchScoreResult.breakdown,
        status: 'POTENTIAL',
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getFarmerMatches,
  getBuyerMatches,
  getMatchDetails,
  calculateMatchScore,
  generateDataDrivenReasons,
  sortMatchedBuyerRecommendations,
  toQuintals,
  toPricePerQuintal,
  safeId,
  safeIsoDate,
};
