const User = require('../models/User');
const Otp = require('../models/Otp');
const { hashPassword, comparePassword } = require('../utils/password');
const { generateToken } = require('../utils/jwt');
const { getDBStatus } = require('../config/database');
const {
  normalizePhone,
  generateOtp,
  hashOtp,
  verifyOtpHash,
  sendSms,
} = require('../utils/otpService');

/**
 * Format standard user object payload for auth responses
 */
const formatUserResponse = (user) => {
  return {
    id: user._id.toString(),
    name: user.name,
    email: user.email || '',
    phone: user.phone,
    role: user.role,
    phoneVerified: user.phoneVerified ?? false,
    verificationStatus: user.verificationStatus || 'PENDING',
    verificationType: user.verificationType || 'NONE',
    verificationId: user.verificationId || '',
    gstin: user.gstin || user.verificationId || '',
    businessName: user.businessName || '',
    businessType: user.businessType || '',
    verificationDocument: user.verificationDocument || '',
  };
};

/**
 * @desc    Register a new user (FARMER or BUYER)
 * @route   POST /api/auth/register
 * @access  Public
 */
const register = async (req, res, next) => {
  console.log('[AUTH] REGISTER REQUEST RECEIVED');

  if (getDBStatus() !== 'connected') {
    return res.status(500).json({
      success: false,
      message: 'Database server is currently unavailable. Please try again shortly.',
    });
  }

  try {
    const { name, email, phone, password, role, farmerId, gstin, GSTIN } = req.body;

    if (!name || !phone || !password || !role) {
      return res.status(400).json({
        success: false,
        message: 'Please provide all required fields: name, phone, password, role',
      });
    }

    const normalizedRole = role.toUpperCase();
    if (!['FARMER', 'BUYER'].includes(normalizedRole)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid role. Role must be either FARMER or BUYER',
      });
    }

    let cleanFarmerId = null;
    let cleanGstin = null;

    if (normalizedRole === 'FARMER') {
      cleanFarmerId = farmerId ? String(farmerId).trim() : '';
      if (!cleanFarmerId) {
        return res.status(400).json({
          success: false,
          message: 'Farmer ID is required.',
        });
      }
    } else if (normalizedRole === 'BUYER') {
      const rawGstin = gstin || GSTIN;
      cleanGstin = rawGstin ? String(rawGstin).trim().toUpperCase() : '';
      if (!cleanGstin) {
        return res.status(400).json({
          success: false,
          message: 'GSTIN is required for Buyer registration.',
        });
      }
      // Basic format validation: 15 alphanumeric characters
      const gstinRegex = /^[0-9A-Z]{15}$/;
      if (!gstinRegex.test(cleanGstin)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid GSTIN format. GSTIN must be 15 alphanumeric characters.',
        });
      }
    }

    const normalizedPhoneNum = normalizePhone(phone);
    if (!normalizedPhoneNum) {
      return res.status(400).json({
        success: false,
        message: 'Invalid mobile phone number format',
      });
    }

    // Check phone uniqueness
    const existingPhoneUser = await User.findOne({ phone: normalizedPhoneNum });
    if (existingPhoneUser) {
      return res.status(409).json({
        success: false,
        message: 'Phone number is already registered.',
      });
    }

    // Optional email check if provided
    let normalizedEmail = null;
    if (email && String(email).trim().length > 0) {
      normalizedEmail = String(email).toLowerCase().trim();
      const existingEmailUser = await User.findOne({ email: normalizedEmail });
      if (existingEmailUser) {
        return res.status(409).json({
          success: false,
          message: 'Email address is already registered.',
        });
      }
    }

    const passwordHash = await hashPassword(password);

    const user = await User.create({
      name: name.trim(),
      email: normalizedEmail || undefined,
      phone: normalizedPhoneNum,
      passwordHash,
      role: normalizedRole,
      phoneVerified: false,
      verificationStatus: 'PENDING',
      verificationType: normalizedRole,
      verificationId: cleanFarmerId || cleanGstin || undefined,
      gstin: cleanGstin || undefined,
    });

    const token = generateToken({
      userId: user._id.toString(),
      role: user.role,
    });

    console.log(`[AUTH SUCCESS] User registered successfully: ${user.phone} (${user.role})`);

    res.status(201).json({
      success: true,
      message: 'Registration successful. Mobile verification required.',
      data: {
        token,
        user: formatUserResponse(user),
      },
    });
  } catch (error) {
    console.error('[AUTH ERROR] Registration exception:', error.message);
    next(error);
  }
};

/**
 * @desc    Authenticate user & get token (Login by Email or Phone)
 * @route   POST /api/auth/login
 * @access  Public
 */
const login = async (req, res, next) => {
  console.log('[AUTH] LOGIN REQUEST RECEIVED');

  if (getDBStatus() !== 'connected') {
    return res.status(500).json({
      success: false,
      message: 'Database server is currently unavailable. Please try again shortly.',
    });
  }

  try {
    const { email, phone, password } = req.body;
    const identifier = email || phone;

    if (!identifier || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please provide mobile number or email, and password',
      });
    }

    let user = null;
    const trimmedId = String(identifier).trim();

    if (trimmedId.includes('@')) {
      user = await User.findOne({ email: trimmedId.toLowerCase() });
    } else {
      const normalizedPhoneNum = normalizePhone(trimmedId);
      user = await User.findOne({ phone: normalizedPhoneNum });
    }

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials. Mobile number/email or password incorrect.',
      });
    }

    const isMatch = await comparePassword(password, user.passwordHash);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials. Mobile number/email or password incorrect.',
      });
    }

    const token = generateToken({
      userId: user._id.toString(),
      role: user.role,
    });

    res.status(200).json({
      success: true,
      message: 'Login successful',
      data: {
        token,
        user: formatUserResponse(user),
      },
    });
  } catch (error) {
    console.error('[AUTH ERROR] Login exception:', error.message);
    next(error);
  }
};

/**
 * @desc    Send 6-digit OTP to user mobile number
 * @route   POST /api/auth/send-otp
 * @access  Public / Private
 */
const sendOtp = async (req, res, next) => {
  try {
    let phoneInput = req.body.phone;
    
    // If authenticated user didn't specify phone, use their registered phone
    if (!phoneInput && req.user && req.user.userId) {
      const user = await User.findById(req.user.userId);
      if (user) phoneInput = user.phone;
    }

    if (!phoneInput) {
      return res.status(400).json({
        success: false,
        message: 'Mobile number is required to send OTP',
      });
    }

    const normalizedPhoneNum = normalizePhone(phoneInput);

    // Check for active resend cooldown
    const now = new Date();
    const existingOtp = await Otp.findOne({
      phone: normalizedPhoneNum,
      isVerified: false,
      expiresAt: { $gt: now },
    }).sort({ createdAt: -1 });

    if (existingOtp && existingOtp.resendCooldownUntil && existingOtp.resendCooldownUntil > now) {
      const remainingSeconds = Math.ceil((existingOtp.resendCooldownUntil - now) / 1000);
      return res.status(429).json({
        success: false,
        message: `Please wait ${remainingSeconds} seconds before requesting a new OTP.`,
      });
    }

    const otpCode = generateOtp();
    const hashedCode = await hashOtp(otpCode);
    const expiresAt = new Date(now.getTime() + 5 * 60 * 1000); // 5 minute validity
    const resendCooldownUntil = new Date(now.getTime() + 60 * 1000); // 60s cooldown

    await Otp.create({
      phone: normalizedPhoneNum,
      otpHash: hashedCode,
      expiresAt,
      resendCooldownUntil,
      attempts: 0,
      maxAttempts: 3,
      isVerified: false,
    });

    const smsResult = await sendSms(normalizedPhoneNum, otpCode);

    res.status(200).json({
      success: true,
      message: `OTP sent successfully to ${normalizedPhoneNum}`,
      data: {
        phone: normalizedPhoneNum,
        expiresInSeconds: 300,
        cooldownSeconds: 60,
        devOtp: smsResult.devOtp,
      },
    });
  } catch (error) {
    console.error('[AUTH ERROR] sendOtp exception:', error.message);
    next(error);
  }
};

/**
 * @desc    Verify 6-digit Mobile OTP
 * @route   POST /api/auth/verify-otp
 * @access  Public / Private
 */
const verifyOtp = async (req, res, next) => {
  try {
    let { phone, otp } = req.body;

    if (!otp) {
      return res.status(400).json({
        success: false,
        message: 'Please provide the 6-digit OTP',
      });
    }

    if (!phone && req.user && req.user.userId) {
      const user = await User.findById(req.user.userId);
      if (user) phone = user.phone;
    }

    if (!phone) {
      return res.status(400).json({
        success: false,
        message: 'Mobile number is required to verify OTP',
      });
    }

    const normalizedPhoneNum = normalizePhone(phone);
    const now = new Date();

    const otpRecord = await Otp.findOne({
      phone: normalizedPhoneNum,
      isVerified: false,
      expiresAt: { $gt: now },
    }).sort({ createdAt: -1 });

    if (!otpRecord) {
      return res.status(400).json({
        success: false,
        message: 'OTP has expired or is invalid. Please request a new OTP.',
      });
    }

    if (otpRecord.attempts >= otpRecord.maxAttempts) {
      return res.status(400).json({
        success: false,
        message: 'Maximum OTP verification attempts exceeded. Please request a new OTP.',
      });
    }

    const isValid = await verifyOtpHash(String(otp).trim(), otpRecord.otpHash);

    if (!isValid) {
      otpRecord.attempts += 1;
      await otpRecord.save();
      const remainingAttempts = otpRecord.maxAttempts - otpRecord.attempts;
      return res.status(400).json({
        success: false,
        message: `Invalid OTP code. ${remainingAttempts} ${remainingAttempts === 1 ? 'attempt' : 'attempts'} remaining.`,
      });
    }

    // Mark OTP record as verified
    otpRecord.isVerified = true;
    await otpRecord.save();

    // Update User phoneVerified state and verificationStatus for Farmers
    let userToUpdate = await User.findOne({ phone: normalizedPhoneNum });
    if (!userToUpdate && req.user && req.user.userId) {
      userToUpdate = await User.findById(req.user.userId);
    }

    if (userToUpdate) {
      userToUpdate.phoneVerified = true;
      userToUpdate.verificationStatus = 'VERIFIED';
      await userToUpdate.save();
    }
    const updatedUser = userToUpdate;

    res.status(200).json({
      success: true,
      message: 'Mobile number verified successfully!',
      data: {
        phoneVerified: true,
        user: updatedUser ? formatUserResponse(updatedUser) : null,
      },
    });
  } catch (error) {
    console.error('[AUTH ERROR] verifyOtp exception:', error.message);
    next(error);
  }
};

/**
 * @desc    Resend 6-digit OTP
 * @route   POST /api/auth/resend-otp
 * @access  Public / Private
 */
const resendOtp = async (req, res, next) => {
  return sendOtp(req, res, next);
};

/**
 * @desc    Get authenticated user profile
 * @route   GET /api/auth/me
 * @access  Private
 */
const getMe = async (req, res, next) => {
  try {
    const user = await User.findById(req.user.userId).select('-passwordHash');
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User profile not found',
      });
    }

    res.status(200).json({
      success: true,
      data: {
        user: formatUserResponse(user),
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  register,
  login,
  sendOtp,
  verifyOtp,
  resendOtp,
  getMe,
};
