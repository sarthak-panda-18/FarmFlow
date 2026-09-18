const Rating = require('../models/Rating');
const Opportunity = require('../models/Opportunity');
const User = require('../models/User');
const { getUserRatingStats } = require('../utils/ratingHelper');

/**
 * @desc    Farmer submits rating for Buyer after completed transaction
 * @route   POST /api/ratings/farmer-to-buyer
 * @access  Private (FARMER only)
 */
const rateBuyer = async (req, res, next) => {
  try {
    const farmerId = req.user.userId;
    const { opportunityId, rating, categoryRatings, comment } = req.body;

    if (!opportunityId || !rating) {
      return res.status(400).json({
        success: false,
        message: 'Opportunity ID and rating are required',
      });
    }

    const numRating = parseFloat(rating);
    if (isNaN(numRating) || numRating < 1 || numRating > 5) {
      return res.status(400).json({
        success: false,
        message: 'Rating must be between 1 and 5 stars',
      });
    }

    const opportunity = await Opportunity.findById(opportunityId);
    if (!opportunity) {
      return res.status(404).json({
        success: false,
        message: 'Opportunity not found',
      });
    }

    // Ownership check
    if (opportunity.farmerId.toString() !== farmerId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You can only rate buyers for transactions on your own crops.',
      });
    }

    // Transaction state check: MUST BE COMPLETED
    if (opportunity.status !== 'COMPLETED') {
      return res.status(400).json({
        success: false,
        message: 'Feedback can only be submitted after the transaction is completed.',
      });
    }

    // Duplicate check
    const existingRating = await Rating.findOne({ fromUserId: farmerId, opportunityId });
    if (existingRating) {
      return res.status(409).json({
        success: false,
        message: 'Your feedback has already been submitted for this transaction.',
      });
    }

    const newRating = await Rating.create({
      fromUserId: farmerId,
      toUserId: opportunity.buyerId,
      fromRole: 'FARMER',
      cropId: opportunity.cropId,
      opportunityId: opportunity._id,
      rating: numRating,
      categoryRatings: categoryRatings || {
        customerInteraction: 5,
        paymentExperience: 5,
        communication: 5,
        transactionExperience: 5,
      },
      comment: (comment || '').trim(),
    });

    const buyerStats = await getUserRatingStats(opportunity.buyerId, 'BUYER');

    res.status(201).json({
      success: true,
      message: 'Buyer feedback submitted successfully',
      data: {
        rating: newRating,
        buyerRatingStats: buyerStats,
      },
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: 'Your feedback has already been submitted for this transaction.',
      });
    }
    next(error);
  }
};

/**
 * @desc    Buyer submits rating for Farmer after completed transaction
 * @route   POST /api/ratings/buyer-to-farmer
 * @access  Private (BUYER only)
 */
const rateFarmer = async (req, res, next) => {
  try {
    const buyerId = req.user.userId;
    const { opportunityId, rating, categoryRatings, comment } = req.body;

    if (!opportunityId || !rating) {
      return res.status(400).json({
        success: false,
        message: 'Opportunity ID and rating are required',
      });
    }

    const numRating = parseFloat(rating);
    if (isNaN(numRating) || numRating < 1 || numRating > 5) {
      return res.status(400).json({
        success: false,
        message: 'Rating must be between 1 and 5 stars',
      });
    }

    const opportunity = await Opportunity.findById(opportunityId);
    if (!opportunity) {
      return res.status(404).json({
        success: false,
        message: 'Opportunity not found',
      });
    }

    if (opportunity.buyerId.toString() !== buyerId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You can only rate farmers for your own transactions.',
      });
    }

    if (opportunity.status !== 'COMPLETED') {
      return res.status(400).json({
        success: false,
        message: 'Feedback can only be submitted after the transaction is completed.',
      });
    }

    const existingRating = await Rating.findOne({ fromUserId: buyerId, opportunityId });
    if (existingRating) {
      return res.status(409).json({
        success: false,
        message: 'Your feedback has already been submitted for this transaction.',
      });
    }

    const newRating = await Rating.create({
      fromUserId: buyerId,
      toUserId: opportunity.farmerId,
      fromRole: 'BUYER',
      cropId: opportunity.cropId,
      opportunityId: opportunity._id,
      rating: numRating,
      categoryRatings: categoryRatings || {
        productQuality: 5,
        freshness: 5,
        spoilage: 5,
        quantityAccuracy: 5,
        farmerInteraction: 5,
        transactionExperience: 5,
      },
      comment: (comment || '').trim(),
    });

    const farmerStats = await getUserRatingStats(opportunity.farmerId, 'FARMER');

    res.status(201).json({
      success: true,
      message: 'Farmer feedback submitted successfully',
      data: {
        rating: newRating,
        farmerRatingStats: farmerStats,
      },
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: 'Your feedback has already been submitted for this transaction.',
      });
    }
    next(error);
  }
};

/**
 * @desc    Get user rating statistics
 * @route   GET /api/ratings/user/:id
 * @access  Public
 */
const getUserRating = async (req, res, next) => {
  try {
    const user = await User.findById(req.params.id).select('role name').lean();
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found',
      });
    }

    const stats = await getUserRatingStats(req.params.id, user.role);

    res.status(200).json({
      success: true,
      data: stats,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  rateBuyer,
  rateFarmer,
  getUserRating,
};
