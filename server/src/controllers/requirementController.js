const BuyerRequirement = require('../models/BuyerRequirement');

/**
 * Helper to format requirement response
 */
const formatRequirement = (reqDoc) => ({
  id: reqDoc._id.toString(),
  buyerId: reqDoc.buyerId ? reqDoc.buyerId.toString() : null,
  commodity: reqDoc.commodity,
  cropName: reqDoc.cropName || reqDoc.commodity,
  variety: reqDoc.variety,
  grade: reqDoc.grade,
  quantity: reqDoc.quantity,
  quantityUnit: reqDoc.quantityUnit,
  offeredPrice: reqDoc.offeredPrice,
  expectedPrice: reqDoc.offeredPrice,
  requiredByDate: reqDoc.requiredByDate ? reqDoc.requiredByDate.toISOString().split('T')[0] : null,
  state: reqDoc.state,
  district: reqDoc.district,
  market: reqDoc.market || '',
  location: reqDoc.location || reqDoc.market || reqDoc.district,
  notes: reqDoc.notes || '',
  status: reqDoc.status,
  createdAt: reqDoc.createdAt,
  updatedAt: reqDoc.updatedAt,
});

/**
 * @desc    Create a new buyer crop requirement
 * @route   POST /api/requirements
 * @access  Private (BUYER only)
 */
const createRequirement = async (req, res, next) => {
  try {
    const {
      commodity,
      cropName,
      variety,
      quantity,
      quantityUnit = 'kg',
      offeredPrice,
      expectedPrice,
      requiredByDate,
      state,
      district,
      market,
      location,
      notes,
    } = req.body;

    const cropIdentifier = commodity || cropName;
    if (!cropIdentifier || !cropIdentifier.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Please select a crop.',
      });
    }

    if (quantity === undefined || quantity === null || String(quantity).trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'Please enter the required quantity.',
      });
    }

    const numQuantity = parseFloat(quantity);
    if (isNaN(numQuantity) || numQuantity <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Quantity must be greater than zero.',
      });
    }

    const validUnits = ['kg', 'quintal', 'tonne'];
    const unitLower = (quantityUnit || 'kg').toString().toLowerCase();
    if (!validUnits.includes(unitLower)) {
      return res.status(400).json({
        success: false,
        message: 'Unit must be one of: kg, quintal, tonne',
      });
    }

    const rawPrice = offeredPrice !== undefined ? offeredPrice : expectedPrice;
    if (rawPrice === undefined || rawPrice === null || String(rawPrice).trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'Please enter your expected price.',
      });
    }

    const numPrice = parseFloat(rawPrice);
    if (isNaN(numPrice) || numPrice < 0) {
      return res.status(400).json({
        success: false,
        message: 'Please enter your expected price.',
      });
    }

    if (!requiredByDate) {
      return res.status(400).json({
        success: false,
        message: 'Please select the required date.',
      });
    }

    const parsedDate = new Date(requiredByDate);
    if (isNaN(parsedDate.getTime())) {
      return res.status(400).json({
        success: false,
        message: 'Please select the required date.',
      });
    }

    const locState = (state || '').trim();
    const locDistrict = (district || '').trim();
    const locGeneral = (location || market || district || '').trim();

    if (!locState && !locDistrict && !locGeneral) {
      return res.status(400).json({
        success: false,
        message: 'Please enter the location.',
      });
    }

    if (notes && notes.length > 500) {
      return res.status(400).json({
        success: false,
        message: 'Notes cannot exceed 500 characters',
      });
    }

    // Securely associate buyerId from authenticated user token
    const buyerId = req.user.userId;

    const requirement = await BuyerRequirement.create({
      buyerId,
      commodity: cropIdentifier.trim(),
      cropName: cropIdentifier.trim(),
      variety: (variety || 'Not specified').trim(),
      grade: 'Not specified',
      quantity: numQuantity,
      quantityUnit: unitLower,
      offeredPrice: numPrice,
      requiredByDate: parsedDate,
      state: locState || locDistrict || locGeneral || 'National',
      district: locDistrict || locGeneral || locState || 'National',
      market: (market || '').trim(),
      location: locGeneral || locDistrict || locState,
      notes: (notes || '').trim(),
      status: 'ACTIVE',
    });

    res.status(201).json({
      success: true,
      message: 'Requirement created successfully',
      data: {
        requirement: formatRequirement(requirement),
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get requirements listed by the authenticated buyer
 * @route   GET /api/requirements/my
 * @access  Private (BUYER only)
 */
const getMyRequirements = async (req, res, next) => {
  try {
    const buyerId = req.user.userId;
    const { page = 1, limit = 20, status } = req.query;

    const filter = { buyerId };
    if (status && ['ACTIVE', 'FULFILLED', 'CANCELLED', 'EXPIRED'].includes(status.toUpperCase())) {
      filter.status = status.toUpperCase();
    }

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    const [total, requirements] = await Promise.all([
      BuyerRequirement.countDocuments(filter),
      BuyerRequirement.find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limitNum)
        .lean(),
    ]);

    const formattedRequirements = requirements.map((r) => formatRequirement(r));

    res.status(200).json({
      success: true,
      page: pageNum,
      limit: limitNum,
      total,
      pages: Math.ceil(total / limitNum) || 1,
      data: formattedRequirements,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get single requirement details for owner buyer
 * @route   GET /api/requirements/:id
 * @access  Private (BUYER only)
 */
const getRequirementById = async (req, res, next) => {
  try {
    const requirement = await BuyerRequirement.findById(req.params.id);
    if (!requirement) {
      return res.status(404).json({
        success: false,
        message: 'Requirement not found',
      });
    }

    // Ownership check
    if (requirement.buyerId.toString() !== req.user.userId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You do not own this requirement entry.',
      });
    }

    res.status(200).json({
      success: true,
      data: {
        requirement: formatRequirement(requirement),
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Update requirement details for owner buyer
 * @route   PUT /api/requirements/:id
 * @access  Private (BUYER only)
 */
const updateRequirement = async (req, res, next) => {
  try {
    const requirement = await BuyerRequirement.findById(req.params.id);
    if (!requirement) {
      return res.status(404).json({
        success: false,
        message: 'Requirement not found',
      });
    }

    // Ownership check
    if (requirement.buyerId.toString() !== req.user.userId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You do not own this requirement entry.',
      });
    }

    // Only ACTIVE requirements can be edited
    if (requirement.status !== 'ACTIVE') {
      return res.status(409).json({
        success: false,
        message: 'This requirement can no longer be edited.',
      });
    }

    const {
      commodity,
      cropName,
      variety,
      grade,
      quantity,
      quantityUnit,
      offeredPrice,
      requiredByDate,
      state,
      district,
      market,
      location,
      notes,
    } = req.body;

    if (commodity !== undefined) {
      requirement.commodity = commodity.trim();
      requirement.cropName = cropName !== undefined ? cropName.trim() : commodity.trim();
    } else if (cropName !== undefined) {
      requirement.cropName = cropName.trim();
    }

    if (variety !== undefined) requirement.variety = variety.trim();
    if (grade !== undefined) requirement.grade = grade.trim();
    if (state !== undefined) requirement.state = state.trim();
    if (district !== undefined) requirement.district = district.trim();
    if (market !== undefined) requirement.market = market.trim();
    if (location !== undefined) requirement.location = location.trim();

    if (notes !== undefined) {
      if (notes.length > 500) {
        return res.status(400).json({
          success: false,
          message: 'Notes cannot exceed 500 characters',
        });
      }
      requirement.notes = notes.trim();
    }

    if (quantity !== undefined) {
      const numQuantity = parseFloat(quantity);
      if (isNaN(numQuantity) || numQuantity <= 0) {
        return res.status(400).json({
          success: false,
          message: 'Quantity must be greater than zero',
        });
      }
      requirement.quantity = numQuantity;
    }

    if (quantityUnit !== undefined) {
      const validUnits = ['kg', 'quintal', 'tonne'];
      if (!validUnits.includes(quantityUnit.toString().toLowerCase())) {
        return res.status(400).json({
          success: false,
          message: 'Unit must be one of: kg, quintal, tonne',
        });
      }
      requirement.quantityUnit = quantityUnit.toString().toLowerCase();
    }

    if (offeredPrice !== undefined) {
      const numPrice = parseFloat(offeredPrice);
      if (isNaN(numPrice) || numPrice < 0) {
        return res.status(400).json({
          success: false,
          message: 'Offered price must be a non-negative number',
        });
      }
      requirement.offeredPrice = numPrice;
    }

    if (requiredByDate !== undefined) {
      const parsedDate = new Date(requiredByDate);
      if (isNaN(parsedDate.getTime())) {
        return res.status(400).json({
          success: false,
          message: 'Invalid required-by date format',
        });
      }
      requirement.requiredByDate = parsedDate;
    }

    await requirement.save();

    res.status(200).json({
      success: true,
      message: 'Requirement updated successfully',
      data: {
        requirement: formatRequirement(requirement),
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Cancel a requirement entry for owner buyer
 * @route   PATCH /api/requirements/:id/cancel
 * @access  Private (BUYER only)
 */
const cancelRequirement = async (req, res, next) => {
  try {
    const requirement = await BuyerRequirement.findById(req.params.id);
    if (!requirement) {
      return res.status(404).json({
        success: false,
        message: 'Requirement not found',
      });
    }

    // Ownership check
    if (requirement.buyerId.toString() !== req.user.userId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You do not own this requirement entry.',
      });
    }

    // Only ACTIVE requirements can be cancelled
    if (requirement.status !== 'ACTIVE') {
      return res.status(409).json({
        success: false,
        message: `This requirement cannot be cancelled because it is already ${requirement.status.toLowerCase()}.`,
      });
    }

    requirement.status = 'CANCELLED';
    await requirement.save();

    res.status(200).json({
      success: true,
      message: 'Requirement cancelled successfully',
      data: {
        requirement: formatRequirement(requirement),
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Delete a requirement entry for owner buyer
 * @route   DELETE /api/requirements/:id
 * @access  Private (BUYER only)
 */
const deleteRequirement = async (req, res, next) => {
  try {
    const requirement = await BuyerRequirement.findById(req.params.id);
    if (!requirement) {
      return res.status(404).json({
        success: false,
        message: 'Requirement not found',
      });
    }

    // Ownership check
    if (requirement.buyerId.toString() !== req.user.userId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You do not own this requirement entry.',
      });
    }

    await BuyerRequirement.findByIdAndDelete(req.params.id);

    res.status(200).json({
      success: true,
      message: 'Requirement deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createRequirement,
  getMyRequirements,
  getRequirementById,
  updateRequirement,
  cancelRequirement,
  deleteRequirement,
};
