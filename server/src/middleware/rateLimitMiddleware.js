const rateLimitStore = new Map();

/**
 * In-memory sliding window rate limiter middleware for sensitive auth & OTP operations
 * @param {Object} options Configuration options
 * @param {number} options.windowMs Time window in milliseconds (default: 15 minutes)
 * @param {number} options.max Maximum allowed requests in time window (default: 5)
 * @param {string} options.message Error message returned when limit exceeded
 */
const createRateLimiter = (options = {}) => {
  const windowMs = options.windowMs || 15 * 60 * 1000;
  const max = options.max || 5;
  const message = options.message || 'Too many requests. Please try again later.';

  return (req, res, next) => {
    const key = req.ip || req.headers['x-forwarded-for'] || 'global';
    const now = Date.now();

    if (!rateLimitStore.has(key)) {
      rateLimitStore.set(key, []);
    }

    const timestamps = rateLimitStore.get(key).filter((ts) => now - ts < windowMs);

    if (timestamps.length >= max) {
      const oldestTs = timestamps[0];
      const retryAfterSeconds = Math.ceil((windowMs - (now - oldestTs)) / 1000);
      res.setHeader('Retry-After', retryAfterSeconds);
      return res.status(429).json({
        success: false,
        message: `${message} Retry after ${retryAfterSeconds} seconds.`,
      });
    }

    timestamps.push(now);
    rateLimitStore.set(key, timestamps);
    next();
  };
};

const otpSendLimiter = createRateLimiter({
  windowMs: 10 * 60 * 1000, // 10 minutes
  max: 5,
  message: 'OTP send limit reached.',
});

const otpVerifyLimiter = createRateLimiter({
  windowMs: 10 * 60 * 1000, // 10 minutes
  max: 10,
  message: 'Too many verification attempts.',
});

module.exports = {
  createRateLimiter,
  otpSendLimiter,
  otpVerifyLimiter,
};
