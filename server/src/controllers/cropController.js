const Crop = require('../models/Crop');
const BuyerRequirement = require('../models/BuyerRequirement');
const Notification = require('../models/Notification');
const { normalizeCropName } = require('../utils/normalizeCrop');
const { isValidCoordinates, buildGeoJsonPoint } = require('../utils/geoUtils');
const { getMarketCoordinates } = require('../utils/districtCoordinates');
const { sanitizeAddress, formatAddressParts } = require('../utils/locationResolver');

/**
 * @desc    Create a new farmer crop entry
 * @route   POST /api/crops
 * @access  Private (FARMER only)
 */
const createCrop = async (req, res, next) => {
  try {
    const {
      commodity,
      cropName,
      variety,
      grade,
      quantity,
      quantityUnit,
      expectedPrice,
      harvestDate,
      state,
      district,
      market,
      location,
      latitude,
      longitude,
      locationCoordinates,
      description,
    } = req.body;

    // Validate required fields
    if (!commodity || !cropName || !quantity || !quantityUnit || !harvestDate || !state || !district) {
      return res.status(400).json({
        success: false,
        message: 'Please provide all required fields: commodity, cropName, quantity, quantityUnit, harvestDate, state, district',
      });
    }

    const numQuantity = parseFloat(quantity);
    if (isNaN(numQuantity) || numQuantity <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Quantity must be a positive number greater than zero',
      });
    }

    const unit = (quantityUnit || 'quintal').toString().toLowerCase().trim();
    if (unit !== 'quintal') {
      return res.status(400).json({
        success: false,
        message: "Only 'quintal' is supported as the quantity unit. KG and other units are not supported.",
      });
    }

    const parsedDate = new Date(harvestDate);
    if (isNaN(parsedDate.getTime())) {
      return res.status(400).json({
        success: false,
        message: 'Invalid harvest date format',
      });
    }

    const numPrice = expectedPrice !== undefined && expectedPrice !== null ? parseFloat(expectedPrice) : 0;
    if (isNaN(numPrice) || numPrice < 0) {
      return res.status(400).json({
        success: false,
        message: 'Expected price must be a non-negative number',
      });
    }

    // Derive farmerId strictly from authenticated token
    const farmerId = req.user.userId;

    const cleanState = sanitizeAddress(state);
    const cleanDistrict = sanitizeAddress(district);
    const cleanMarket = sanitizeAddress(market);
    const cleanLoc = sanitizeAddress(location) || formatAddressParts(cleanMarket, cleanDistrict, cleanState);

    let cropGeoPoint = undefined;
    if (isValidCoordinates(latitude, longitude)) {
      cropGeoPoint = buildGeoJsonPoint(Number(longitude), Number(latitude));
    } else if (
      locationCoordinates &&
      typeof locationCoordinates === 'object' &&
      Array.isArray(locationCoordinates.coordinates) &&
      locationCoordinates.coordinates.length === 2 &&
      isValidCoordinates(locationCoordinates.coordinates[1], locationCoordinates.coordinates[0])
    ) {
      cropGeoPoint = {
        type: 'Point',
        coordinates: [Number(locationCoordinates.coordinates[0]), Number(locationCoordinates.coordinates[1])],
      };
    } else if (cleanState || cleanDistrict || cleanMarket) {
      const coords = getMarketCoordinates(cleanState, cleanDistrict, cleanMarket);
      if (coords && isValidCoordinates(coords.lat, coords.lng)) {
        cropGeoPoint = buildGeoJsonPoint(coords.lng, coords.lat);
      }
    }

    const crop = await Crop.create({
      farmerId,
      commodity: commodity.trim(),
      cropName: cropName.trim(),
      variety: (variety || 'Other').trim(),
      grade: (grade || 'FAQ').trim(),
      quantity: numQuantity,
      quantityUnit: quantityUnit.toLowerCase(),
      expectedPrice: numPrice,
      harvestDate: parsedDate,
      state: cleanState,
      district: cleanDistrict,
      market: cleanMarket,
      location: cleanLoc,
      locationCoordinates: cropGeoPoint,
      description: (description || '').trim(),
      status: 'AVAILABLE',
    });

    // Check for matching active buyer requirements and notify them (Future Match)
    try {
      const matchingReqs = await BuyerRequirement.find({
        commodity: new RegExp(`^${commodity.trim()}$`, 'i'),
        status: 'ACTIVE',
      }).limit(10).lean();

      for (const reqItem of matchingReqs) {
        if (reqItem.buyerId) {
          const alertKey = `FUTURE_MATCH_BUYER_${reqItem.buyerId}_${crop._id}`;
          const existingNotif = await Notification.findOne({ alertKey });
          if (!existingNotif) {
            await Notification.create({
              userId: reqItem.buyerId,
              recipientRole: 'BUYER',
              type: 'MATCH_FOUND',
              title: 'New Farmer Crop Available',
              message: `Good news! A Farmer matching your ${crop.commodity} requirement is now available with ${crop.quantity} Quintals.`,
              crop: crop.commodity,
              alertKey,
            });
          }
        }
      }
    } catch (_) {
      // Future match notification is non-blocking
    }

    res.status(201).json({
      success: true,
      message: 'Crop added successfully',
      data: {
        crop: {
          id: crop._id.toString(),
          farmerId: crop.farmerId.toString(),
          commodity: crop.commodity,
          cropName: crop.cropName,
          variety: crop.variety,
          grade: crop.grade,
          quantity: crop.quantity,
          quantityUnit: crop.quantityUnit,
          expectedPrice: crop.expectedPrice,
          harvestDate: crop.harvestDate.toISOString().split('T')[0],
          state: crop.state,
          district: crop.district,
          market: crop.market,
          location: crop.location,
          description: crop.description,
          status: crop.status,
          createdAt: crop.createdAt,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get crops listed by the authenticated farmer
 * @route   GET /api/crops/my
 * @access  Private (FARMER only)
 */
const getMyCrops = async (req, res, next) => {
  try {
    const farmerId = req.user.userId;
    const { page = 1, limit = 20, status } = req.query;

    const filter = { farmerId };
    if (status && ['AVAILABLE', 'RESERVED', 'SOLD', 'CANCELLED'].includes(status.toUpperCase())) {
      filter.status = status.toUpperCase();
    }

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    const [total, crops] = await Promise.all([
      Crop.countDocuments(filter),
      Crop.find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limitNum)
        .lean(),
    ]);

    const formattedCrops = crops.map((c) => ({
      id: c._id.toString(),
      farmerId: c.farmerId.toString(),
      commodity: c.commodity,
      cropName: c.cropName,
      variety: c.variety,
      grade: c.grade,
      quantity: c.quantity,
      quantityUnit: c.quantityUnit,
      expectedPrice: c.expectedPrice,
      harvestDate: c.harvestDate ? c.harvestDate.toISOString().split('T')[0] : null,
      state: c.state,
      district: c.district,
      market: c.market,
      location: c.location,
      description: c.description,
      status: c.status,
      createdAt: c.createdAt,
    }));

    res.status(200).json({
      success: true,
      page: pageNum,
      limit: limitNum,
      total,
      pages: Math.ceil(total / limitNum),
      data: formattedCrops,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get single crop details for owner farmer
 * @route   GET /api/crops/:id
 * @access  Private (FARMER only)
 */
const getCropById = async (req, res, next) => {
  try {
    const crop = await Crop.findById(req.params.id);
    if (!crop) {
      return res.status(404).json({
        success: false,
        message: 'Crop not found',
      });
    }

    // Ownership check
    if (crop.farmerId.toString() !== req.user.userId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You do not own this crop entry.',
      });
    }

    res.status(200).json({
      success: true,
      data: {
        crop: {
          id: crop._id.toString(),
          commodity: crop.commodity,
          cropName: crop.cropName,
          variety: crop.variety,
          grade: crop.grade,
          quantity: crop.quantity,
          quantityUnit: crop.quantityUnit,
          expectedPrice: crop.expectedPrice,
          harvestDate: crop.harvestDate ? crop.harvestDate.toISOString().split('T')[0] : null,
          state: crop.state,
          district: crop.district,
          market: crop.market,
          location: crop.location,
          description: crop.description,
          status: crop.status,
          createdAt: crop.createdAt,
          updatedAt: crop.updatedAt,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Update crop details for owner farmer
 * @route   PUT /api/crops/:id
 * @access  Private (FARMER only)
 */
const updateCrop = async (req, res, next) => {
  try {
    const crop = await Crop.findById(req.params.id);
    if (!crop) {
      return res.status(404).json({
        success: false,
        message: 'Crop not found',
      });
    }

    // Ownership check
    if (crop.farmerId.toString() !== req.user.userId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You do not own this crop entry.',
      });
    }

    if (crop.status === 'SOLD') {
      return res.status(409).json({
        success: false,
        message: 'Cannot edit a crop that has already been sold.',
      });
    }

    const {
      commodity,
      cropName,
      variety,
      grade,
      quantity,
      quantityUnit,
      expectedPrice,
      harvestDate,
      state,
      district,
      market,
      location,
      description,
    } = req.body;

    if (commodity !== undefined) crop.commodity = commodity.trim();
    if (cropName !== undefined) crop.cropName = cropName.trim();
    if (variety !== undefined) crop.variety = variety.trim();
    if (grade !== undefined) crop.grade = grade.trim();
    if (state !== undefined) crop.state = state.trim();
    if (district !== undefined) crop.district = district.trim();
    if (market !== undefined) crop.market = market.trim();
    if (location !== undefined) crop.location = location.trim();
    if (description !== undefined) crop.description = description.trim();

    if (quantity !== undefined) {
      const numQuantity = parseFloat(quantity);
      if (isNaN(numQuantity) || numQuantity <= 0) {
        return res.status(400).json({
          success: false,
          message: 'Quantity must be a positive number greater than zero',
        });
      }
      crop.quantity = numQuantity;
    }

    if (quantityUnit !== undefined) {
      const unit = quantityUnit.toString().toLowerCase().trim();
      if (unit !== 'quintal') {
        return res.status(400).json({
          success: false,
          message: "Only 'quintal' is supported as the quantity unit.",
        });
      }
      crop.quantityUnit = 'quintal';
    }

    if (expectedPrice !== undefined) {
      const numPrice = parseFloat(expectedPrice);
      if (isNaN(numPrice) || numPrice < 0) {
        return res.status(400).json({
          success: false,
          message: 'Expected price must be a non-negative number',
        });
      }
      crop.expectedPrice = numPrice;
    }

    if (harvestDate !== undefined) {
      const parsedDate = new Date(harvestDate);
      if (isNaN(parsedDate.getTime())) {
        return res.status(400).json({
          success: false,
          message: 'Invalid harvest date format',
        });
      }
      crop.harvestDate = parsedDate;
    }

    await crop.save();

    res.status(200).json({
      success: true,
      message: 'Crop updated successfully',
      data: {
        crop: {
          id: crop._id.toString(),
          commodity: crop.commodity,
          cropName: crop.cropName,
          variety: crop.variety,
          grade: crop.grade,
          quantity: crop.quantity,
          quantityUnit: crop.quantityUnit,
          expectedPrice: crop.expectedPrice,
          harvestDate: crop.harvestDate ? crop.harvestDate.toISOString().split('T')[0] : null,
          state: crop.state,
          district: crop.district,
          market: crop.market,
          location: crop.location,
          description: crop.description,
          status: crop.status,
          updatedAt: crop.updatedAt,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Delete a crop entry for owner farmer
 * @route   DELETE /api/crops/:id
 * @access  Private (FARMER only)
 */
const deleteCrop = async (req, res, next) => {
  try {
    const crop = await Crop.findById(req.params.id);
    if (!crop) {
      return res.status(404).json({
        success: false,
        message: 'Crop not found',
      });
    }

    // Ownership check
    if (crop.farmerId.toString() !== req.user.userId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You do not own this crop entry.',
      });
    }

    // State check
    if (crop.status === 'RESERVED' || crop.status === 'SOLD') {
      return res.status(409).json({
        success: false,
        message: `This crop cannot be deleted because it is already ${crop.status.toLowerCase()}.`,
      });
    }

    await Crop.findByIdAndDelete(req.params.id);

    res.status(200).json({
      success: true,
      message: 'Crop deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createCrop,
  getMyCrops,
  getCropById,
  updateCrop,
  deleteCrop,
};
