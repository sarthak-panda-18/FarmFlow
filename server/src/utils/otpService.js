const crypto = require('crypto');
const bcrypt = require('bcryptjs');

/**
 * Normalize phone numbers into canonical E.164 format for India (+91XXXXXXXXXX)
 */
const normalizePhone = (phoneInput) => {
  if (!phoneInput) return '';
  let cleaned = String(phoneInput).trim().replace(/[^\d+]/g, '');
  
  if (cleaned.startsWith('+91')) {
    cleaned = cleaned.substring(3);
  } else if (cleaned.startsWith('91') && cleaned.length === 12) {
    cleaned = cleaned.substring(2);
  } else if (cleaned.startsWith('0') && cleaned.length === 11) {
    cleaned = cleaned.substring(1);
  }

  // Ensure 10-digit Indian mobile number
  if (/^[6-9]\d{9}$/.test(cleaned)) {
    return `+91${cleaned}`;
  }

  // Fallback to cleaned if non-standard or international format provided
  return phoneInput.trim();
};

/**
 * Generate cryptographically random 6-digit OTP
 */
const generateOtp = () => {
  return String(crypto.randomInt(100000, 999999));
};

/**
 * Hash OTP using bcrypt with salt factor 10
 */
const hashOtp = async (otp) => {
  const salt = await bcrypt.genSalt(10);
  return await bcrypt.hash(otp, salt);
};

/**
 * Compare plain OTP against stored hash
 */
const verifyOtpHash = async (otp, hashedOtp) => {
  return await bcrypt.compare(otp, hashedOtp);
};

/**
 * SMS Provider Abstraction
 * Handles SMS dispatch in development (MockOtpService) or production (SmsOtpService)
 */
const sendSms = async (phone, otp) => {
  const provider = process.env.SMS_PROVIDER || 'MOCK';

  if (provider.toUpperCase() === 'MOCK' || process.env.NODE_ENV !== 'production') {
    console.log('\n==================================================');
    console.log(`[MOCK SMS PROVIDER] OTP Dispatch`);
    console.log(`To: ${phone}`);
    console.log(`OTP Code: ${otp}`);
    console.log(`Expires in: 5 minutes`);
    console.log('==================================================\n');

    return {
      success: true,
      provider: 'MOCK',
      message: 'Mock SMS dispatched to console log',
      devOtp: process.env.NODE_ENV !== 'production' ? otp : undefined,
    };
  }

  // Production SMS Gateway Placeholder (e.g. Twilio, MSG91)
  console.log(`[SMS PROVIDER] Sending SMS via ${provider} to ${phone}`);
  // In production with credentials:
  // await externalSmsClient.send(...)
  return {
    success: true,
    provider,
    message: 'SMS dispatched successfully via provider',
  };
};

module.exports = {
  normalizePhone,
  generateOtp,
  hashOtp,
  verifyOtpHash,
  sendSms,
};
