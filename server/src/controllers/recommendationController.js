const Crop = require('../models/Crop');
const Opportunity = require('../models/Opportunity');
const User = require('../models/User');
const { calculateHaversineDistance, buildGoogleMapsUrl } = require('../utils/geoUtils');
const { getUserRatingStats } = require('../utils/ratingHelper');

/**
 * Calculates deterministic Net Value for an interested buyer opportunity.
 * Formula: Net Value = Selling Price - Transportation Cost - Other Costs
 * All monetary amounts are on a total deal value basis in INR (₹).
 * Quantity basis is strictly Quintal.
 */
const calculateOpportunityNetValue = async (op, farmerCoords, crop) => {
  const buyer = op.buyerId || {};
  const buyerRatingStats = await getUserRatingStats(buyer._id, 'BUYER');

  const buyerCoords =
    buyer.location?.coordinates?.length === 2
      ? { lng: buyer.location.coordinates[0], lat: buyer.location.coordinates[1] }
      : op.requirementId?.locationCoordinates?.coordinates?.length === 2
      ? {
          lng: op.requirementId.locationCoordinates.coordinates[0],
          lat: op.requirementId.locationCoordinates.coordinates[1],
        }
      : null;

  let distanceKm = null;
  if (farmerCoords && buyerCoords) {
    distanceKm = calculateHaversineDistance(
      farmerCoords.lat,
      farmerCoords.lng,
      buyerCoords.lat,
      buyerCoords.lng
    );
  } else if (op.distanceKm != null && op.distanceKm > 0) {
    distanceKm = Number(op.distanceKm);
  }

  // Unit price and total selling price in Quintals
  const unitPrice = Number(op.offeredPrice) || Number(crop.expectedPrice) || 0;
  const quantity = Number(op.quantity) || Number(crop.quantity) || 0;
  const sellingPrice = Math.round(quantity * unitPrice * 100) / 100;

  // Transportation cost handling
  let transportationCost = null;
  let isTransportAvailable = false;

  if (op.transportCost !== undefined && op.transportCost !== null && Number(op.transportCost) >= 0) {
    transportationCost = Number(op.transportCost);
    isTransportAvailable = true;
  } else if (distanceKm !== null && distanceKm !== undefined) {
    // If distance is known and no transport cost specified, calculate estimated standard rate (₹25/km)
    transportationCost = Math.round(distanceKm * 25 * 100) / 100;
    isTransportAvailable = true;
  } else {
    // Missing transportation data
    transportationCost = null;
    isTransportAvailable = false;
  }

  // Other costs handling
  const otherCosts = Math.max(0, Number(op.otherCosts) || 0);

  // Net Value = Selling Price - Transportation Cost - Other Costs
  let netValue = 0;
  if (isTransportAvailable && transportationCost !== null) {
    netValue = Math.round((sellingPrice - transportationCost - otherCosts) * 100) / 100;
  } else {
    netValue = Math.round((sellingPrice - otherCosts) * 100) / 100;
  }

  const buyerName = buyer.businessName || buyer.name || 'Verified Buyer';
  const buyerLocation =
    buyer.address || `${buyer.city ? buyer.city + ', ' : ''}${buyer.district || ''}, ${buyer.state || ''}`;

  const googleMapsUrl = buyerCoords
    ? buildGoogleMapsUrl(buyerCoords.lat, buyerCoords.lng, `${buyerName} (Delivery Location)`)
    : `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(buyerLocation)}`;

  return {
    opportunityId: op._id ? op._id.toString() : '',
    buyerId: buyer._id ? buyer._id.toString() : (op.buyerId ? op.buyerId.toString() : ''),
    buyerName,
    businessName: buyer.businessName || '',
    phone: op.status === 'ACCEPTED' || op.status === 'COMPLETED' ? buyer.phone || '' : '',
    ratingStats: buyerRatingStats,
    location: buyerLocation,
    distanceKm,
    coordinates: buyerCoords ? { latitude: buyerCoords.lat, longitude: buyerCoords.lng } : null,
    googleMapsUrl,
    quantity,
    quantityUnit: 'quintal',
    unitPrice,
    sellingPrice,
    transportationCost,
    isTransportAvailable,
    otherCosts,
    netValue,
    status: op.status,
    notes: op.notes || '',
    createdAt: op.createdAt,
  };
};

/**
 * Generates transparent, data-driven explanations for the top recommended buyer.
 */
const generateRecommendationExplanations = (topBuyer, allBuyers) => {
  if (!topBuyer || allBuyers.length < 3) {
    return {
      summary: 'Recommendation engine activates when 3 or more buyers express interest.',
      reasons: [],
    };
  }

  const reasons = [];

  // 1. Highest expected net value
  reasons.push(
    `Highest expected net value of ₹${topBuyer.netValue.toLocaleString('en-IN')}`
  );

  // 2. Compare transport costs
  const otherBuyersWithTransport = allBuyers.filter(
    (b) => b.opportunityId !== topBuyer.opportunityId && b.isTransportAvailable && b.transportationCost !== null
  );
  if (otherBuyersWithTransport.length > 0) {
    const minOtherTransport = Math.min(...otherBuyersWithTransport.map((b) => b.transportationCost));
    const avgOtherTransport =
      otherBuyersWithTransport.reduce((acc, b) => acc + b.transportationCost, 0) /
      otherBuyersWithTransport.length;

    if (topBuyer.transportationCost <= minOtherTransport) {
      reasons.push(
        `Lowest transportation cost of ₹${topBuyer.transportationCost.toLocaleString('en-IN')}${
          topBuyer.distanceKm != null ? ` (${topBuyer.distanceKm} km away)` : ''
        }`
      );
    } else if (topBuyer.transportationCost < avgOtherTransport) {
      reasons.push(
        `Transportation cost is relatively low at ₹${topBuyer.transportationCost.toLocaleString('en-IN')}`
      );
    }
  }

  // 3. Compare selling prices
  const otherSellingPrices = allBuyers
    .filter((b) => b.opportunityId !== topBuyer.opportunityId)
    .map((b) => b.sellingPrice);
  if (otherSellingPrices.length > 0) {
    const maxOtherSellingPrice = Math.max(...otherSellingPrices);
    if (topBuyer.sellingPrice >= maxOtherSellingPrice) {
      reasons.push(
        `Highest offered selling price of ₹${topBuyer.sellingPrice.toLocaleString('en-IN')} (₹${topBuyer.unitPrice}/Quintal)`
      );
    } else {
      reasons.push(
        `Competitive selling price of ₹${topBuyer.sellingPrice.toLocaleString('en-IN')} (₹${topBuyer.unitPrice}/Quintal)`
      );
    }
  }

  // 4. Compare other costs
  const otherCostsList = allBuyers
    .filter((b) => b.opportunityId !== topBuyer.opportunityId)
    .map((b) => b.otherCosts);
  if (otherCostsList.length > 0) {
    const minOtherCosts = Math.min(...otherCostsList);
    if (topBuyer.otherCosts <= minOtherCosts) {
      reasons.push(
        `Lowest additional handling costs (₹${topBuyer.otherCosts.toLocaleString('en-IN')})`
      );
    }
  }

  // Summary
  const transportText =
    topBuyer.isTransportAvailable && topBuyer.transportationCost !== null
      ? `₹${topBuyer.transportationCost.toLocaleString('en-IN')}`
      : 'unavailable';

  const summary = `Buyer ${topBuyer.buyerName} is recommended because they provide the highest expected net value of ₹${topBuyer.netValue.toLocaleString(
    'en-IN'
  )} after transportation (${transportText}) and other costs (₹${topBuyer.otherCosts.toLocaleString('en-IN')}).`;

  return {
    summary,
    reasons,
  };
};

/**
 * Deterministically sorts buyers by Net Value descending.
 * Tie-breaker: 1. Higher selling price, 2. Lower transport cost, 3. Lower other costs, 4. Earlier createdAt
 */
const sortBuyerRecommendations = (buyers) => {
  return [...buyers].sort((a, b) => {
    // 1. Buyers with unavailable transport data go after complete records if net values are otherwise tied
    if (a.isTransportAvailable && !b.isTransportAvailable) return -1;
    if (!a.isTransportAvailable && b.isTransportAvailable) return 1;

    // 2. Primary: Net Value descending
    if (b.netValue !== a.netValue) {
      return b.netValue - a.netValue;
    }

    // 3. Secondary Tie-breaker: Higher Selling Price
    if (b.sellingPrice !== a.sellingPrice) {
      return b.sellingPrice - a.sellingPrice;
    }

    // 4. Tertiary Tie-breaker: Lower Transportation Cost
    const tA = a.transportationCost ?? Infinity;
    const tB = b.transportationCost ?? Infinity;
    if (tA !== tB) {
      return tA - tB;
    }

    // 5. Quaternary Tie-breaker: Lower Other Costs
    if (a.otherCosts !== b.otherCosts) {
      return a.otherCosts - b.otherCosts;
    }

    // 6. Stable ordering: Earlier createdAt
    const timeA = a.createdAt ? new Date(a.createdAt).getTime() : 0;
    const timeB = b.createdAt ? new Date(b.createdAt).getTime() : 0;
    return timeA - timeB;
  });
};

/**
 * @desc    Get buyer recommendations for a specific farmer's crop
 * @route   GET /api/recommendations/crop/:cropId
 * @access  Private (FARMER only)
 */
const getCropRecommendations = async (req, res, next) => {
  try {
    const { cropId } = req.params;
    const currentUserId = req.user.userId;

    if (req.user.role !== 'FARMER') {
      return res.status(403).json({
        success: false,
        message: 'Access denied. Buyer recommendations are only available for Farmers.',
      });
    }

    const crop = await Crop.findById(cropId);
    if (!crop) {
      return res.status(404).json({
        success: false,
        message: 'Crop listing not found.',
      });
    }

    // Ownership check
    if (crop.farmerId.toString() !== currentUserId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You are not authorized to view recommendations for this crop.',
      });
    }

    // Fetch Farmer coordinates
    const farmerUser = await User.findById(currentUserId).select('location coordinates address district state').lean();
    const farmerCoords =
      crop.locationCoordinates?.coordinates?.length === 2
        ? { lng: crop.locationCoordinates.coordinates[0], lat: crop.locationCoordinates.coordinates[1] }
        : farmerUser?.location?.coordinates?.length === 2
        ? { lng: farmerUser.location.coordinates[0], lat: farmerUser.location.coordinates[1] }
        : null;

    // Fetch all active/pending opportunities for this crop
    const opportunities = await Opportunity.find({
      cropId: crop._id,
      status: { $in: ['PENDING', 'INTERESTED', 'ACCEPTED'] },
    })
      .populate('buyerId', 'name businessName phone location address city district state')
      .populate('requirementId', 'commodity quantity quantityUnit offeredPrice state district locationCoordinates')
      .sort({ createdAt: -1 })
      .lean();

    const interestedBuyersCount = opportunities.length;

    // Calculate Net Value for each interested buyer
    const computedBuyers = await Promise.all(
      opportunities.map((op) => calculateOpportunityNetValue(op, farmerCoords, crop))
    );

    // Sort by Net Value descending
    const sortedBuyers = sortBuyerRecommendations(computedBuyers);

    const isRecommendationActive = interestedBuyersCount >= 3;

    // Rank buyers and assign isRecommended
    const rankedBuyers = sortedBuyers.map((buyer, idx) => ({
      ...buyer,
      rank: idx + 1,
      isRecommended: isRecommendationActive && idx === 0 && buyer.isTransportAvailable,
    }));

    const topRecommendedBuyer = isRecommendationActive && rankedBuyers.length > 0 ? rankedBuyers[0] : null;
    const explanations = generateRecommendationExplanations(topRecommendedBuyer, rankedBuyers);

    res.status(200).json({
      success: true,
      data: {
        crop: {
          id: crop._id.toString(),
          commodity: crop.commodity,
          cropName: crop.cropName || crop.commodity,
          variety: crop.variety,
          quantity: crop.quantity,
          quantityUnit: 'quintal',
          expectedPrice: crop.expectedPrice,
          expectedPriceUnit: 'quintal',
          status: crop.status,
          location: crop.location || `${crop.district || ''}, ${crop.state || ''}`,
        },
        interestedBuyersCount,
        isRecommendationActive,
        recommendationThreshold: 3,
        recommendedBuyer: topRecommendedBuyer,
        explanation: explanations.summary,
        reasons: explanations.reasons,
        allBuyers: rankedBuyers,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get recommendations for all active crops of the authenticated farmer
 * @route   GET /api/recommendations/farmer
 * @access  Private (FARMER only)
 */
const getFarmerRecommendations = async (req, res, next) => {
  try {
    const farmerId = req.user.userId;

    if (req.user.role !== 'FARMER') {
      return res.status(403).json({
        success: false,
        message: 'Access denied. Buyer recommendations are only available for Farmers.',
      });
    }

    // Fetch Farmer active crops
    const crops = await Crop.find({
      farmerId,
      status: 'AVAILABLE',
    })
      .sort({ createdAt: -1 })
      .lean();

    const farmerUser = await User.findById(farmerId).select('location coordinates address district state').lean();

    const cropRecommendations = await Promise.all(
      crops.map(async (crop) => {
        const farmerCoords =
          crop.locationCoordinates?.coordinates?.length === 2
            ? { lng: crop.locationCoordinates.coordinates[0], lat: crop.locationCoordinates.coordinates[1] }
            : farmerUser?.location?.coordinates?.length === 2
            ? { lng: farmerUser.location.coordinates[0], lat: farmerUser.location.coordinates[1] }
            : null;

        const opportunities = await Opportunity.find({
          cropId: crop._id,
          status: { $in: ['PENDING', 'INTERESTED', 'ACCEPTED'] },
        })
          .populate('buyerId', 'name businessName phone location address city district state')
          .populate('requirementId', 'commodity quantity quantityUnit offeredPrice state district locationCoordinates')
          .sort({ createdAt: -1 })
          .lean();

        const interestedBuyersCount = opportunities.length;
        const computedBuyers = await Promise.all(
          opportunities.map((op) => calculateOpportunityNetValue(op, farmerCoords, crop))
        );

        const sortedBuyers = sortBuyerRecommendations(computedBuyers);
        const isRecommendationActive = interestedBuyersCount >= 3;

        const rankedBuyers = sortedBuyers.map((buyer, idx) => ({
          ...buyer,
          rank: idx + 1,
          isRecommended: isRecommendationActive && idx === 0 && buyer.isTransportAvailable,
        }));

        const topRecommendedBuyer = isRecommendationActive && rankedBuyers.length > 0 ? rankedBuyers[0] : null;
        const explanations = generateRecommendationExplanations(topRecommendedBuyer, rankedBuyers);

        return {
          crop: {
            id: crop._id.toString(),
            commodity: crop.commodity,
            cropName: crop.cropName || crop.commodity,
            variety: crop.variety,
            quantity: crop.quantity,
            quantityUnit: 'quintal',
            expectedPrice: crop.expectedPrice,
            expectedPriceUnit: 'quintal',
            status: crop.status,
            location: crop.location || `${crop.district || ''}, ${crop.state || ''}`,
          },
          interestedBuyersCount,
          isRecommendationActive,
          recommendationThreshold: 3,
          recommendedBuyer: topRecommendedBuyer,
          explanation: explanations.summary,
          reasons: explanations.reasons,
          allBuyers: rankedBuyers,
        };
      })
    );

    res.status(200).json({
      success: true,
      count: cropRecommendations.length,
      data: cropRecommendations,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get recommendations linked to a specific Opportunity ID
 * @route   GET /api/recommendations/opportunity/:id
 * @access  Private (FARMER only)
 */
const getOpportunityRecommendations = async (req, res, next) => {
  try {
    const { id } = req.params;
    const currentUserId = req.user.userId;

    if (req.user.role !== 'FARMER') {
      return res.status(403).json({
        success: false,
        message: 'Access denied. Recommendations are only available for Farmers.',
      });
    }

    const opportunity = await Opportunity.findById(id).populate('cropId').lean();
    if (!opportunity) {
      return res.status(404).json({
        success: false,
        message: 'Opportunity not found.',
      });
    }

    if (opportunity.farmerId.toString() !== currentUserId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You do not own this opportunity.',
      });
    }

    if (!opportunity.cropId) {
      return res.status(400).json({
        success: false,
        message: 'Opportunity is not linked to a specific crop listing.',
      });
    }

    req.params.cropId = opportunity.cropId._id.toString();
    return getCropRecommendations(req, res, next);
  } catch (error) {
    next(error);
  }
};

module.exports = {
  calculateOpportunityNetValue,
  generateRecommendationExplanations,
  sortBuyerRecommendations,
  getCropRecommendations,
  getFarmerRecommendations,
  getOpportunityRecommendations,
};
