const User = require('../models/User');

/**
 * @desc    Submit Farmer Verification Information
 * @route   POST /api/verification/farmer
 * @access  Private (FARMER only)
 */
const submitFarmerVerification = async (req, res, next) => {
  try {
    const { farmerId, supportingDocument, documentUrl } = req.body;

    if (!farmerId || String(farmerId).trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Farmer ID / Agricultural Registration ID is required.',
      });
    }

    const doc = supportingDocument || documentUrl || '';

    const user = await User.findById(req.user.userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User account not found.',
      });
    }

    if (user.role !== 'FARMER') {
      return res.status(403).json({
        success: false,
        message: 'Forbidden: Only users with FARMER role can submit Farmer verification.',
      });
    }

    user.verificationId = String(farmerId).trim();
    user.verificationDocument = String(doc).trim();
    user.verificationStatus = 'PENDING';
    user.verificationType = 'FARMER';
    user.verificationSubmittedAt = new Date();

    await user.save();

    console.log(`[VERIFICATION] Farmer verification submitted for ${user.phone}: ${user.verificationId}`);

    res.status(200).json({
      success: true,
      message: 'Farmer verification information submitted successfully. Status set to PENDING.',
      data: {
        userId: user._id.toString(),
        phoneVerified: user.phoneVerified,
        verificationStatus: user.verificationStatus,
        verificationType: user.verificationType,
        verificationId: user.verificationId,
        verificationSubmittedAt: user.verificationSubmittedAt,
      },
    });
  } catch (error) {
    console.error('[VERIFICATION ERROR] submitFarmerVerification exception:', error.message);
    next(error);
  }
};

/**
 * @desc    Submit Buyer Verification Information
 * @route   POST /api/verification/buyer
 * @access  Private (BUYER only)
 */
const submitBuyerVerification = async (req, res, next) => {
  try {
    const { businessName, businessType, registrationIdentifier, gstId, supportingDocument } = req.body;
    const regId = registrationIdentifier || gstId;

    if (!businessName || !businessType || !regId) {
      return res.status(400).json({
        success: false,
        message: 'Business Name, Business Type, and Registration / GST Identifier are required.',
      });
    }

    const user = await User.findById(req.user.userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User account not found.',
      });
    }

    if (user.role !== 'BUYER') {
      return res.status(403).json({
        success: false,
        message: 'Forbidden: Only users with BUYER role can submit Buyer verification.',
      });
    }

    user.businessName = String(businessName).trim();
    user.businessType = String(businessType).trim();
    user.verificationId = String(regId).trim();
    user.verificationDocument = supportingDocument ? String(supportingDocument).trim() : '';
    user.verificationStatus = 'PENDING';
    user.verificationType = 'BUYER';
    user.verificationSubmittedAt = new Date();

    await user.save();

    console.log(`[VERIFICATION] Buyer verification submitted for ${user.phone}: ${user.businessName} (${user.verificationId})`);

    res.status(200).json({
      success: true,
      message: 'Buyer verification information submitted successfully. Status set to PENDING.',
      data: {
        userId: user._id.toString(),
        phoneVerified: user.phoneVerified,
        verificationStatus: user.verificationStatus,
        verificationType: user.verificationType,
        businessName: user.businessName,
        businessType: user.businessType,
        verificationId: user.verificationId,
        verificationSubmittedAt: user.verificationSubmittedAt,
      },
    });
  } catch (error) {
    console.error('[VERIFICATION ERROR] submitBuyerVerification exception:', error.message);
    next(error);
  }
};

/**
 * @desc    Get Current Verification Status
 * @route   GET /api/verification/status
 * @access  Private
 */
const getVerificationStatus = async (req, res, next) => {
  try {
    const user = await User.findById(req.user.userId).select(
      'phone phoneVerified verificationStatus verificationType verificationId businessName businessType verificationDocument verificationSubmittedAt verificationReviewedAt'
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User account not found.',
      });
    }

    res.status(200).json({
      success: true,
      data: {
        phone: user.phone,
        phoneVerified: user.phoneVerified,
        verificationStatus: user.verificationStatus,
        verificationType: user.verificationType,
        verificationId: user.verificationId,
        businessName: user.businessName,
        businessType: user.businessType,
        verificationDocument: user.verificationDocument,
        verificationSubmittedAt: user.verificationSubmittedAt,
        verificationReviewedAt: user.verificationReviewedAt,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Admin helper to update verification status (For development / prototype administration)
 * @route   PATCH /api/verification/admin/user/:userId/status
 * @access  Private
 */
const adminUpdateStatus = async (req, res, next) => {
  try {
    const { userId } = req.params;
    const { status } = req.body;

    if (!['PENDING', 'VERIFIED', 'REJECTED'].includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid status. Must be one of: PENDING, VERIFIED, REJECTED',
      });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User account not found.',
      });
    }

    user.verificationStatus = status;
    user.verificationReviewedAt = new Date();
    await user.save();

    console.log(`[ADMIN VERIFICATION] Updated ${user.phone} (${user.role}) status to ${status}`);

    res.status(200).json({
      success: true,
      message: `User verification status updated to ${status}`,
      data: {
        userId: user._id.toString(),
        role: user.role,
        phoneVerified: user.phoneVerified,
        verificationStatus: user.verificationStatus,
        verificationReviewedAt: user.verificationReviewedAt,
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  submitFarmerVerification,
  submitBuyerVerification,
  getVerificationStatus,
  adminUpdateStatus,
};
