const Opportunity = require('../models/Opportunity');
const Crop = require('../models/Crop');
const BuyerRequirement = require('../models/BuyerRequirement');
const User = require('../models/User');
const Notification = require('../models/Notification');
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
        message: 'Crop not found',
      });
    }

    if (crop.status !== 'AVAILABLE') {
      return res.status(400).json({
        success: false,
        message: `This crop is currently ${crop.status.toLowerCase()} and not available for new buyer interest.`,
      });
    }

    // Check if buyer already expressed interest in this crop
    const existing = await Opportunity.findOne({ cropId, buyerId });
    if (existing) {
      return res.status(409).json({
        success: false,
        message: 'You have already expressed interest in this crop.',
        data: { opportunity: existing },
      });
    }

    const price = offeredPrice !== undefined && offeredPrice !== null ? parseFloat(offeredPrice) : crop.expectedPrice;

    const opportunity = await Opportunity.create({
      buyerId,
      farmerId: crop.farmerId,
      cropId: crop._id,
      requirementId: requirementId || undefined,
      commodity: crop.commodity,
      quantity: crop.quantity,
      quantityUnit: crop.quantityUnit,
      offeredPrice: price,
      status: 'INTERESTED',
      notes: (notes || '').trim(),
    });

    // Get buyer name
    const buyerUser = await User.findById(buyerId).select('name phone businessName').lean();
    const buyerDisplayName = buyerUser ? buyerUser.name : 'A Buyer';

    // Create Notification Alert for the Farmer
    await Notification.create({
      userId: crop.farmerId,
      farmerId: crop.farmerId,
      title: 'New Buyer Interest',
      type: 'BUYER_INTEREST',
      message: `Buyer ${buyerDisplayName} is interested in your ${crop.commodity} crop.`,
      crop: crop.commodity,
      opportunityId: opportunity._id,
      status: 'UNREAD',
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

    // Check if farmer already expressed interest for this requirement
    const existing = await Opportunity.findOne({ requirementId, farmerId });
    if (existing) {
      return res.status(409).json({
        success: false,
        message: 'You have already expressed interest in this requirement.',
        data: { opportunity: existing },
      });
    }

    const price = offeredPrice !== undefined && offeredPrice !== null ? parseFloat(offeredPrice) : requirement.offeredPrice;

    const opportunity = await Opportunity.create({
      buyerId: requirement.buyerId,
      farmerId,
      requirementId: requirement._id,
      cropId: cropId || undefined,
      commodity: requirement.commodity,
      quantity: requirement.quantity,
      quantityUnit: requirement.quantityUnit,
      offeredPrice: price,
      status: 'INTERESTED',
      notes: (notes || '').trim(),
    });

    // Get farmer name
    const farmerUser = await User.findById(farmerId).select('name phone').lean();
    const farmerDisplayName = farmerUser ? farmerUser.name : 'A Farmer';

    // Create Notification Alert for the Buyer
    await Notification.create({
      userId: requirement.buyerId,
      farmerId: requirement.buyerId, // for backward compatibility
      title: 'Farmer Interested',
      type: 'FARMER_INTEREST',
      message: `Farmer ${farmerDisplayName} is looking to sell ${requirement.commodity} to you.`,
      crop: requirement.commodity,
      opportunityId: opportunity._id,
      status: 'UNREAD',
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
 * @desc    Get opportunities for authenticated farmer
 * @route   GET /api/opportunities/farmer-opportunities
 * @access  Private (FARMER only)
 */
const getFarmerOpportunities = async (req, res, next) => {
  try {
    const farmerId = req.user.userId;
    const { page = 1, limit = 20, status } = req.query;

    const filter = { farmerId };
    if (status && ['INTERESTED', 'ACCEPTED', 'REJECTED', 'COMPLETED', 'CANCELLED'].includes(status.toUpperCase())) {
      filter.status = status.toUpperCase();
    }

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    const [total, list] = await Promise.all([
      Opportunity.countDocuments(filter),
      Opportunity.find(filter)
        .populate('buyerId', 'name phone businessName email')
        .populate('cropId', 'commodity cropName variety expectedPrice location state district')
        .populate('requirementId', 'commodity cropName quantity quantityUnit offeredPrice state district')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limitNum)
        .lean(),
    ]);

    const formatted = await Promise.all(
      list.map(async (op) => {
        const buyerObj = op.buyerId || {};
        const buyerRatingStats = await getUserRatingStats(buyerObj._id, 'BUYER');

        return {
          id: op._id.toString(),
          buyer: {
            id: buyerObj._id ? buyerObj._id.toString() : null,
            name: buyerObj.name || 'Buyer',
            phone: buyerObj.phone || '',
            businessName: buyerObj.businessName || '',
            ratingStats: buyerRatingStats,
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
              }
            : null,
          commodity: op.commodity,
          quantity: op.quantity,
          quantityUnit: op.quantityUnit,
          offeredPrice: op.offeredPrice,
          status: op.status,
          notes: op.notes,
          createdAt: op.createdAt,
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
    const { page = 1, limit = 20, status } = req.query;

    const filter = { buyerId };
    if (status && ['INTERESTED', 'ACCEPTED', 'REJECTED', 'COMPLETED', 'CANCELLED'].includes(status.toUpperCase())) {
      filter.status = status.toUpperCase();
    }

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    const [total, list] = await Promise.all([
      Opportunity.countDocuments(filter),
      Opportunity.find(filter)
        .populate('farmerId', 'name phone verificationId gstin')
        .populate('cropId', 'commodity cropName variety expectedPrice location state district')
        .populate('requirementId', 'commodity cropName quantity quantityUnit offeredPrice state district')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limitNum)
        .lean(),
    ]);

    const formatted = await Promise.all(
      list.map(async (op) => {
        const farmerObj = op.farmerId || {};
        const farmerRatingStats = await getUserRatingStats(farmerObj._id, 'FARMER');

        return {
          id: op._id.toString(),
          farmer: {
            id: farmerObj._id ? farmerObj._id.toString() : null,
            name: farmerObj.name || 'Farmer',
            phone: op.status === 'ACCEPTED' || op.status === 'COMPLETED' ? farmerObj.phone || '' : '',
            ratingStats: farmerRatingStats,
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
              }
            : null,
          commodity: op.commodity,
          quantity: op.quantity,
          quantityUnit: op.quantityUnit,
          offeredPrice: op.offeredPrice,
          status: op.status,
          notes: op.notes,
          createdAt: op.createdAt,
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
    // Find existing interests of this buyer
    const existingInterests = await Opportunity.find({
      buyerId,
      cropId: { $in: crops.map((c) => c._id) },
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
      .populate('buyerId', 'name phone businessName email gstin')
      .populate('farmerId', 'name phone verificationId')
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

    const buyerRatingStats = await getUserRatingStats(opportunity.buyerId ? opportunity.buyerId._id : null, 'BUYER');
    const farmerRatingStats = await getUserRatingStats(opportunity.farmerId ? opportunity.farmerId._id : null, 'FARMER');

    res.status(200).json({
      success: true,
      data: {
        opportunity: {
          id: opportunity._id.toString(),
          buyer: opportunity.buyerId
            ? {
                id: opportunity.buyerId._id.toString(),
                name: opportunity.buyerId.name,
                phone: isBuyer || opportunity.status === 'ACCEPTED' || opportunity.status === 'COMPLETED' ? opportunity.buyerId.phone : '',
                businessName: opportunity.buyerId.businessName || '',
                gstin: opportunity.buyerId.gstin || '',
                ratingStats: buyerRatingStats,
              }
            : null,
          farmer: opportunity.farmerId
            ? {
                id: opportunity.farmerId._id.toString(),
                name: opportunity.farmerId.name,
                phone: isFarmer || opportunity.status === 'ACCEPTED' || opportunity.status === 'COMPLETED' ? opportunity.farmerId.phone : '',
                ratingStats: farmerRatingStats,
              }
            : null,
          crop: opportunity.cropId,
          requirement: opportunity.requirementId,
          commodity: opportunity.commodity,
          quantity: opportunity.quantity,
          quantityUnit: opportunity.quantityUnit,
          offeredPrice: opportunity.offeredPrice,
          status: opportunity.status,
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
 * @desc    Farmer accepts buyer interest
 * @route   POST /api/opportunities/:id/accept
 * @access  Private (FARMER only)
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

    if (opportunity.farmerId.toString() !== req.user.userId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You do not own this crop opportunity.',
      });
    }

    if (opportunity.status !== 'INTERESTED') {
      return res.status(400).json({
        success: false,
        message: `Cannot accept an opportunity with status ${opportunity.status}.`,
      });
    }

    opportunity.status = 'ACCEPTED';
    await opportunity.save();

    if (opportunity.cropId) {
      await Crop.findByIdAndUpdate(opportunity.cropId, { status: 'RESERVED' });
    }

    res.status(200).json({
      success: true,
      message: 'Opportunity accepted successfully',
      data: { opportunity },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Farmer rejects buyer interest
 * @route   POST /api/opportunities/:id/reject
 * @access  Private (FARMER only)
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

    if (opportunity.farmerId.toString() !== req.user.userId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You do not own this crop opportunity.',
      });
    }

    opportunity.status = 'REJECTED';
    await opportunity.save();

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
  completeOpportunity,
};
