const express = require('express');
const router = express.Router();
const {
  register,
  login,
  sendOtp,
  verifyOtp,
  resendOtp,
  getMe,
} = require('../controllers/authController');
const { requireAuth } = require('../middleware/authMiddleware');
const { otpSendLimiter, otpVerifyLimiter } = require('../middleware/rateLimitMiddleware');

// Soft auth middleware to attach user if Bearer token is provided without failing public calls
const optionalAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return requireAuth(req, res, next);
  }
  next();
};

// Public Auth Endpoints
router.post('/register', register);
router.post('/login', login);

// OTP Endpoints
router.post('/send-otp', otpSendLimiter, optionalAuth, sendOtp);
router.post('/verify-otp', otpVerifyLimiter, optionalAuth, verifyOtp);
router.post('/resend-otp', otpSendLimiter, optionalAuth, resendOtp);

// Private Auth Endpoint
router.get('/me', requireAuth, getMe);

module.exports = router;
