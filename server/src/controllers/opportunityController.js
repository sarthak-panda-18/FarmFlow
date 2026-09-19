const Opportunity = require('../models/Opportunity');
const Deal = require('../models/Deal');
const Crop = require('../models/Crop');
const BuyerRequirement = require('../models/BuyerRequirement');
const User = require('../models/User');
const Notification = require('../models/Notification');
const MarketPrice = require('../models/MarketPrice');
const { calculateHaversineDistance, buildGoogleMapsUrl } = require('../utils/geoUtils');
const { getUserRatingStats } = require('../utils/ratingHelper');
const { buildCommodityFilter } = require('../utils/commodityCategoryMapping');

/**
 * @desc    Buyer expresses interest in a farmer's crop
 * @route   POST /api/opportunities/express-interest
 * @access  Private (BUYER only)
 */
const expressInterest = async (req, res, next) => {
  try {
    const { cropId, requirementId, offeredPrice, notes } = req.body;
    const buyerId = req.user.userId;

    if (!cropId) {
      return res.status(400).json({
        success: false,
        message: 'Crop ID is required',
      });
    }

    const crop = await Crop.findById(cropId);
    if (!crop) {
      return res.status(404).json({
        success: false,
        message: 'Crop listing not found',
      });
    }

    if (crop.status !== 'AVAILABLE') {
      return res.status(400).json({
        success: false,
        message: `This crop is currently ${crop.status.toLowerCase()} and not available for new offers.`,
      });
    }

    // Verify requirement ownership if requirementId is provided
    let validReqId = null;
    if (requirementId) {
      const reqDoc = await BuyerRequirement.findById(requirementId);
      if (reqDoc && reqDoc.buyerId.toString() === buyerId && reqDoc.status === 'ACTIVE') {
        validReqId = reqDoc._id;
      }
    }

    // Prevent duplicate active opportunities for same crop & buyer
    const existing = await Opportunity.findOne({
      cropId: crop._id,
      buyerId,
      status: { $in: ['PENDING', 'INTERESTED', 'ACCEPTED'] },
    });

    if (existing) {
      return res.status(409).json({
        success: false,
        message: 'Interest already expressed.',
        data: { opportunity: existing },
      });
    }

    const price = offeredPrice !== undefined && offeredPrice !== null ? parseFloat(offeredPrice) : crop.expectedPrice;

    const opportunity = await Opportunity.create({
      buyerId,
      farmerId: crop.farmerId,
      cropId: crop._id,
      requirementId: validReqId,
      commodity: crop.commodity,
      quantity: crop.quantity,
      quantityUnit: crop.quantityUnit,
      offeredPrice: price,
      initiatedBy: 'BUYER',
      status: 'PENDING',
      notes: (notes || '').trim(),
    });

    // Fetch Buyer name
    const buyerUser = await User.findById(buyerId).select('name businessName phone').lean();
    const buyerDisplayName = buyerUser?.businessName || buyerUser?.name || 'A Verified Buyer';

    // Create Notification Alert for the Farmer
    await Notification.create({
      userId: crop.farmerId,
      farmerId: crop.farmerId,
      recipientRole: 'FARMER',
      title: 'New Buyer Interest',
      type: 'INTEREST_RECEIVED',
      message: `Buyer ${buyerDisplayName} is interested in your ${crop.commodity} crop.`,
      crop: crop.commodity,
      opportunityId: opportunity._id,
      status: 'UNREAD',
      isRead: false,
    });

    res.status(201).json({
      success: true,
      message: 'Interest expressed successfully',
      data: {
        opportunity: {
          id: opportunity._id.toString(),
          buyerId: opportunity.buyerId.toString(),
          farmerId: opportunity.farmerId.toString(),
          cropId: opportunity.cropId.toString(),
          requirementId: opportunity.requirementId ? opportunity.requirementId.toString() : null,
          commodity: opportunity.commodity,
          quantity: opportunity.quantity,
          quantityUnit: opportunity.quantityUnit,
          offeredPrice: opportunity.offeredPrice,
          initiatedBy: opportunity.initiatedBy,
          status: opportunity.status,
          createdAt: opportunity.createdAt,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Farmer expresses interest in fulfilling a buyer's requirement
 * @route   POST /api/opportunities/farmer-express-interest
 * @access  Private (FARMER only)
 */
const farmerExpressInterest = async (req, res, next) => {
  try {
    const { requirementId, cropId, offeredPrice, notes } = req.body;
    const farmerId = req.user.userId;

    if (!requirementId) {
      return res.status(400).json({
        success: false,
        message: 'Requirement ID is required',
      });
    }

    const requirement = await BuyerRequirement.findById(requirementId);
    if (!requirement) {
      return res.status(404).json({
        success: false,
        message: 'Buyer requirement not found',
      });
    }

    if (requirement.status !== 'ACTIVE') {
      return res.status(400).json({
        success: false,
        message: `This requirement is currently ${requirement.status.toLowerCase()} and no longer accepting offers.`,
      });
    }

    // Check expiration date
    if (requirement.requiredByDate) {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      if (new Date(requirement.requiredByDate) < today) {
        return res.status(400).json({
          success: false,
          message: 'This requirement has expired.',
        });
      }
    }

    // Verify crop ownership if cropId is provided
    let validCropId = null;
    if (cropId) {
      const cropDoc = await Crop.findById(cropId);
      if (cropDoc && cropDoc.farmerId.toString() === farmerId && cropDoc.status === 'AVAILABLE') {
        validCropId = cropDoc._id;
      }
    }

    // Prevent duplicate active opportunities for same requirement & farmer
    const existing = await Opportunity.findOne({
      requirementId: requirement._id,
      farmerId,
      status: { $in: ['PENDING', 'INTERESTED', 'ACCEPTED'] },
    });

    if (existing) {
      return res.status(409).json({
        success: false,
        message: 'Interest already expressed.',
        data: { opportunity: existing },
      });
    }

    const price = offeredPrice !== undefined && offeredPrice !== null ? parseFloat(offeredPrice) : requirement.offeredPrice;

    const opportunity = await Opportunity.create({
      buyerId: requirement.buyerId,
      farmerId,
      requirementId: requirement._id,
      cropId: validCropId,
      commodity: requirement.commodity,
      quantity: requirement.quantity,
      quantityUnit: requirement.quantityUnit,
      offeredPrice: price,
      initiatedBy: 'FARMER',
      status: 'PENDING',
      notes: (notes || '').trim(),
    });

    // Fetch Farmer name
    const farmerUser = await User.findById(farmerId).select('name phone').lean();
    const farmerDisplayName = farmerUser?.name || 'A Verified Farmer';

    // Create Notification Alert for the Buyer
    await Notification.create({
      userId: requirement.buyerId,
      farmerId: requirement.buyerId,
      recipientRole: 'BUYER',
      title: 'New Farmer Offer',
      type: 'INTEREST_RECEIVED',
      message: `Farmer ${farmerDisplayName} offered to supply your ${requirement.commodity} requirement.`,
      crop: requirement.commodity,
      opportunityId: opportunity._id,
      status: 'UNREAD',
      isRead: false,
    });

    res.status(201).json({
      success: true,
      message: 'Offer sent to buyer successfully',
      data: {
        opportunity: {
          id: opportunity._id.toString(),
          buyerId: opportunity.buyerId.toString(),
          farmerId: opportunity.farmerId.toString(),
          requirementId: opportunity.requirementId.toString(),
          cropId: opportunity.cropId ? opportunity.cropId.toString() : null,
          commodity: opportunity.commodity,
          quantity: opportunity.quantity,
          quantityUnit: opportunity.quantityUnit,
          offeredPrice: opportunity.offeredPrice,
          initiatedBy: opportunity.initiatedBy,
          status: opportunity.status,
          createdAt: opportunity.createdAt,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get opportunities for authenticated farmer ("My Opportunities")
 * @route   GET /api/opportunities/farmer-opportunities
 * @access  Private (FARMER only)
 */
const getFarmerOpportunities = async (req, res, next) => {
  try {
    const farmerId = req.user.userId;
    const { page = 1, limit = 20, status, direction } = req.query;

    const filter = { farmerId };
    if (status) {
      const normalizedStatus = status.toUpperCase() === 'PENDING' ? { $in: ['PENDING', 'INTERESTED'] } : status.toUpperCase();
      filter.status = normalizedStatus;
    }
    if (direction) {
      if (direction.toUpperCase() === 'SENT') {
        filter.initiatedBy = 'FARMER';
      } else if (direction.toUpperCase() === 'RECEIVED') {
        filter.initiatedBy = 'BUYER';
      }
    }

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    // Get Farmer coordinates for distance calculation
    const farmerUser = await User.findById(farmerId).select('location address city district state').lean();
    const farmerCoords = farmerUser?.location?.coordinates?.length === 2
      ? { lng: farmerUser.location.coordinates[0], lat: farmerUser.location.coordinates[1] }
      : null;

    const [total, list] = await Promise.all([
      Opportunity.countDocuments(filter),
      Opportunity.find(filter)
        .populate('buyerId', 'name phone businessName email location address city district state')
        .populate('cropId', 'commodity cropName variety expectedPrice location state district locationCoordinates')
        .populate('requirementId', 'commodity cropName quantity quantityUnit offeredPrice state district locationCoordinates requiredByDate')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limitNum)
        .lean(),
    ]);

    const formatted = await Promise.all(
      list.map(async (op) => {
        const buyerObj = op.buyerId || {};
        const buyerRatingStats = await getUserRatingStats(buyerObj._id, 'BUYER');

        const buyerCoords = buyerObj?.location?.coordinates?.length === 2
          ? { lng: buyerObj.location.coordinates[0], lat: buyerObj.location.coordinates[1] }
          : (op.requirementId?.locationCoordinates?.coordinates?.length === 2
              ? { lng: op.requirementId.locationCoordinates.coordinates[0], lat: op.requirementId.locationCoordinates.coordinates[1] }
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

        const isNormalizedPending = op.status === 'PENDING' || op.status === 'INTERESTED';

        return {
          id: op._id.toString(),
          buyer: {
            id: buyerObj._id ? buyerObj._id.toString() : null,
            name: buyerObj.name || 'Buyer',
            phone: op.status === 'ACCEPTED' || op.status === 'COMPLETED' ? buyerObj.phone || '' : '',
            businessName: buyerObj.businessName || '',
            ratingStats: buyerRatingStats,
            location: buyerObj.address || `${buyerObj.district || ''}, ${buyerObj.state || ''}`,
          },
          crop: op.cropId
            ? {
                id: op.cropId._id ? op.cropId._id.toString() : null,
                commodity: op.cropId.commodity,
                cropName: op.cropId.cropName,
                variety: op.cropId.variety,
                expectedPrice: op.cropId.expectedPrice,
                location: op.cropId.location,
              }
            : { commodity: op.commodity },
          requirement: op.requirementId
            ? {
                id: op.requirementId._id ? op.requirementId._id.toString() : null,
                commodity: op.requirementId.commodity,
                quantity: op.requirementId.quantity,
                quantityUnit: op.requirementId.quantityUnit,
                offeredPrice: op.requirementId.offeredPrice,
                requiredByDate: op.requirementId.requiredByDate ? op.requirementId.requiredByDate.toISOString().split('T')[0] : null,
              }
            : null,
          commodity: op.commodity,
          quantity: op.quantity,
          quantityUnit: op.quantityUnit,
          offeredPrice: op.offeredPrice,
          initiatedBy: op.initiatedBy || 'BUYER',
          status: isNormalizedPending ? 'PENDING' : op.status,
          distanceKm,
          notes: op.notes,
          createdAt: op.createdAt,
          updatedAt: op.updatedAt,
        };
      })
    );

    res.status(200).json({
      success: true,
      page: pageNum,
      limit: limitNum,
      total,
      pages: Math.ceil(total / limitNum) || 1,
      data: formatted,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get opportunities for authenticated buyer ("My Opportunities")
 * @route   GET /api/opportunities/buyer-opportunities
 * @access  Private (BUYER only)
 */
const getBuyerOpportunities = async (req, res, next) => {
  try {
    const buyerId = req.user.userId;
    const { page = 1, limit = 20, status, direction } = req.query;

    const filter = { buyerId };
    if (status) {
      const normalizedStatus = status.toUpperCase() === 'PENDING' ? { $in: ['PENDING', 'INTERESTED'] } : status.toUpperCase();
      filter.status = normalizedStatus;
    }
    if (direction) {
      if (direction.toUpperCase() === 'SENT') {
        filter.initiatedBy = 'BUYER';
      } else if (direction.toUpperCase() === 'RECEIVED') {
        filter.initiatedBy = 'FARMER';
      }
    }

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    // Get Buyer coordinates for distance calculation
    const buyerUser = await User.findById(buyerId).select('location address city district state').lean();
    const buyerCoords = buyerUser?.location?.coordinates?.length === 2
      ? { lng: buyerUser.location.coordinates[0], lat: buyerUser.location.coordinates[1] }
      : null;

    const [total, list] = await Promise.all([
      Opportunity.countDocuments(filter),
      Opportunity.find(filter)
        .populate('farmerId', 'name phone location address city district state')
        .populate('cropId', 'commodity cropName variety expectedPrice location state district locationCoordinates harvestDate')
        .populate('requirementId', 'commodity cropName quantity quantityUnit offeredPrice state district locationCoordinates')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limitNum)
        .lean(),
    ]);

    const formatted = await Promise.all(
      list.map(async (op) => {
        const farmerObj = op.farmerId || {};
        const farmerRatingStats = await getUserRatingStats(farmerObj._id, 'FARMER');

        const farmerCoords = farmerObj?.location?.coordinates?.length === 2
          ? { lng: farmerObj.location.coordinates[0], lat: farmerObj.location.coordinates[1] }
          : (op.cropId?.locationCoordinates?.coordinates?.length === 2
              ? { lng: op.cropId.locationCoordinates.coordinates[0], lat: op.cropId.locationCoordinates.coordinates[1] }
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

        const isNormalizedPending = op.status === 'PENDING' || op.status === 'INTERESTED';

        return {
          id: op._id.toString(),
          farmer: {
            id: farmerObj._id ? farmerObj._id.toString() : null,
            name: farmerObj.name || 'Farmer',
            phone: op.status === 'ACCEPTED' || op.status === 'COMPLETED' ? farmerObj.phone || '' : '',
            ratingStats: farmerRatingStats,
            location: farmerObj.address || `${farmerObj.district || ''}, ${farmerObj.state || ''}`,
          },
          crop: op.cropId
            ? {
                id: op.cropId._id ? op.cropId._id.toString() : null,
                commodity: op.cropId.commodity,
                cropName: op.cropId.cropName,
                variety: op.cropId.variety,
                expectedPrice: op.cropId.expectedPrice,
                location: op.cropId.location,
              }
            : null,
          requirement: op.requirementId
            ? {
                id: op.requirementId._id ? op.requirementId._id.toString() : null,
                commodity: op.requirementId.commodity,
                quantity: op.requirementId.quantity,
                quantityUnit: op.requirementId.quantityUnit,
              }
            : null,
          commodity: op.commodity,
          quantity: op.quantity,
          quantityUnit: op.quantityUnit,
          offeredPrice: op.offeredPrice,
          initiatedBy: op.initiatedBy || 'BUYER',
          status: isNormalizedPending ? 'PENDING' : op.status,
          distanceKm,
          notes: op.notes,
          createdAt: op.createdAt,
          updatedAt: op.updatedAt,
        };
      })
    );

    res.status(200).json({
      success: true,
      page: pageNum,
      limit: limitNum,
      total,
      pages: Math.ceil(total / limitNum) || 1,
      data: formatted,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Buyer discovers available farmer crops matching criteria
 * @route   GET /api/opportunities/discover-crops
 * @access  Private (BUYER only)
 */
const getDiscoverableFarmerCrops = async (req, res, next) => {
  try {
    const { commodity, state, district, page = 1, limit = 20 } = req.query;

    const filter = { status: 'AVAILABLE' };

    if (commodity && commodity.trim()) {
      const commFilter = buildCommodityFilter(commodity.trim());
      if (commFilter) {
        Object.assign(filter, commFilter);
      }
    }

    if (state && state.trim()) {
      filter.state = { $regex: new RegExp(`^${state.trim()}$`, 'i') };
    }
    if (district && district.trim()) {
      filter.district = { $regex: new RegExp(`^${district.trim()}$`, 'i') };
    }

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    const [total, crops] = await Promise.all([
      Crop.countDocuments(filter),
      Crop.find(filter)
        .populate('farmerId', 'name phone')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limitNum)
        .lean(),
    ]);

    const buyerId = req.user.userId;
    // Find existing active interests of this buyer
    const existingInterests = await Opportunity.find({
      buyerId,
      cropId: { $in: crops.map((c) => c._id) },
      status: { $in: ['PENDING', 'INTERESTED', 'ACCEPTED'] },
    }).select('cropId status').lean();

    const interestMap = new Map(existingInterests.map((op) => [op.cropId.toString(), op.status]));

    const formatted = await Promise.all(
      crops.map(async (c) => {
        const farmerObj = c.farmerId || {};
        const farmerRatingStats = await getUserRatingStats(farmerObj._id, 'FARMER');

        return {
          id: c._id.toString(),
          commodity: c.commodity,
          cropName: c.cropName || c.commodity,
          variety: c.variety,
          quantity: c.quantity,
          quantityUnit: c.quantityUnit,
          expectedPrice: c.expectedPrice,
          harvestDate: c.harvestDate ? c.harvestDate.toISOString().split('T')[0] : null,
          state: c.state,
          district: c.district,
          market: c.market,
          location: c.location || c.market || c.district,
          description: c.description || '',
          farmer: {
            id: farmerObj._id ? farmerObj._id.toString() : null,
            name: farmerObj.name || 'Farmer',
            ratingStats: farmerRatingStats,
          },
          userInterestStatus: interestMap.get(c._id.toString()) || null,
          createdAt: c.createdAt,
        };
      })
    );

    res.status(200).json({
      success: true,
      page: pageNum,
      limit: limitNum,
      total,
      pages: Math.ceil(total / limitNum) || 1,
      data: formatted,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get single opportunity by ID (Ownership protected)
 * @route   GET /api/opportunities/:id
 * @access  Private
 */
const getOpportunityById = async (req, res, next) => {
  try {
    const opportunity = await Opportunity.findById(req.params.id)
      .populate('buyerId', 'name phone businessName email gstin location address city district state')
      .populate('farmerId', 'name phone verificationId location address city district state')
      .populate('cropId')
      .populate('requirementId')
      .lean();

    if (!opportunity) {
      return res.status(404).json({
        success: false,
        message: 'Opportunity not found',
      });
    }

    const currentUserId = req.user.userId;
    const isFarmer = opportunity.farmerId && opportunity.farmerId._id.toString() === currentUserId;
    const isBuyer = opportunity.buyerId && opportunity.buyerId._id.toString() === currentUserId;

    if (!isFarmer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You are not associated with this opportunity.',
      });
    }

    // Rating stats
    const buyerRatingStats = await getUserRatingStats(opportunity.buyerId ? opportunity.buyerId._id : null, 'BUYER');
    const farmerRatingStats = await getUserRatingStats(opportunity.farmerId ? opportunity.farmerId._id : null, 'FARMER');

    // Market Reference Price from AGMARKNET dataset
    const commFilter = buildCommodityFilter(opportunity.commodity);
    const refPriceRecord = await MarketPrice.findOne(commFilter || { commodity: opportunity.commodity })
      .sort({ date: -1 })
      .lean();

    const marketModalPrice = refPriceRecord?.modalPrice || 0;
    const marketSource = refPriceRecord ? `${refPriceRecord.market} (${refPriceRecord.state})` : 'AGMARKNET Reference';

    // Coordinates & Distance
    const farmerCoords = opportunity.farmerId?.location?.coordinates?.length === 2
      ? { lng: opportunity.farmerId.location.coordinates[0], lat: opportunity.farmerId.location.coordinates[1] }
      : (opportunity.cropId?.locationCoordinates?.coordinates?.length === 2
          ? { lng: opportunity.cropId.locationCoordinates.coordinates[0], lat: opportunity.cropId.locationCoordinates.coordinates[1] }
          : null);

    const buyerCoords = opportunity.buyerId?.location?.coordinates?.length === 2
      ? { lng: opportunity.buyerId.location.coordinates[0], lat: opportunity.buyerId.location.coordinates[1] }
      : (opportunity.requirementId?.locationCoordinates?.coordinates?.length === 2
          ? { lng: opportunity.requirementId.locationCoordinates.coordinates[0], lat: opportunity.requirementId.locationCoordinates.coordinates[1] }
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

    // Build Maps URL for counterparty
    const targetCoords = isFarmer ? buyerCoords : farmerCoords;
    const targetName = isFarmer
      ? (opportunity.buyerId?.businessName || opportunity.buyerId?.name || 'Buyer')
      : (opportunity.farmerId?.name || 'Farmer');

    const googleMapsUrl = targetCoords
      ? buildGoogleMapsUrl(targetCoords.lat, targetCoords.lng, targetName)
      : (isFarmer
          ? `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(opportunity.buyerId?.address || `${opportunity.buyerId?.district || ''}, ${opportunity.buyerId?.state || ''}`)}`
          : `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(opportunity.farmerId?.address || `${opportunity.cropId?.district || ''}, ${opportunity.cropId?.state || ''}`)}`);

    const isNormalizedPending = opportunity.status === 'PENDING' || opportunity.status === 'INTERESTED';
    const currentStatus = isNormalizedPending ? 'PENDING' : opportunity.status;

    // Find any linked deal for Phase 10 integration
    const linkedDeal = await Deal.findOne({ opportunityId: opportunity._id }).select('_id status').lean();

    res.status(200).json({
      success: true,
      data: {
        opportunity: {
          id: opportunity._id.toString(),
          dealId: linkedDeal ? linkedDeal._id.toString() : null,
          dealStatus: linkedDeal ? linkedDeal.status : null,
          buyer: opportunity.buyerId
            ? {
                id: opportunity.buyerId._id.toString(),
                name: opportunity.buyerId.name,
                phone: isBuyer || currentStatus === 'ACCEPTED' || currentStatus === 'COMPLETED' ? opportunity.buyerId.phone : '',
                businessName: opportunity.buyerId.businessName || '',
                gstin: opportunity.buyerId.gstin || '',
                location: opportunity.buyerId.address || `${opportunity.buyerId.district || ''}, ${opportunity.buyerId.state || ''}`,
                coordinates: buyerCoords ? { latitude: buyerCoords.lat, longitude: buyerCoords.lng } : null,
                ratingStats: buyerRatingStats,
              }
            : null,
          farmer: opportunity.farmerId
            ? {
                id: opportunity.farmerId._id.toString(),
                name: opportunity.farmerId.name,
                phone: isFarmer || currentStatus === 'ACCEPTED' || currentStatus === 'COMPLETED' ? opportunity.farmerId.phone : '',
                location: opportunity.farmerId.address || `${opportunity.farmerId.district || ''}, ${opportunity.farmerId.state || ''}`,
                coordinates: farmerCoords ? { latitude: farmerCoords.lat, longitude: farmerCoords.lng } : null,
                ratingStats: farmerRatingStats,
              }
            : null,
          crop: opportunity.cropId
            ? {
                id: opportunity.cropId._id ? opportunity.cropId._id.toString() : null,
                commodity: opportunity.cropId.commodity,
                cropName: opportunity.cropId.cropName,
                variety: opportunity.cropId.variety,
                grade: opportunity.cropId.grade,
                quantity: opportunity.cropId.quantity,
                quantityUnit: opportunity.cropId.quantityUnit,
                expectedPrice: opportunity.cropId.expectedPrice,
                harvestDate: opportunity.cropId.harvestDate ? opportunity.cropId.harvestDate.toISOString().split('T')[0] : null,
                location: opportunity.cropId.location || `${opportunity.cropId.district}, ${opportunity.cropId.state}`,
                status: opportunity.cropId.status,
              }
            : null,
          requirement: opportunity.requirementId
            ? {
                id: opportunity.requirementId._id ? opportunity.requirementId._id.toString() : null,
                commodity: opportunity.requirementId.commodity,
                quantity: opportunity.requirementId.quantity,
                quantityUnit: opportunity.requirementId.quantityUnit,
                offeredPrice: opportunity.requirementId.offeredPrice,
                requiredByDate: opportunity.requirementId.requiredByDate ? opportunity.requirementId.requiredByDate.toISOString().split('T')[0] : null,
                location: opportunity.requirementId.location || `${opportunity.requirementId.district}, ${opportunity.requirementId.state}`,
                status: opportunity.requirementId.status,
              }
            : null,
          commodity: opportunity.commodity,
          quantity: opportunity.quantity,
          quantityUnit: opportunity.quantityUnit,
          offeredPrice: opportunity.offeredPrice,
          marketReferencePrice: marketModalPrice,
          marketSource,
          distanceKm,
          googleMapsUrl,
          initiatedBy: opportunity.initiatedBy || 'BUYER',
          status: currentStatus,
          notes: opportunity.notes,
          createdAt: opportunity.createdAt,
          updatedAt: opportunity.updatedAt,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Receiving party accepts opportunity
 * @route   PATCH /api/opportunities/:id/accept or POST /api/opportunities/:id/accept
 * @access  Private (FARMER or BUYER)
 */
const acceptOpportunity = async (req, res, next) => {
  try {
    const opportunity = await Opportunity.findById(req.params.id);
    if (!opportunity) {
      return res.status(404).json({
        success: false,
        message: 'Opportunity not found',
      });
    }

    const currentUserId = req.user.userId;
    const isFarmer = opportunity.farmerId.toString() === currentUserId;
    const isBuyer = opportunity.buyerId.toString() === currentUserId;

    if (!isFarmer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You are not associated with this opportunity.',
      });
    }

    // Verify authenticated user is the RECEIVING party
    const isInitiatedByBuyer = opportunity.initiatedBy === 'BUYER';
    const isInitiatedByFarmer = opportunity.initiatedBy === 'FARMER';

    if (isInitiatedByBuyer && !isFarmer) {
      return res.status(403).json({
        success: false,
        message: 'Only the farmer can accept an offer initiated by the buyer.',
      });
    }
    if (isInitiatedByFarmer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Only the buyer can accept an offer initiated by the farmer.',
      });
    }

    // Concurrency check
    if (opportunity.status !== 'PENDING' && opportunity.status !== 'INTERESTED') {
      return res.status(400).json({
        success: false,
        message: 'Opportunity is no longer pending.',
      });
    }

    opportunity.status = 'ACCEPTED';
    await opportunity.save();

    if (opportunity.cropId) {
      await Crop.findByIdAndUpdate(opportunity.cropId, { status: 'RESERVED' });
    }

    // Auto-create or link Deal record
    let deal = await Deal.findOne({ opportunityId: opportunity._id });
    if (!deal) {
      const farmer = await User.findById(opportunity.farmerId).select('address location coordinates district state').lean();
      const buyer = await User.findById(opportunity.buyerId).select('address location coordinates district state').lean();

      let pickupLat = null;
      let pickupLng = null;
      if (farmer && farmer.location && Array.isArray(farmer.location.coordinates) && farmer.location.coordinates.length === 2) {
        pickupLng = farmer.location.coordinates[0];
        pickupLat = farmer.location.coordinates[1];
      } else if (farmer && farmer.coordinates && farmer.coordinates.latitude != null) {
        pickupLat = farmer.coordinates.latitude;
        pickupLng = farmer.coordinates.longitude;
      }

      let deliveryLat = null;
      let deliveryLng = null;
      if (buyer && buyer.location && Array.isArray(buyer.location.coordinates) && buyer.location.coordinates.length === 2) {
        deliveryLng = buyer.location.coordinates[0];
        deliveryLat = buyer.location.coordinates[1];
      } else if (buyer && buyer.coordinates && buyer.coordinates.latitude != null) {
        deliveryLat = buyer.coordinates.latitude;
        deliveryLng = buyer.coordinates.longitude;
      }

      let distance = null;
      if (pickupLat != null && pickupLng != null && deliveryLat != null && deliveryLng != null) {
        distance = calculateHaversineDistance(pickupLat, pickupLng, deliveryLat, deliveryLng);
      }

      const farmerAddress = farmer?.address || (typeof farmer?.location === 'string' ? farmer.location : '') || `${farmer?.district || ''}, ${farmer?.state || ''}`;
      const buyerAddress = buyer?.address || (typeof buyer?.location === 'string' ? buyer.location : '') || `${buyer?.district || ''}, ${buyer?.state || ''}`;

      deal = new Deal({
        farmerId: opportunity.farmerId,
        buyerId: opportunity.buyerId,
        opportunityId: opportunity._id,
        farmerCropId: opportunity.cropId || opportunity.farmerCropId,
        cropId: opportunity.cropId || opportunity.farmerCropId,
        buyerRequirementId: opportunity.requirementId || opportunity.buyerRequirementId,
        requirementId: opportunity.requirementId || opportunity.buyerRequirementId,
        commodity: opportunity.commodity,
        crop: opportunity.commodity,
        quantity: opportunity.quantity,
        quantityUnit: opportunity.quantityUnit || 'kg',
        agreedPrice: opportunity.offeredPrice,
        agreedPriceUnit: 'quintal',
        status: 'CONFIRMED',
        pickupLocation: {
          address: farmerAddress,
          latitude: pickupLat,
          longitude: pickupLng,
        },
        deliveryLocation: {
          address: buyerAddress,
          latitude: deliveryLat,
          longitude: deliveryLng,
        },
        distanceKm: distance,
        paymentStatus: 'PAYMENT_PENDING',
        paymentMethod: 'External / Direct Payment',
      });
      await deal.save();
    }

    // Notify the INITIATING party
    const acceptingUser = await User.findById(currentUserId).select('name businessName').lean();
    const acceptingName = acceptingUser?.businessName || acceptingUser?.name || (isFarmer ? 'Farmer' : 'Buyer');

    const recipientUserId = isFarmer ? opportunity.buyerId : opportunity.farmerId;
    const recipientRole = isFarmer ? 'BUYER' : 'FARMER';

    await Notification.create({
      userId: recipientUserId,
      farmerId: recipientUserId,
      recipientRole,
      title: 'Interest Accepted',
      type: 'INTEREST_ACCEPTED',
      message: `${acceptingName} accepted your interest in ${opportunity.commodity}. Deal is now confirmed!`,
      crop: opportunity.commodity,
      opportunityId: opportunity._id,
      dealId: deal ? deal._id : null,
      status: 'UNREAD',
      isRead: false,
    });

    res.status(200).json({
      success: true,
      message: 'Opportunity accepted and deal confirmed successfully',
      data: {
        opportunity,
        dealId: deal ? deal._id.toString() : null,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Receiving party rejects opportunity
 * @route   PATCH /api/opportunities/:id/reject or POST /api/opportunities/:id/reject
 * @access  Private (FARMER or BUYER)
 */
const rejectOpportunity = async (req, res, next) => {
  try {
    const opportunity = await Opportunity.findById(req.params.id);
    if (!opportunity) {
      return res.status(404).json({
        success: false,
        message: 'Opportunity not found',
      });
    }

    const currentUserId = req.user.userId;
    const isFarmer = opportunity.farmerId.toString() === currentUserId;
    const isBuyer = opportunity.buyerId.toString() === currentUserId;

    if (!isFarmer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Access denied.',
      });
    }

    // Verify receiver
    const isInitiatedByBuyer = opportunity.initiatedBy === 'BUYER';
    const isInitiatedByFarmer = opportunity.initiatedBy === 'FARMER';

    if (isInitiatedByBuyer && !isFarmer) {
      return res.status(403).json({
        success: false,
        message: 'Only the recipient farmer can reject this opportunity.',
      });
    }
    if (isInitiatedByFarmer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Only the recipient buyer can reject this opportunity.',
      });
    }

    // Concurrency check
    if (opportunity.status !== 'PENDING' && opportunity.status !== 'INTERESTED') {
      return res.status(400).json({
        success: false,
        message: 'Opportunity is no longer pending.',
      });
    }

    opportunity.status = 'REJECTED';
    await opportunity.save();

    // Notify initiator
    const rejectingUser = await User.findById(currentUserId).select('name businessName').lean();
    const rejectingName = rejectingUser?.businessName || rejectingUser?.name || (isFarmer ? 'Farmer' : 'Buyer');
    const recipientUserId = isFarmer ? opportunity.buyerId : opportunity.farmerId;
    const recipientRole = isFarmer ? 'BUYER' : 'FARMER';

    await Notification.create({
      userId: recipientUserId,
      farmerId: recipientUserId,
      recipientRole,
      title: 'Offer Declined',
      type: 'INTEREST_REJECTED',
      message: `${rejectingName} declined your offer for ${opportunity.commodity}.`,
      crop: opportunity.commodity,
      opportunityId: opportunity._id,
      status: 'UNREAD',
      isRead: false,
    });

    res.status(200).json({
      success: true,
      message: 'Opportunity rejected',
      data: { opportunity },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Initiating party cancels pending opportunity
 * @route   PATCH /api/opportunities/:id/cancel or POST /api/opportunities/:id/cancel
 * @access  Private (FARMER or BUYER)
 */
const cancelOpportunity = async (req, res, next) => {
  try {
    const opportunity = await Opportunity.findById(req.params.id);
    if (!opportunity) {
      return res.status(404).json({
        success: false,
        message: 'Opportunity not found',
      });
    }

    const currentUserId = req.user.userId;
    const isFarmer = opportunity.farmerId.toString() === currentUserId;
    const isBuyer = opportunity.buyerId.toString() === currentUserId;

    if (!isFarmer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Access denied.',
      });
    }

    // Verify initiator
    const isInitiatedByBuyer = opportunity.initiatedBy === 'BUYER';
    const isInitiatedByFarmer = opportunity.initiatedBy === 'FARMER';

    if (isInitiatedByBuyer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Only the initiating buyer can cancel this interest.',
      });
    }
    if (isInitiatedByFarmer && !isFarmer) {
      return res.status(403).json({
        success: false,
        message: 'Only the initiating farmer can cancel this offer.',
      });
    }

    // Concurrency check
    if (opportunity.status !== 'PENDING' && opportunity.status !== 'INTERESTED') {
      return res.status(400).json({
        success: false,
        message: 'Opportunity is no longer pending and cannot be cancelled.',
      });
    }

    opportunity.status = 'CANCELLED';
    await opportunity.save();

    // Notify receiver
    const cancellingUser = await User.findById(currentUserId).select('name businessName').lean();
    const cancellingName = cancellingUser?.businessName || cancellingUser?.name || (isFarmer ? 'Farmer' : 'Buyer');
    const recipientUserId = isFarmer ? opportunity.buyerId : opportunity.farmerId;
    const recipientRole = isFarmer ? 'BUYER' : 'FARMER';

    await Notification.create({
      userId: recipientUserId,
      farmerId: recipientUserId,
      recipientRole,
      title: 'Interest Cancelled',
      type: 'INTEREST_CANCELLED',
      message: `${cancellingName} cancelled their offer for ${opportunity.commodity}.`,
      crop: opportunity.commodity,
      opportunityId: opportunity._id,
      status: 'UNREAD',
      isRead: false,
    });

    res.status(200).json({
      success: true,
      message: 'Opportunity cancelled successfully',
      data: { opportunity },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Mark transaction completed (enabling feedback)
 * @route   POST /api/opportunities/:id/complete
 * @access  Private (FARMER or BUYER)
 */
const completeOpportunity = async (req, res, next) => {
  try {
    const opportunity = await Opportunity.findById(req.params.id);
    if (!opportunity) {
      return res.status(404).json({
        success: false,
        message: 'Opportunity not found',
      });
    }

    const currentUserId = req.user.userId;
    const isFarmer = opportunity.farmerId.toString() === currentUserId;
    const isBuyer = opportunity.buyerId.toString() === currentUserId;

    if (!isFarmer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Access denied.',
      });
    }

    if (opportunity.status !== 'ACCEPTED') {
      return res.status(400).json({
        success: false,
        message: 'Only accepted opportunities can be marked as completed.',
      });
    }

    opportunity.status = 'COMPLETED';
    await opportunity.save();

    if (opportunity.cropId) {
      await Crop.findByIdAndUpdate(opportunity.cropId, { status: 'SOLD' });
    }
    if (opportunity.requirementId) {
      await BuyerRequirement.findByIdAndUpdate(opportunity.requirementId, { status: 'FULFILLED' });
    }

    res.status(200).json({
      success: true,
      message: 'Transaction marked as COMPLETED. You can now leave feedback.',
      data: { opportunity },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  expressInterest,
  farmerExpressInterest,
  getFarmerOpportunities,
  getBuyerOpportunities,
  getDiscoverableFarmerCrops,
  getOpportunityById,
  acceptOpportunity,
  rejectOpportunity,
  cancelOpportunity,
  completeOpportunity,
};

