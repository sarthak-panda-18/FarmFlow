const Deal = require('../models/Deal');
const Opportunity = require('../models/Opportunity');
const Crop = require('../models/Crop');
const BuyerRequirement = require('../models/BuyerRequirement');
const User = require('../models/User');
const Notification = require('../models/Notification');
const Rating = require('../models/Rating');
const { calculateHaversineDistance, buildGoogleMapsUrl } = require('../utils/geoUtils');
const { getUserRatingStats } = require('../utils/ratingHelper');

/**
 * Creates or retrieves a Deal from an ACCEPTED Opportunity
 * @route POST /api/deals
 * @access Private
 */
const createDealFromOpportunity = async (req, res, next) => {
  try {
    const currentUserId = req.user.userId;
    const { opportunityId, transportCost, otherCosts, transportType, deliveryDate } = req.body;

    if (!opportunityId) {
      return res.status(400).json({
        success: false,
        message: 'Opportunity ID is required to create a deal',
      });
    }

    const opportunity = await Opportunity.findById(opportunityId);
    if (!opportunity) {
      return res.status(404).json({
        success: false,
        message: 'Opportunity not found',
      });
    }

    const isFarmer = opportunity.farmerId.toString() === currentUserId;
    const isBuyer = opportunity.buyerId.toString() === currentUserId;

    if (!isFarmer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized. You are not a party to this opportunity.',
      });
    }

    // Opportunity must be ACCEPTED or COMPLETED to create a deal
    const opStatus = (opportunity.status || '').toUpperCase();
    if (opStatus !== 'ACCEPTED' && opStatus !== 'COMPLETED') {
      return res.status(400).json({
        success: false,
        message: `Deal can only be created for an ACCEPTED opportunity. Current status: ${opStatus}`,
      });
    }

    // Check if Deal already exists for this opportunity
    let existingDeal = await Deal.findOne({ opportunityId });
    if (existingDeal) {
      return res.status(200).json({
        success: true,
        message: 'Deal already exists for this opportunity',
        data: existingDeal,
      });
    }

    // Fetch Farmer and Buyer details for location & coordinates
    const farmer = await User.findById(opportunity.farmerId).select('name phone location coordinates district state').lean();
    const buyer = await User.findById(opportunity.buyerId).select('name phone location coordinates businessName district state').lean();

    // Fetch crop details if available
    let cropDetails = null;
    if (opportunity.cropId || opportunity.farmerCropId) {
      cropDetails = await Crop.findById(opportunity.cropId || opportunity.farmerCropId).lean();
    }

    // Compute coordinates & distance
    let pickupLat = null;
    let pickupLng = null;
    let pickupAddr = farmer ? (farmer.address || `${farmer.district || ''}, ${farmer.state || ''}`) : '';

    if (farmer && farmer.location && Array.isArray(farmer.location.coordinates) && farmer.location.coordinates.length === 2) {
      pickupLng = farmer.location.coordinates[0];
      pickupLat = farmer.location.coordinates[1];
    } else if (farmer && farmer.coordinates && farmer.coordinates.latitude != null) {
      pickupLat = farmer.coordinates.latitude;
      pickupLng = farmer.coordinates.longitude;
    } else if (cropDetails && cropDetails.coordinates && cropDetails.coordinates.latitude != null) {
      pickupLat = cropDetails.coordinates.latitude;
      pickupLng = cropDetails.coordinates.longitude;
    }

    let deliveryLat = null;
    let deliveryLng = null;
    let deliveryAddr = buyer ? (buyer.address || `${buyer.district || ''}, ${buyer.state || ''}`) : '';

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

    const newDeal = new Deal({
      farmerId: opportunity.farmerId,
      buyerId: opportunity.buyerId,
      opportunityId: opportunity._id,
      farmerCropId: opportunity.cropId || opportunity.farmerCropId,
      cropId: opportunity.cropId || opportunity.farmerCropId,
      buyerRequirementId: opportunity.requirementId || opportunity.buyerRequirementId,
      requirementId: opportunity.requirementId || opportunity.buyerRequirementId,
      commodity: opportunity.commodity || (cropDetails ? cropDetails.commodity : 'Crop'),
      crop: opportunity.commodity || (cropDetails ? cropDetails.cropName : 'Crop'),
      variety: cropDetails ? cropDetails.variety || '' : '',
      quantity: opportunity.quantity,
      quantityUnit: 'quintal',
      agreedPrice: opportunity.offeredPrice,
      agreedPriceUnit: 'quintal',
      agreedDate: opportunity.updatedAt || new Date(),
      deliveryDate: deliveryDate ? new Date(deliveryDate) : null,
      status: 'AGREEMENT_PENDING',
      agreementStatus: 'AGREEMENT_PENDING',
      farmerAccepted: false,
      buyerAccepted: false,
      agreementVersion: 1,
      termsAcceptedVersion: 1,
      pickupLocation: {
        address: pickupAddr,
        latitude: pickupLat,
        longitude: pickupLng,
      },
      deliveryLocation: {
        address: deliveryAddr,
        latitude: deliveryLat,
        longitude: deliveryLng,
      },
      distanceKm: distance,
      transportRequired: true,
      transportType: transportType || 'Standard Road Transport',
      transportCost: Number(transportCost) || 0,
      otherCosts: Number(otherCosts) || 0,
      logisticsStatus: 'PLANNED',
      paymentStatus: 'PAYMENT_PENDING',
      paymentMethod: 'External / Direct Payment',
    });

    await newDeal.save();

    // Create Notification for the other party
    const targetUserId = isFarmer ? opportunity.buyerId : opportunity.farmerId;
    const targetRole = isFarmer ? 'BUYER' : 'FARMER';
    const creatorName = isFarmer ? (farmer ? farmer.name : 'Farmer') : (buyer ? buyer.name : 'Buyer');

    await Notification.create({
      userId: targetUserId,
      recipientRole: targetRole,
      type: 'AGREEMENT_PENDING',
      title: 'Deal Agreement Created',
      message: `${creatorName} created an Official Deal Agreement for ${newDeal.commodity} (${newDeal.quantity} Quintals). Please review and accept terms.`,
      crop: newDeal.commodity,
      dealId: newDeal._id,
      opportunityId: opportunity._id,
    });

    res.status(201).json({
      success: true,
      message: 'Official Deal Agreement created successfully in pending state',
      data: newDeal,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get deals for the logged-in Farmer
 * @route GET /api/deals/farmer
 * @access Private (FARMER)
 */
const getFarmerDeals = async (req, res, next) => {
  try {
    const farmerId = req.user.userId;
    const { status, page = 1, limit = 50 } = req.query;

    const query = { farmerId };
    if (status && status !== 'ALL') {
      query.status = status.toUpperCase();
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const deals = await Deal.find(query)
      .populate('buyerId', 'name phone location businessName coordinates ratingStats')
      .populate('opportunityId', 'status offeredPrice')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .lean();

    const total = await Deal.countDocuments(query);

    res.status(200).json({
      success: true,
      data: deals,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit)),
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get deals for the logged-in Buyer
 * @route GET /api/deals/buyer
 * @access Private (BUYER)
 */
const getBuyerDeals = async (req, res, next) => {
  try {
    const buyerId = req.user.userId;
    const { status, page = 1, limit = 50 } = req.query;

    const query = { buyerId };
    if (status && status !== 'ALL') {
      query.status = status.toUpperCase();
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const deals = await Deal.find(query)
      .populate('farmerId', 'name phone location coordinates ratingStats')
      .populate('opportunityId', 'status offeredPrice')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .lean();

    const total = await Deal.countDocuments(query);

    res.status(200).json({
      success: true,
      data: deals,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit)),
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get single Deal by ID with authorization and computed Maps links
 * @route GET /api/deals/:id
 * @access Private
 */
const getDealById = async (req, res, next) => {
  try {
    const currentUserId = req.user.userId;
    const deal = await Deal.findById(req.params.id)
      .populate('farmerId', 'name phone location coordinates district state')
      .populate('buyerId', 'name phone location coordinates businessName district state')
      .populate('opportunityId');

    if (!deal) {
      return res.status(404).json({
        success: false,
        message: 'Deal not found',
      });
    }

    const isFarmer = deal.farmerId._id.toString() === currentUserId;
    const isBuyer = deal.buyerId._id.toString() === currentUserId;

    if (!isFarmer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You are not a party to this deal.',
      });
    }

    // Fetch rating statistics
    const farmerStats = await getUserRatingStats(deal.farmerId._id, 'FARMER');
    const buyerStats = await getUserRatingStats(deal.buyerId._id, 'BUYER');

    // Build Google Maps URLs
    let pickupMapsUrl = null;
    if (deal.pickupLocation && deal.pickupLocation.latitude != null && deal.pickupLocation.longitude != null) {
      pickupMapsUrl = `https://www.google.com/maps/search/?api=1&query=${deal.pickupLocation.latitude},${deal.pickupLocation.longitude}`;
    }

    let deliveryMapsUrl = null;
    if (deal.deliveryLocation && deal.deliveryLocation.latitude != null && deal.deliveryLocation.longitude != null) {
      deliveryMapsUrl = `https://www.google.com/maps/search/?api=1&query=${deal.deliveryLocation.latitude},${deal.deliveryLocation.longitude}`;
    }

    const dealObj = deal.toObject();
    dealObj.farmer = {
      ...dealObj.farmerId,
      ratingStats: farmerStats,
    };
    dealObj.buyer = {
      ...dealObj.buyerId,
      ratingStats: buyerStats,
    };
    dealObj.pickupMapsUrl = pickupMapsUrl;
    dealObj.deliveryMapsUrl = deliveryMapsUrl;

    res.status(200).json({
      success: true,
      data: dealObj,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Update Deal status (CONFIRMED -> PREPARING -> READY_FOR_PICKUP -> IN_TRANSIT -> DELIVERED -> COMPLETED)
 * @route PATCH /api/deals/:id/status
 * @access Private
 */
const updateDealStatus = async (req, res, next) => {
  try {
    const currentUserId = req.user.userId;
    const { status, notes } = req.body;

    if (!status) {
      return res.status(400).json({
        success: false,
        message: 'Status is required',
      });
    }

    const validStatuses = [
      'CONFIRMED',
      'PREPARING',
      'READY_FOR_PICKUP',
      'IN_TRANSIT',
      'DELIVERED',
      'PAYMENT_PENDING',
      'COMPLETED',
      'CANCELLED',
      'DISPUTED',
    ];

    const normalizedStatus = status.toUpperCase();
    if (!validStatuses.includes(normalizedStatus)) {
      return res.status(400).json({
        success: false,
        message: `Invalid deal status: ${status}`,
      });
    }

    const deal = await Deal.findById(req.params.id);
    if (!deal) {
      return res.status(404).json({
        success: false,
        message: 'Deal not found',
      });
    }

    const isFarmer = deal.farmerId.toString() === currentUserId;
    const isBuyer = deal.buyerId.toString() === currentUserId;

    if (!isFarmer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized. You are not a party to this deal.',
      });
    }

    deal.status = normalizedStatus;
    if (normalizedStatus === 'DELIVERED') {
      deal.logisticsStatus = 'DELIVERED';
      deal.deliveredAt = new Date();
      deal.deliveredConfirmedBy = currentUserId;
    } else if (normalizedStatus === 'COMPLETED') {
      deal.completedAt = new Date();
    }

    await deal.save();

    // Notify other party
    const targetUserId = isFarmer ? deal.buyerId : deal.farmerId;
    const targetRole = isFarmer ? 'BUYER' : 'FARMER';
    const actorRole = isFarmer ? 'Farmer' : 'Buyer';

    await Notification.create({
      userId: targetUserId,
      recipientRole: targetRole,
      type: 'DELIVERY_UPDATED',
      title: 'Deal Status Updated',
      message: `${actorRole} updated deal status for ${deal.commodity} to ${deal.status}.`,
      crop: deal.commodity,
      dealId: deal._id,
      opportunityId: deal.opportunityId,
    });

    res.status(200).json({
      success: true,
      message: `Deal status updated to ${deal.status}`,
      data: deal,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Update Logistics & Cost breakdown (Phase 11)
 * @route PATCH /api/deals/:id/logistics
 * @access Private
 */
const updateDealLogistics = async (req, res, next) => {
  try {
    const currentUserId = req.user.userId;
    const {
      pickupLocation,
      deliveryLocation,
      transportRequired,
      transportType,
      transportCost,
      otherCosts,
      otherCostsBreakdown,
      logisticsStatus,
      deliveryDate,
    } = req.body;

    const deal = await Deal.findById(req.params.id);
    if (!deal) {
      return res.status(404).json({
        success: false,
        message: 'Deal not found',
      });
    }

    const isFarmer = deal.farmerId.toString() === currentUserId;
    const isBuyer = deal.buyerId.toString() === currentUserId;

    if (!isFarmer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized. You are not a party to this deal.',
      });
    }

    if (pickupLocation && typeof pickupLocation === 'object') {
      deal.pickupLocation = {
        address: pickupLocation.address || deal.pickupLocation.address,
        latitude: pickupLocation.latitude != null ? pickupLocation.latitude : deal.pickupLocation.latitude,
        longitude: pickupLocation.longitude != null ? pickupLocation.longitude : deal.pickupLocation.longitude,
      };
    }

    if (deliveryLocation && typeof deliveryLocation === 'object') {
      deal.deliveryLocation = {
        address: deliveryLocation.address || deal.deliveryLocation.address,
        latitude: deliveryLocation.latitude != null ? deliveryLocation.latitude : deal.deliveryLocation.latitude,
        longitude: deliveryLocation.longitude != null ? deliveryLocation.longitude : deal.deliveryLocation.longitude,
      };
    }

    if (deal.pickupLocation.latitude != null && deal.deliveryLocation.latitude != null) {
      deal.distanceKm = calculateHaversineDistance(
        deal.pickupLocation.latitude,
        deal.pickupLocation.longitude,
        deal.deliveryLocation.latitude,
        deal.deliveryLocation.longitude
      );
    }

    if (transportRequired !== undefined) deal.transportRequired = Boolean(transportRequired);
    if (transportType !== undefined) deal.transportType = transportType;
    if (transportCost !== undefined) deal.transportCost = Math.max(0, Number(transportCost) || 0);
    if (otherCosts !== undefined) deal.otherCosts = Math.max(0, Number(otherCosts) || 0);
    if (otherCostsBreakdown && typeof otherCostsBreakdown === 'object') {
      deal.otherCostsBreakdown = {
        packaging: Number(otherCostsBreakdown.packaging) || 0,
        loading: Number(otherCostsBreakdown.loading) || 0,
        unloading: Number(otherCostsBreakdown.unloading) || 0,
        handling: Number(otherCostsBreakdown.handling) || 0,
      };
    }
    if (logisticsStatus) deal.logisticsStatus = logisticsStatus;
    if (deliveryDate) deal.deliveryDate = new Date(deliveryDate);

    await deal.save();

    // Notify other party
    const targetUserId = isFarmer ? deal.buyerId : deal.farmerId;
    const targetRole = isFarmer ? 'BUYER' : 'FARMER';
    const actorRole = isFarmer ? 'Farmer' : 'Buyer';

    await Notification.create({
      userId: targetUserId,
      recipientRole: targetRole,
      type: 'DELIVERY_UPDATED',
      title: 'Logistics Updated',
      message: `${actorRole} updated logistics details for ${deal.commodity}. Estimated Net Return: ₹${deal.estimatedNetReturn.toFixed(0)}.`,
      crop: deal.commodity,
      dealId: deal._id,
      opportunityId: deal.opportunityId,
    });

    res.status(200).json({
      success: true,
      message: 'Logistics details updated successfully',
      data: deal,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Mark Deal as Delivered (Phase 11)
 * @route PATCH /api/deals/:id/deliver
 * @access Private
 */
const markDelivered = async (req, res, next) => {
  try {
    const currentUserId = req.user.userId;
    const deal = await Deal.findById(req.params.id);

    if (!deal) {
      return res.status(404).json({
        success: false,
        message: 'Deal not found',
      });
    }

    const isFarmer = deal.farmerId.toString() === currentUserId;
    const isBuyer = deal.buyerId.toString() === currentUserId;

    if (!isFarmer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized. You are not a party to this deal.',
      });
    }

    if (deal.status === 'CANCELLED') {
      return res.status(400).json({
        success: false,
        message: 'Cannot mark a cancelled deal as delivered.',
      });
    }

    deal.status = 'DELIVERED';
    deal.logisticsStatus = 'DELIVERED';
    deal.deliveredAt = new Date();
    deal.deliveredConfirmedBy = currentUserId;

    // If payment was already confirmed, mark as COMPLETED
    if (deal.paymentStatus === 'PAYMENT_CONFIRMED_BY_BOTH') {
      deal.status = 'COMPLETED';
      deal.completedAt = new Date();
    }

    await deal.save();

    const targetUserId = isFarmer ? deal.buyerId : deal.farmerId;
    const targetRole = isFarmer ? 'BUYER' : 'FARMER';
    const actorRole = isFarmer ? 'Farmer' : 'Buyer';

    await Notification.create({
      userId: targetUserId,
      recipientRole: targetRole,
      type: 'DEAL_DELIVERED',
      title: 'Goods Delivered',
      message: `${actorRole} confirmed delivery of ${deal.commodity} (${deal.quantity} ${deal.quantityUnit}).`,
      crop: deal.commodity,
      dealId: deal._id,
      opportunityId: deal.opportunityId,
    });

    res.status(200).json({
      success: true,
      message: 'Deal marked as delivered successfully',
      data: deal,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Cancel a Deal if in cancellable state
 * @route PATCH /api/deals/:id/cancel
 * @access Private
 */
const cancelDeal = async (req, res, next) => {
  try {
    const currentUserId = req.user.userId;
    const { reason } = req.body;

    const deal = await Deal.findById(req.params.id);
    if (!deal) {
      return res.status(404).json({
        success: false,
        message: 'Deal not found',
      });
    }

    const isFarmer = deal.farmerId.toString() === currentUserId;
    const isBuyer = deal.buyerId.toString() === currentUserId;

    if (!isFarmer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized. You are not a party to this deal.',
      });
    }

    if (deal.status === 'COMPLETED' || deal.status === 'DELIVERED') {
      return res.status(400).json({
        success: false,
        message: `Deal cannot be cancelled once it is ${deal.status}.`,
      });
    }

    if (deal.status === 'CANCELLED') {
      return res.status(400).json({
        success: false,
        message: 'Deal is already cancelled.',
      });
    }

    deal.status = 'CANCELLED';
    deal.cancellationReason = reason || 'Cancelled by user';
    deal.cancelledBy = currentUserId;
    deal.cancelledAt = new Date();

    await deal.save();

    // Release crop reservation if farmer crop exists
    if (deal.cropId) {
      await Crop.findByIdAndUpdate(deal.cropId, { status: 'AVAILABLE' });
    }

    const targetUserId = isFarmer ? deal.buyerId : deal.farmerId;
    const targetRole = isFarmer ? 'BUYER' : 'FARMER';
    const actorRole = isFarmer ? 'Farmer' : 'Buyer';

    await Notification.create({
      userId: targetUserId,
      recipientRole: targetRole,
      type: 'DEAL_CANCELLED',
      title: 'Deal Cancelled',
      message: `${actorRole} cancelled the deal for ${deal.commodity}. Reason: ${deal.cancellationReason}`,
      crop: deal.commodity,
      dealId: deal._id,
      opportunityId: deal.opportunityId,
    });

    res.status(200).json({
      success: true,
      message: 'Deal cancelled successfully',
      data: deal,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Report Payment Made (Phase 10 External Payment Tracking)
 * @route PATCH /api/deals/:id/payment/report
 * @access Private
 */
const reportPaymentMade = async (req, res, next) => {
  try {
    const currentUserId = req.user.userId;
    const { notes } = req.body;

    const deal = await Deal.findById(req.params.id);
    if (!deal) {
      return res.status(404).json({
        success: false,
        message: 'Deal not found',
      });
    }

    const isFarmer = deal.farmerId.toString() === currentUserId;
    const isBuyer = deal.buyerId.toString() === currentUserId;

    if (!isFarmer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized. You are not a party to this deal.',
      });
    }

    if (deal.paymentStatus === 'PAYMENT_CONFIRMED_BY_BOTH') {
      return res.status(400).json({
        success: false,
        message: 'Payment is already confirmed by both parties.',
      });
    }

    const reporterRole = isFarmer ? 'FARMER' : 'BUYER';
    deal.paymentStatus = 'PAYMENT_REPORTED';
    deal.paymentReportedBy = currentUserId;
    deal.paymentReportedByRole = reporterRole;
    deal.paymentReportedAt = new Date();
    deal.paymentReportedNotes = (notes || '').trim();
    deal.paymentDisputed = false;

    await deal.save();

    // Notify receiving counterparty
    const targetUserId = isFarmer ? deal.buyerId : deal.farmerId;
    const targetRole = isFarmer ? 'BUYER' : 'FARMER';
    const reporterName = isFarmer ? 'Farmer' : 'Buyer';

    await Notification.create({
      userId: targetUserId,
      recipientRole: targetRole,
      type: 'PAYMENT_REPORTED',
      title: 'Payment Reported',
      message: `${reporterName} reported that direct payment was completed for ${deal.commodity}. Please verify and confirm receipt.`,
      crop: deal.commodity,
      dealId: deal._id,
      opportunityId: deal.opportunityId,
    });

    res.status(200).json({
      success: true,
      message: 'Payment report submitted. Waiting for receiving party to confirm receipt.',
      data: deal,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Confirm Payment Received (Phase 10 External Payment Tracking)
 * CRITICAL SAFETY: Only the receiving party can confirm receipt (Self-confirmation blocked)
 * @route PATCH /api/deals/:id/payment/confirm
 * @access Private
 */
const confirmPaymentReceived = async (req, res, next) => {
  try {
    const currentUserId = req.user.userId;
    const deal = await Deal.findById(req.params.id);

    if (!deal) {
      return res.status(404).json({
        success: false,
        message: 'Deal not found',
      });
    }

    const isFarmer = deal.farmerId.toString() === currentUserId;
    const isBuyer = deal.buyerId.toString() === currentUserId;

    if (!isFarmer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized. You are not a party to this deal.',
      });
    }

    // PREVENT SELF-CONFIRMATION FRAUD:
    // If a user reported payment, they CANNOT confirm their own payment report!
    if (deal.paymentReportedBy && deal.paymentReportedBy.toString() === currentUserId) {
      return res.status(403).json({
        success: false,
        message: 'Security Violation: You cannot confirm receipt of a payment you reported yourself. Only the receiving party can confirm.',
      });
    }

    if (deal.paymentStatus !== 'PAYMENT_REPORTED' && deal.paymentStatus !== 'PAYMENT_DISPUTED' && deal.paymentStatus !== 'PAYMENT_PENDING') {
      return res.status(400).json({
        success: false,
        message: `Payment status is ${deal.paymentStatus}.`,
      });
    }

    deal.paymentStatus = 'PAYMENT_CONFIRMED_BY_BOTH';
    deal.paymentConfirmedBy = currentUserId;
    deal.paymentConfirmedAt = new Date();
    deal.paymentDisputed = false;
    deal.paymentDisputeReason = '';

    // If deal is also delivered, mark as COMPLETED
    if (deal.status === 'DELIVERED' || deal.logisticsStatus === 'DELIVERED') {
      deal.status = 'COMPLETED';
      deal.completedAt = new Date();
    }

    await deal.save();

    // Notify the other party
    const targetUserId = isFarmer ? deal.buyerId : deal.farmerId;
    const targetRole = isFarmer ? 'BUYER' : 'FARMER';
    const receiverRole = isFarmer ? 'Farmer' : 'Buyer';

    await Notification.create({
      userId: targetUserId,
      recipientRole: targetRole,
      type: 'PAYMENT_CONFIRMED',
      title: 'Payment Confirmed',
      message: `${receiverRole} confirmed receipt of direct payment for ${deal.commodity}.`,
      crop: deal.commodity,
      dealId: deal._id,
      opportunityId: deal.opportunityId,
    });

    res.status(200).json({
      success: true,
      message: 'Payment receipt confirmed successfully.',
      data: deal,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Dispute Payment (Phase 10 External Payment Tracking)
 * @route PATCH /api/deals/:id/payment/dispute
 * @access Private
 */
const disputePayment = async (req, res, next) => {
  try {
    const currentUserId = req.user.userId;
    const { reason } = req.body;

    const deal = await Deal.findById(req.params.id);
    if (!deal) {
      return res.status(404).json({
        success: false,
        message: 'Deal not found',
      });
    }

    const isFarmer = deal.farmerId.toString() === currentUserId;
    const isBuyer = deal.buyerId.toString() === currentUserId;

    if (!isFarmer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized. You are not a party to this deal.',
      });
    }

    deal.paymentStatus = 'PAYMENT_DISPUTED';
    deal.paymentDisputed = true;
    deal.paymentDisputeReason = (reason || 'Payment has not been received.').trim();
    deal.paymentDisputedBy = currentUserId;
    deal.paymentDisputedAt = new Date();

    await deal.save();

    const targetUserId = isFarmer ? deal.buyerId : deal.farmerId;
    const targetRole = isFarmer ? 'BUYER' : 'FARMER';
    const disputerRole = isFarmer ? 'Farmer' : 'Buyer';

    await Notification.create({
      userId: targetUserId,
      recipientRole: targetRole,
      type: 'PAYMENT_DISPUTED',
      title: 'Payment Issue Reported',
      message: `${disputerRole} reported an issue regarding payment for ${deal.commodity}: "${deal.paymentDisputeReason}". Please resolve directly with counterparty.`,
      crop: deal.commodity,
      dealId: deal._id,
      opportunityId: deal.opportunityId,
    });

    res.status(200).json({
      success: true,
      message: 'Payment issue recorded. Please resolve payment directly between the Farmer and Buyer.',
      data: deal,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Rate a Deal after completion/delivery (Phase 12)
 * @route POST /api/deals/:id/ratings
 * @access Private
 */
const rateDeal = async (req, res, next) => {
  try {
    const currentUserId = req.user.userId;
    const { rating, feedback, comment, categoryRatings } = req.body;

    if (!rating) {
      return res.status(400).json({
        success: false,
        message: 'Rating is required',
      });
    }

    const numRating = parseInt(rating, 10);
    if (isNaN(numRating) || numRating < 1 || numRating > 5) {
      return res.status(400).json({
        success: false,
        message: 'Rating must be an integer between 1 and 5 stars',
      });
    }

    const deal = await Deal.findById(req.params.id);
    if (!deal) {
      return res.status(404).json({
        success: false,
        message: 'Deal not found',
      });
    }

    const isFarmer = deal.farmerId.toString() === currentUserId;
    const isBuyer = deal.buyerId.toString() === currentUserId;

    if (!isFarmer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized. You are not a party to this deal.',
      });
    }

    // Deal must be DELIVERED, COMPLETED, or PAYMENT_CONFIRMED_BY_BOTH to rate
    const isEligible =
      deal.status === 'DELIVERED' ||
      deal.status === 'COMPLETED' ||
      deal.logisticsStatus === 'DELIVERED' ||
      deal.paymentStatus === 'PAYMENT_CONFIRMED_BY_BOTH';

    if (!isEligible) {
      return res.status(400).json({
        success: false,
        message: 'Ratings can only be submitted after the deal is delivered or completed.',
      });
    }

    // Duplicate Check
    const existingRating = await Rating.findOne({ fromUserId: currentUserId, dealId: deal._id });
    if (existingRating) {
      return res.status(409).json({
        success: false,
        message: 'You have already submitted a rating for this deal.',
      });
    }

    const toUserId = isFarmer ? deal.buyerId : deal.farmerId;
    const fromRole = isFarmer ? 'FARMER' : 'BUYER';
    const toRole = isFarmer ? 'BUYER' : 'FARMER';
    const writtenFeedback = (feedback || comment || '').trim();

    const newRating = await Rating.create({
      dealId: deal._id,
      opportunityId: deal.opportunityId,
      cropId: deal.cropId,
      fromUserId: currentUserId,
      fromRole,
      toUserId,
      toRole,
      rating: numRating,
      comment: writtenFeedback,
      feedback: writtenFeedback,
      categoryRatings: categoryRatings || {
        customerInteraction: numRating,
        paymentExperience: numRating,
        communication: numRating,
        transactionExperience: numRating,
      },
    });

    if (isFarmer) {
      deal.farmerRated = true;
    } else {
      deal.buyerRated = true;
    }
    await deal.save();

    // Recalculate target user rating statistics
    const updatedStats = await getUserRatingStats(toUserId, toRole);

    // Notify the rated user
    const raterRole = isFarmer ? 'Farmer' : 'Buyer';
    await Notification.create({
      userId: toUserId,
      recipientRole: toRole,
      type: 'RATING_RECEIVED',
      title: 'Rating Received',
      message: `${raterRole} gave you a ${numRating}-star rating for the ${deal.commodity} deal.`,
      crop: deal.commodity,
      dealId: deal._id,
      opportunityId: deal.opportunityId,
    });

    res.status(201).json({
      success: true,
      message: 'Rating submitted successfully',
      data: {
        rating: newRating,
        userRatingStats: updatedStats,
      },
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: 'You have already submitted a rating for this deal.',
      });
    }
    next(error);
  }
};

/**
 * Get Official Deal Agreement details and Terms & Conditions
 * @route GET /api/deals/:id/agreement
 * @access Private
 */
const getDealAgreement = async (req, res, next) => {
  try {
    const currentUserId = req.user.userId;
    const deal = await Deal.findById(req.params.id)
      .populate('farmerId', 'name phone location address city district state coordinates ratingStats')
      .populate('buyerId', 'name phone location address city district state businessName coordinates ratingStats')
      .lean();

    if (!deal) {
      return res.status(404).json({
        success: false,
        message: 'Deal not found',
      });
    }

    const farmerIdStr = deal.farmerId?._id?.toString() || deal.farmerId?.toString();
    const buyerIdStr = deal.buyerId?._id?.toString() || deal.buyerId?.toString();

    const isFarmer = farmerIdStr === currentUserId;
    const isBuyer = buyerIdStr === currentUserId;
    const isAdmin = req.user.role === 'ADMIN';

    if (!isFarmer && !isBuyer && !isAdmin) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized. You are not a party to this deal.',
      });
    }

    const farmer = deal.farmerId || {};
    const buyer = deal.buyerId || {};

    const pLat = deal.pickupLocation?.latitude || farmer.coordinates?.latitude;
    const pLng = deal.pickupLocation?.longitude || farmer.coordinates?.longitude;
    const dLat = deal.deliveryLocation?.latitude || buyer.coordinates?.latitude;
    const dLng = deal.deliveryLocation?.longitude || buyer.coordinates?.longitude;

    const pickupMapsUrl = pLat && pLng ? `https://www.google.com/maps/search/?api=1&query=${pLat},${pLng}` : null;
    const deliveryMapsUrl = dLat && dLng ? `https://www.google.com/maps/search/?api=1&query=${dLat},${dLng}` : null;

    const termsAndConditions = [
      '1. Both Farmer and Buyer agree to the crop and quantity specified in this agreement.',
      '2. Both parties agree to the mutually agreed price shown in the agreement.',
      '3. Both parties are responsible for following the agreed delivery/pickup details.',
      '4. Any changes to the deal should be mutually agreed upon.',
      '5. FarmFlow records the agreement between the parties but does not guarantee the quality, delivery, or external payment unless explicitly supported by a verified service.',
      '6. Actual payment is handled between the Farmer and Buyer unless a genuine payment provider is integrated.',
      '7. FarmFlow does not consider screenshots or user-entered payment claims as verified payment.',
      '8. Both parties should review the agreement before accepting it.'
    ];

    const isFullyConfirmed = deal.agreementStatus === 'DEAL_CONFIRMED' || (deal.farmerAccepted && deal.buyerAccepted);

    res.status(200).json({
      success: true,
      data: {
        dealId: deal._id.toString(),
        agreementVersion: deal.agreementVersion || 1,
        agreementStatus: deal.agreementStatus || 'AGREEMENT_PENDING',
        dealStatus: deal.status,
        farmerAccepted: Boolean(deal.farmerAccepted),
        buyerAccepted: Boolean(deal.buyerAccepted),
        farmerAcceptedAt: deal.farmerAcceptedAt,
        buyerAcceptedAt: deal.buyerAcceptedAt,
        grossDealValue: deal.totalAmount,
        farmer: {
          id: farmer._id ? farmer._id.toString() : farmerIdStr,
          name: farmer.name || 'Farmer',
          phone: farmer.phone || '',
          location: deal.pickupLocation?.address || farmer.address || farmer.location || '',
          hasAccepted: Boolean(deal.farmerAccepted),
          acceptedAt: deal.farmerAcceptedAt,
        },
        buyer: {
          id: buyer._id ? buyer._id.toString() : buyerIdStr,
          name: buyer.name || 'Buyer',
          businessName: buyer.businessName || '',
          phone: buyer.phone || '',
          location: deal.deliveryLocation?.address || buyer.address || buyer.location || '',
          hasAccepted: Boolean(deal.buyerAccepted),
          acceptedAt: deal.buyerAcceptedAt,
        },
        commodity: deal.commodity,
        crop: deal.crop || deal.commodity,
        variety: deal.variety || '',
        quantity: deal.quantity,
        unit: 'Quintal',
        quantityUnit: 'Quintal',
        agreedPrice: deal.agreedPrice,
        priceUnit: '₹ / Quintal',
        totalAmount: deal.totalAmount,
        agreedDate: deal.agreedDate,
        deliveryDate: deal.deliveryDate,
        pickupLocation: {
          address: deal.pickupLocation?.address || '',
          latitude: pLat,
          longitude: pLng,
          mapsUrl: pickupMapsUrl,
        },
        deliveryLocation: {
          address: deal.deliveryLocation?.address || '',
          latitude: dLat,
          longitude: dLng,
          mapsUrl: deliveryMapsUrl,
        },
        distanceKm: deal.distanceKm,
        transportRequired: deal.transportRequired !== false,
        transportType: deal.transportType || 'Standard Road Transport',
        transportCost: deal.transportCost || 0,
        otherCosts: deal.otherCosts || 0,
        estimatedNetReturn: deal.estimatedNetReturn || (deal.totalAmount - (deal.transportCost || 0) - (deal.otherCosts || 0)),
        estimatedTotalBuyerCost: deal.estimatedTotalBuyerCost || (deal.totalAmount + (deal.transportCost || 0) + (deal.otherCosts || 0)),
        termsAndConditions,
        currentUserRole: isFarmer ? 'FARMER' : 'BUYER',
        userHasAccepted: isFarmer ? Boolean(deal.farmerAccepted) : Boolean(deal.buyerAccepted),
        isFullyConfirmed,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Server-Side Acceptance of Deal Agreement with Terms Checkbox Validation
 * @route POST /api/deals/:id/agreement/accept
 * @access Private
 */
const acceptDealAgreement = async (req, res, next) => {
  try {
    const currentUserId = req.user.userId;
    const { agreeToTerms, hasReviewedAndAgreed, agreementVersion } = req.body;

    const hasCheckedAgreement = agreeToTerms === true || agreeToTerms === 'true' || hasReviewedAndAgreed === true || hasReviewedAndAgreed === 'true';

    if (!hasCheckedAgreement) {
      return res.status(400).json({
        success: false,
        message: 'You must explicitly review and agree to the Terms & Conditions before accepting.',
      });
    }

    const deal = await Deal.findById(req.params.id);
    if (!deal) {
      return res.status(404).json({
        success: false,
        message: 'Deal not found',
      });
    }

    const isFarmer = deal.farmerId.toString() === currentUserId;
    const isBuyer = deal.buyerId.toString() === currentUserId;

    if (!isFarmer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Access Denied: You are not a registered party to this Deal.',
      });
    }

    if (deal.status === 'CANCELLED') {
      return res.status(400).json({
        success: false,
        message: 'Cannot accept an agreement for a cancelled deal.',
      });
    }

    // Version mismatch check: Ensure user is accepting latest version
    if (agreementVersion && parseInt(agreementVersion, 10) !== deal.agreementVersion) {
      return res.status(409).json({
        success: false,
        message: `Agreement has been updated to Version ${deal.agreementVersion}. Please review and accept the latest terms.`,
      });
    }

    if (isFarmer) {
      if (deal.farmerAccepted) {
        return res.status(400).json({
          success: false,
          message: 'You have already accepted this agreement version.',
        });
      }
      deal.farmerAccepted = true;
      deal.farmerAcceptedAt = new Date();
    } else if (isBuyer) {
      if (deal.buyerAccepted) {
        return res.status(400).json({
          success: false,
          message: 'You have already accepted this agreement version.',
        });
      }
      deal.buyerAccepted = true;
      deal.buyerAcceptedAt = new Date();
    }

    // Determine mutual acceptance state
    const bothAccepted = deal.farmerAccepted && deal.buyerAccepted;

    if (bothAccepted) {
      deal.agreementStatus = 'DEAL_CONFIRMED';
      deal.status = 'DEAL_CONFIRMED';
    } else if (deal.farmerAccepted) {
      deal.agreementStatus = 'WAITING_FOR_BUYER';
      deal.status = 'WAITING_FOR_BUYER';
    } else if (deal.buyerAccepted) {
      deal.agreementStatus = 'WAITING_FOR_FARMER';
      deal.status = 'WAITING_FOR_FARMER';
    }

    await deal.save();

    const recipientUserId = isFarmer ? deal.buyerId : deal.farmerId;
    const recipientRole = isFarmer ? 'BUYER' : 'FARMER';
    const actorRole = isFarmer ? 'Farmer' : 'Buyer';

    if (bothAccepted) {
      // Notify BOTH users of mutual confirmation
      await Notification.create({
        userId: deal.farmerId,
        recipientRole: 'FARMER',
        type: 'DEAL_CONFIRMED',
        title: 'Deal Confirmed!',
        message: `Mutual Agreement Confirmed! Both Farmer and Buyer have accepted terms for ${deal.commodity} (${deal.quantity} Quintals). Deal is now officially confirmed.`,
        crop: deal.commodity,
        dealId: deal._id,
        opportunityId: deal.opportunityId,
      });

      await Notification.create({
        userId: deal.buyerId,
        recipientRole: 'BUYER',
        type: 'DEAL_CONFIRMED',
        title: 'Deal Confirmed!',
        message: `Mutual Agreement Confirmed! Both Farmer and Buyer have accepted terms for ${deal.commodity} (${deal.quantity} Quintals). Deal is now officially confirmed.`,
        crop: deal.commodity,
        dealId: deal._id,
        opportunityId: deal.opportunityId,
      });
    } else {
      // Notify counterparty that one party has signed
      await Notification.create({
        userId: recipientUserId,
        recipientRole,
        type: 'AGREEMENT_ACCEPTED',
        title: 'Agreement Accepted by Counterparty',
        message: `${actorRole} accepted the Deal Agreement for ${deal.commodity} (${deal.quantity} Quintals). Please review and accept to complete deal confirmation.`,
        crop: deal.commodity,
        dealId: deal._id,
        opportunityId: deal.opportunityId,
      });
    }

    res.status(200).json({
      success: true,
      message: bothAccepted
        ? 'Mutual agreement complete! Deal is officially confirmed.'
        : `Agreement accepted. Waiting for ${isFarmer ? 'Buyer' : 'Farmer'} acceptance.`,
      data: {
        dealId: deal._id.toString(),
        agreementStatus: deal.agreementStatus,
        status: deal.status,
        farmerAccepted: deal.farmerAccepted,
        farmerAcceptedAt: deal.farmerAcceptedAt,
        buyerAccepted: deal.buyerAccepted,
        buyerAcceptedAt: deal.buyerAcceptedAt,
        agreementVersion: deal.agreementVersion,
        bothAccepted,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Controlled update of deal agreement details (Increments version & resets acceptances)
 * @route PATCH /api/deals/:id/agreement
 * @access Private
 */
const updateDealAgreement = async (req, res, next) => {
  try {
    const currentUserId = req.user.userId;
    const deal = await Deal.findById(req.params.id);

    if (!deal) {
      return res.status(404).json({
        success: false,
        message: 'Deal not found',
      });
    }

    const isFarmer = deal.farmerId.toString() === currentUserId;
    const isBuyer = deal.buyerId.toString() === currentUserId;

    if (!isFarmer && !isBuyer) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized. You are not a party to this deal.',
      });
    }

    // Lock check: After both accept, deal fields are locked
    if (deal.agreementStatus === 'DEAL_CONFIRMED' || deal.status === 'DEAL_CONFIRMED' || deal.status === 'COMPLETED') {
      return res.status(400).json({
        success: false,
        message: 'Deal is already mutually confirmed and locked against unauthorized modification.',
      });
    }

    const {
      agreedPrice,
      quantity,
      deliveryDate,
      transportCost,
      otherCosts,
      transportRequired,
      transportType,
      pickupAddress,
      deliveryAddress,
    } = req.body;

    let hasChanges = false;

    if (agreedPrice !== undefined && Number(agreedPrice) !== deal.agreedPrice) {
      deal.agreedPrice = Number(agreedPrice);
      hasChanges = true;
    }

    if (quantity !== undefined && Number(quantity) !== deal.quantity) {
      deal.quantity = Number(quantity);
      hasChanges = true;
    }

    if (deliveryDate !== undefined) {
      deal.deliveryDate = new Date(deliveryDate);
      hasChanges = true;
    }

    if (transportCost !== undefined && Number(transportCost) !== deal.transportCost) {
      deal.transportCost = Number(transportCost);
      hasChanges = true;
    }

    if (otherCosts !== undefined && Number(otherCosts) !== deal.otherCosts) {
      deal.otherCosts = Number(otherCosts);
      hasChanges = true;
    }

    if (transportRequired !== undefined) {
      deal.transportRequired = Boolean(transportRequired);
      hasChanges = true;
    }

    if (transportType !== undefined) {
      deal.transportType = transportType;
      hasChanges = true;
    }

    if (pickupAddress !== undefined) {
      deal.pickupLocation.address = pickupAddress;
      hasChanges = true;
    }

    if (deliveryAddress !== undefined) {
      deal.deliveryLocation.address = deliveryAddress;
      hasChanges = true;
    }

    if (hasChanges) {
      // Invalidate old acceptance states and increment version
      deal.farmerAccepted = false;
      deal.buyerAccepted = false;
      deal.farmerAcceptedAt = null;
      deal.buyerAcceptedAt = null;
      deal.agreementVersion = (deal.agreementVersion || 1) + 1;
      deal.agreementStatus = 'AGREEMENT_PENDING';
      deal.status = 'AGREEMENT_PENDING';

      await deal.save();

      // Notify counterparty of version update
      const targetUserId = isFarmer ? deal.buyerId : deal.farmerId;
      const targetRole = isFarmer ? 'BUYER' : 'FARMER';
      const updaterName = isFarmer ? 'Farmer' : 'Buyer';

      await Notification.create({
        userId: targetUserId,
        recipientRole: targetRole,
        type: 'AGREEMENT_PENDING',
        title: 'Deal Agreement Updated',
        message: `${updaterName} updated the terms for ${deal.commodity} (Version ${deal.agreementVersion}). Prior acceptance has been reset. Please review and re-accept.`,
        crop: deal.commodity,
        dealId: deal._id,
        opportunityId: deal.opportunityId,
      });
    }

    res.status(200).json({
      success: true,
      message: 'Agreement updated. New version created and prior acceptances reset.',
      data: deal,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createDealFromOpportunity,
  getFarmerDeals,
  getBuyerDeals,
  getDealById,
  getDealAgreement,
  acceptDealAgreement,
  updateDealAgreement,
  updateDealStatus,
  updateDealLogistics,
  markDelivered,
  cancelDeal,
  reportPaymentMade,
  confirmPaymentReceived,
  disputePayment,
  rateDeal,
};
