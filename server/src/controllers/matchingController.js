const User = require('../models/User');
const Crop = require('../models/Crop');
const BuyerRequirement = require('../models/BuyerRequirement');
const MarketPrice = require('../models/MarketPrice');
const {
  calculateHaversineDistance,
  buildGoogleMapsUrl,
} = require('../utils/geoUtils');
const { buildCommodityFilter } = require('../utils/commodityCategoryMapping');

const DEFAULT_MAX_MATCH_DISTANCE_KM = 100;

/**
 * Normalizes quantity to Quintals for standard agricultural comparison
 */
const toQuintals = (qty, unit) => {
  const q = Number(qty) || 0;
  const u = (unit || 'quintal').toLowerCase().trim();
  if (u === 'kg') return q / 100;
  if (u === 'tonne' || u === 'ton' || u === 't') return q * 10;
  return q; // quintal
};

/**
 * Normalizes price to per-Quintal for standard agricultural comparison
 */
const toPricePerQuintal = (price, unit) => {
  const p = Number(price) || 0;
  const u = (unit || 'quintal').toLowerCase().trim();
  if (u === 'kg') return p * 100;
  if (u === 'tonne' || u === 'ton' || u === 't') return p / 10;
  return p; // already per quintal
};

/**
 * Calculates transparent multi-factor compatibility score (0 - 100%)
 */
const calculateMatchScore = ({
  farmerQty,
  buyerQty,
  farmerPricePerQ,
  buyerPricePerQ,
  marketRefPricePerQ,
  distanceKm,
  maxDistanceKm,
  harvestDate,
  requiredByDate,
}) => {
  let score = 0;
  const breakdown = {};

  // 1. Quantity Compatibility (Max 30 pts)
  const minQty = Math.min(farmerQty, buyerQty);
  const maxQty = Math.max(farmerQty, buyerQty);
  const qtyRatio = maxQty > 0 ? minQty / maxQty : 0;
  const qtyScore = Math.round(qtyRatio * 30 * 10) / 10;
  score += qtyScore;
  breakdown.quantityScore = qtyScore;
  breakdown.quantityMatch =
    farmerQty >= buyerQty
      ? 'FULL_MATCH'
      : 'PARTIAL_MATCH';

  // 2. Price Compatibility (Max 35 pts)
  let priceScore = 0;
  const refPrice = marketRefPricePerQ > 0 ? marketRefPricePerQ : Math.max(farmerPricePerQ, buyerPricePerQ, 1);

  if (buyerPricePerQ >= farmerPricePerQ && farmerPricePerQ > 0) {
    // Buyer is offering at or above Farmer's expectation - ideal match
    priceScore = 35;
    breakdown.priceStatus = 'COMPATIBLE_BUYER_HIGH';
  } else if (farmerPricePerQ > 0 && buyerPricePerQ > 0) {
    const diff = farmerPricePerQ - buyerPricePerQ;
    const diffRatio = diff / refPrice;
    priceScore = Math.max(0, Math.round((1 - Math.min(1, diffRatio)) * 35 * 10) / 10);
    breakdown.priceStatus = diffRatio <= 0.1 ? 'COMPATIBLE_CLOSE' : 'PRICE_GAP';
  } else {
    // One or both prices 0/unspecified - neutral
    priceScore = 20;
    breakdown.priceStatus = 'PRICE_NOT_SPECIFIED';
  }
  score += priceScore;
  breakdown.priceScore = priceScore;

  // 3. Distance Score (Max 25 pts)
  let distScore = 12.5; // neutral default if distance unknown
  if (distanceKm !== null && distanceKm !== undefined) {
    const dMax = maxDistanceKm || DEFAULT_MAX_MATCH_DISTANCE_KM;
    const distRatio = Math.max(0, 1 - distanceKm / dMax);
    distScore = Math.round(distRatio * 25 * 10) / 10;
    breakdown.distanceStatus = distanceKm <= dMax ? 'WITHIN_PREFERRED_RANGE' : 'OUTSIDE_PREFERRED_RANGE';
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
 * @desc    Get matching Buyer requirements for authenticated Farmer's active crops
 * @route   GET /api/matches/farmer
 * @access  Private (FARMER)
 */
const getFarmerMatches = async (req, res, next) => {
  try {
    const farmerId = req.user.id;
    const { cropId, maxDistance = DEFAULT_MAX_MATCH_DISTANCE_KM, commodity, limit = 50 } = req.query;
    const maxDistKm = Number(maxDistance) || DEFAULT_MAX_MATCH_DISTANCE_KM;

    // Fetch Farmer profile to get location
    const farmer = await User.findById(farmerId).lean();
    if (!farmer) {
      return res.status(404).json({ success: false, message: 'Farmer account not found' });
    }

    const farmerCoords = farmer.location?.coordinates?.length === 2
      ? { lng: farmer.location.coordinates[0], lat: farmer.location.coordinates[1] }
      : null;

    // Fetch Farmer's active crops
    const cropQuery = { farmerId, status: 'AVAILABLE' };
    if (cropId) cropQuery._id = cropId;
    if (commodity && commodity.trim()) {
      const commFilter = buildCommodityFilter(commodity.trim());
      if (commFilter) Object.assign(cropQuery, commFilter);
    }

    const farmerCrops = await Crop.find(cropQuery).lean();
    if (farmerCrops.length === 0) {
      return res.status(200).json({
        success: true,
        count: 0,
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
      const commFilter = buildCommodityFilter(crop.commodity);
      const reqQuery = {
        status: 'ACTIVE',
        requiredByDate: { $gte: today },
        buyerId: { $ne: farmerId },
      };
      if (commFilter) Object.assign(reqQuery, commFilter);

      const buyerReqs = await BuyerRequirement.find(reqQuery)
        .populate('buyerId', 'name businessName location address city district state phone')
        .lean();

      // Fetch AGMARKNET reference market price for this commodity
      const refPriceRecord = await MarketPrice.findOne(commFilter || { commodity: crop.commodity })
        .sort({ date: -1 })
        .lean();

      const marketModalPrice = refPriceRecord?.modalPrice || 0;

      const farmerQty = toQuintals(crop.quantity, crop.quantityUnit);
      const farmerPricePerQ = toPricePerQuintal(crop.expectedPrice, crop.quantityUnit);

      for (const reqItem of buyerReqs) {
        const buyer = reqItem.buyerId;
        const buyerCoords = buyer?.location?.coordinates?.length === 2
          ? { lng: buyer.location.coordinates[0], lat: buyer.location.coordinates[1] }
          : (reqItem.locationCoordinates?.coordinates?.length === 2
              ? { lng: reqItem.locationCoordinates.coordinates[0], lat: reqItem.locationCoordinates.coordinates[1] }
              : null);

        let distanceKm = null;
        if (farmerCoords && buyerCoords) {
          distanceKm = calculateHaversineDistance(
            farmerCoords.lat,
            farmerCoords.lng,
            buyerCoords.lat,
            buyerCoords.lng
          );
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
          maxDistanceKm: maxDistKm,
          harvestDate: crop.harvestDate,
          requiredByDate: reqItem.requiredByDate,
        });

        const buyerName = buyer?.businessName || buyer?.name || 'Verified Buyer';
        const buyerLocText = buyer?.address || `${reqItem.district}, ${reqItem.state}`;
        const mapsUrl = buyerCoords
          ? buildGoogleMapsUrl(buyerCoords.lat, buyerCoords.lng, `${buyerName} (Buyer Requirement)`)
          : `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(`${reqItem.market || reqItem.district}, ${reqItem.state}`)}`;

        matches.push({
          id: `FMATCH_${crop._id}_${reqItem._id}`,
          cropId: crop._id,
          cropName: crop.cropName,
          commodity: crop.commodity,
          farmerAvailableQty: crop.quantity,
          farmerUnit: crop.quantityUnit,
          farmerExpectedPrice: crop.expectedPrice,
          requirementId: reqItem._id,
          buyerId: buyer?._id || reqItem.buyerId,
          buyerName,
          buyerBusinessName: buyer?.businessName || '',
          buyerRequiredQty: reqItem.quantity,
          buyerUnit: reqItem.quantityUnit,
          buyerExpectedPrice: reqItem.offeredPrice,
          marketReferencePrice: marketModalPrice,
          marketReferenceUnit: 'Quintal',
          marketSource: refPriceRecord ? `${refPriceRecord.market} (${refPriceRecord.state})` : 'AGMARKNET Dataset',
          distanceKm,
          location: buyerLocText,
          buyerCoordinates: buyerCoords ? { latitude: buyerCoords.lat, longitude: buyerCoords.lng } : null,
          googleMapsUrl: mapsUrl,
          requiredByDate: reqItem.requiredByDate ? reqItem.requiredByDate.toISOString().split('T')[0] : null,
          harvestDate: crop.harvestDate ? crop.harvestDate.toISOString().split('T')[0] : null,
          matchScore: matchScoreResult.score,
          compatibility: matchScoreResult.compatibility,
          breakdown: matchScoreResult.breakdown,
          status: 'POTENTIAL',
        });
      }
    }

    // Sort descending by match score, then ascending by distance
    matches.sort((a, b) => {
      if (b.matchScore !== a.matchScore) return b.matchScore - a.matchScore;
      if (a.distanceKm !== null && b.distanceKm !== null) return a.distanceKm - b.distanceKm;
      return 0;
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
 * @desc    Get matching Farmer crops for authenticated Buyer's active requirements
 * @route   GET /api/matches/buyer
 * @access  Private (BUYER)
 */
const getBuyerMatches = async (req, res, next) => {
  try {
    const buyerId = req.user.id;
    const { requirementId, maxDistance = DEFAULT_MAX_MATCH_DISTANCE_KM, commodity, limit = 50 } = req.query;
    const maxDistKm = Number(maxDistance) || DEFAULT_MAX_MATCH_DISTANCE_KM;

    const buyer = await User.findById(buyerId).lean();
    if (!buyer) {
      return res.status(404).json({ success: false, message: 'Buyer account not found' });
    }

    const buyerCoords = buyer.location?.coordinates?.length === 2
      ? { lng: buyer.location.coordinates[0], lat: buyer.location.coordinates[1] }
      : null;

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const reqQuery = { buyerId, status: 'ACTIVE', requiredByDate: { $gte: today } };
    if (requirementId) reqQuery._id = requirementId;
    if (commodity && commodity.trim()) {
      const commFilter = buildCommodityFilter(commodity.trim());
      if (commFilter) Object.assign(reqQuery, commFilter);
    }

    const buyerReqs = await BuyerRequirement.find(reqQuery).lean();
    if (buyerReqs.length === 0) {
      return res.status(200).json({
        success: true,
        count: 0,
        message: 'No active buyer requirements found for matching',
        data: [],
      });
    }

    const matches = [];

    for (const reqItem of buyerReqs) {
      const commFilter = buildCommodityFilter(reqItem.commodity);
      const cropQuery = {
        status: 'AVAILABLE',
        farmerId: { $ne: buyerId },
      };
      if (commFilter) Object.assign(cropQuery, commFilter);

      const availableCrops = await Crop.find(cropQuery)
        .populate('farmerId', 'name location address city district state phone')
        .lean();

      const refPriceRecord = await MarketPrice.findOne(commFilter || { commodity: reqItem.commodity })
        .sort({ date: -1 })
        .lean();

      const marketModalPrice = refPriceRecord?.modalPrice || 0;

      const buyerKg = toKilograms(reqItem.quantity, reqItem.quantityUnit);
      const buyerPricePerQ = toPricePerQuintal(reqItem.offeredPrice, reqItem.quantityUnit);

      for (const crop of availableCrops) {
        const farmer = crop.farmerId;
        const farmerCoords = farmer?.location?.coordinates?.length === 2
          ? { lng: farmer.location.coordinates[0], lat: farmer.location.coordinates[1] }
          : (crop.locationCoordinates?.coordinates?.length === 2
              ? { lng: crop.locationCoordinates.coordinates[0], lat: crop.locationCoordinates.coordinates[1] }
              : null);

        let distanceKm = null;
        if (buyerCoords && farmerCoords) {
          distanceKm = calculateHaversineDistance(
            buyerCoords.lat,
            buyerCoords.lng,
            farmerCoords.lat,
            farmerCoords.lng
          );
        }

        const farmerQty = toQuintals(crop.quantity, crop.quantityUnit);
        const farmerPricePerQ = toPricePerQuintal(crop.expectedPrice, crop.quantityUnit);
        const buyerQty = toQuintals(reqItem.quantity, reqItem.quantityUnit);
        const buyerPricePerQ = toPricePerQuintal(reqItem.offeredPrice, reqItem.quantityUnit);

        const matchScoreResult = calculateMatchScore({
          farmerQty,
          buyerQty,
          farmerPricePerQ,
          buyerPricePerQ,
          marketRefPricePerQ: marketModalPrice,
          distanceKm,
          maxDistanceKm: maxDistKm,
          harvestDate: crop.harvestDate,
          requiredByDate: reqItem.requiredByDate,
        });

        const farmerName = farmer?.name || 'Verified Farmer';
        const farmerLocText = farmer?.address || `${crop.district}, ${crop.state}`;
        const mapsUrl = farmerCoords
          ? buildGoogleMapsUrl(farmerCoords.lat, farmerCoords.lng, `${farmerName} (Farmer Crop Listing)`)
          : `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(`${crop.market || crop.district}, ${crop.state}`)}`;

        matches.push({
          id: `BMATCH_${reqItem._id}_${crop._id}`,
          requirementId: reqItem._id,
          commodity: reqItem.commodity,
          buyerRequiredQty: reqItem.quantity,
          buyerUnit: reqItem.quantityUnit,
          buyerExpectedPrice: reqItem.offeredPrice,
          cropId: crop._id,
          cropName: crop.cropName,
          farmerId: farmer?._id || crop.farmerId,
          farmerName,
          farmerAvailableQty: crop.quantity,
          farmerUnit: crop.quantityUnit,
          farmerExpectedPrice: crop.expectedPrice,
          marketReferencePrice: marketModalPrice,
          marketReferenceUnit: 'Quintal',
          marketSource: refPriceRecord ? `${refPriceRecord.market} (${refPriceRecord.state})` : 'AGMARKNET Dataset',
          distanceKm,
          location: farmerLocText,
          farmerCoordinates: farmerCoords ? { latitude: farmerCoords.lat, longitude: farmerCoords.lng } : null,
          googleMapsUrl: mapsUrl,
          harvestDate: crop.harvestDate ? crop.harvestDate.toISOString().split('T')[0] : null,
          requiredByDate: reqItem.requiredByDate ? reqItem.requiredByDate.toISOString().split('T')[0] : null,
          matchScore: matchScoreResult.score,
          compatibility: matchScoreResult.compatibility,
          breakdown: matchScoreResult.breakdown,
          status: 'POTENTIAL',
        });
      }
    }

    matches.sort((a, b) => {
      if (b.matchScore !== a.matchScore) return b.matchScore - a.matchScore;
      if (a.distanceKm !== null && b.distanceKm !== null) return a.distanceKm - b.distanceKm;
      return 0;
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
    // Format: FMATCH_cropId_reqId or BMATCH_reqId_cropId
    const parts = id.split('_');
    if (parts.length < 3) {
      return res.status(400).json({ success: false, message: 'Invalid match ID format' });
    }

    const isFarmerOrigin = parts[0] === 'FMATCH';
    const cropId = isFarmerOrigin ? parts[1] : parts[2];
    const reqId = isFarmerOrigin ? parts[2] : parts[1];

    const [crop, reqItem] = await Promise.all([
      Crop.findById(cropId).populate('farmerId', 'name location address city district state phone'),
      BuyerRequirement.findById(reqId).populate('buyerId', 'name businessName location address city district state phone'),
    ]);

    if (!crop || !reqItem) {
      return res.status(404).json({ success: false, message: 'Crop or Requirement not found for this match' });
    }

    const refPriceRecord = await MarketPrice.findOne({ commodity: crop.commodity })
      .sort({ date: -1 })
      .lean();

    const marketModalPrice = refPriceRecord?.modalPrice || 0;

    const farmerCoords = crop.farmerId?.location?.coordinates?.length === 2
      ? { lng: crop.farmerId.location.coordinates[0], lat: crop.farmerId.location.coordinates[1] }
      : null;

    const buyerCoords = reqItem.buyerId?.location?.coordinates?.length === 2
      ? { lng: reqItem.buyerId.location.coordinates[0], lat: reqItem.buyerId.location.coordinates[1] }
      : null;

    let distanceKm = null;
    if (farmerCoords && buyerCoords) {
      distanceKm = calculateHaversineDistance(
        farmerCoords.lat,
        farmerCoords.lng,
        buyerCoords.lat,
        buyerCoords.lng
      );
    }

    const farmerKg = toKilograms(crop.quantity, crop.quantityUnit);
    const buyerKg = toKilograms(reqItem.quantity, reqItem.quantityUnit);
    const farmerPricePerQ = toPricePerQuintal(crop.expectedPrice, crop.quantityUnit);
    const buyerPricePerQ = toPricePerQuintal(reqItem.offeredPrice, reqItem.quantityUnit);

    const matchScoreResult = calculateMatchScore({
      farmerKg,
      buyerKg,
      farmerPricePerQ,
      buyerPricePerQ,
      marketRefPricePerQ: marketModalPrice,
      distanceKm,
      harvestDate: crop.harvestDate,
      requiredByDate: reqItem.requiredByDate,
    });

    const targetCoords = req.user.role === 'FARMER' ? buyerCoords : farmerCoords;
    const targetName = req.user.role === 'FARMER'
      ? (reqItem.buyerId?.businessName || reqItem.buyerId?.name || 'Buyer')
      : (crop.farmerId?.name || 'Farmer');

    const mapsUrl = targetCoords
      ? buildGoogleMapsUrl(targetCoords.lat, targetCoords.lng, targetName)
      : '';

    res.status(200).json({
      success: true,
      data: {
        id,
        crop: {
          id: crop._id,
          commodity: crop.commodity,
          cropName: crop.cropName,
          variety: crop.variety,
          grade: crop.grade,
          quantity: crop.quantity,
          quantityUnit: crop.quantityUnit,
          expectedPrice: crop.expectedPrice,
          harvestDate: crop.harvestDate ? crop.harvestDate.toISOString().split('T')[0] : null,
          farmerName: crop.farmerId?.name,
          state: crop.state,
          district: crop.district,
        },
        requirement: {
          id: reqItem._id,
          commodity: reqItem.commodity,
          quantity: reqItem.quantity,
          quantityUnit: reqItem.quantityUnit,
          offeredPrice: reqItem.offeredPrice,
          requiredByDate: reqItem.requiredByDate ? reqItem.requiredByDate.toISOString().split('T')[0] : null,
          buyerName: reqItem.buyerId?.businessName || reqItem.buyerId?.name,
          state: reqItem.state,
          district: reqItem.district,
        },
        marketReferencePrice: marketModalPrice,
        marketSource: refPriceRecord ? `${refPriceRecord.market} (${refPriceRecord.state})` : 'AGMARKNET Dataset',
        distanceKm,
        googleMapsUrl: mapsUrl,
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
  toQuintals,
  toPricePerQuintal,
};
