const User = require('../models/User');

/**
 * Middleware requiring authenticated user to have verified mobile number AND approved role verification
 */
const requireVerified = async (req, res, next) => {
  try {
    if (!req.user || !req.user.userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required prior to verification check',
      });
    }

    const user = await User.findById(req.user.userId).select('phoneVerified verificationStatus role name');
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'User account not found',
      });
    }

    if (!user.phoneVerified) {
      return res.status(403).json({
        success: false,
        code: 'MOBILE_VERIFICATION_REQUIRED',
        message: 'Mobile number verification is required before performing restricted marketplace operations.',
      });
    }

    if (user.verificationStatus !== 'VERIFIED') {
      return res.status(403).json({
        success: false,
        code: `VERIFICATION_${user.verificationStatus}`,
        message: `Account verification status is currently ${user.verificationStatus}. ${user.role} verification must be approved to access restricted marketplace operations.`,
      });
    }

    next();
  } catch (error) {
    next(error);
  }
};

module.exports = { requireVerified };
