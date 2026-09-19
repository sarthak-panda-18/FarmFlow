/**
 * FarmFlow ML Price Prediction Service Client
 * Handles communication between Node.js backend and Python FastAPI ML microservice.
 */

const ML_SERVICE_URL = process.env.ML_SERVICE_URL || 'http://localhost:8000';
const ML_TIMEOUT_MS = parseInt(process.env.ML_TIMEOUT_MS, 10) || 5000;

// In-memory prediction cache with 5-minute TTL
const predictionCache = new Map();
const CACHE_TTL_MS = 5 * 60 * 1000;

/**
 * Generates cache key for prediction requests
 */
function getCacheKey(commodity, state, district, market, variety, grade, date) {
  return `${commodity || ''}:${state || ''}:${district || ''}:${market || ''}:${variety || ''}:${grade || ''}:${date || ''}`.toLowerCase();
}

/**
 * Checks health of the Python FastAPI ML microservice
 * @returns {Promise<{ available: boolean, data?: object, error?: string }>}
 */
async function checkMLHealth() {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 2000);

  try {
    const response = await fetch(`${ML_SERVICE_URL}/health`, {
      method: 'GET',
      signal: controller.signal,
    });
    clearTimeout(timeoutId);

    if (response.ok) {
      const data = await response.json();
      return { available: true, data };
    }
    return { available: false, error: `HTTP ${response.status}` };
  } catch (err) {
    clearTimeout(timeoutId);
    return { available: false, error: err.message };
  }
}

/**
 * Requests agricultural price prediction from Python FastAPI ML microservice
 * @param {object} params
 * @param {string} params.commodity
 * @param {string} [params.state]
 * @param {string} [params.district]
 * @param {string} [params.market]
 * @param {string} [params.variety]
 * @param {string} [params.grade]
 * @param {string} [params.date]
 * @returns {Promise<{ available: boolean, success: boolean, prediction?: object, message?: string }>}
 */
async function getPricePrediction({
  commodity,
  state = 'Andhra Pradesh',
  district = 'Krishna',
  market,
  variety = 'Other',
  grade = 'FAQ',
  date,
}) {
  if (!commodity || !commodity.trim()) {
    return {
      available: true,
      success: false,
      message: 'Commodity name is required for price prediction.',
    };
  }

  const cacheKey = getCacheKey(commodity, state, district, market, variety, grade, date);
  const cached = predictionCache.get(cacheKey);

  if (cached && Date.now() - cached.timestamp < CACHE_TTL_MS) {
    return {
      available: true,
      success: true,
      cached: true,
      prediction: cached.data,
    };
  }

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), ML_TIMEOUT_MS);

  try {
    const payload = {
      commodity: commodity.trim(),
      state: state ? state.trim() : 'Andhra Pradesh',
      district: district ? district.trim() : 'Krishna',
      market: market ? market.trim() : undefined,
      variety: variety ? variety.trim() : 'Other',
      grade: grade ? grade.trim() : 'FAQ',
      date: date ? date.trim() : undefined,
    };

    const response = await fetch(`${ML_SERVICE_URL}/predict`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    if (response.ok) {
      const data = await response.json();
      if (data.success && data.prediction) {
        // Cache valid result
        predictionCache.set(cacheKey, {
          timestamp: Date.now(),
          data: data.prediction,
        });

        return {
          available: true,
          success: true,
          prediction: data.prediction,
        };
      }
    }

    const errorBody = await response.json().catch(() => ({}));
    return {
      available: true,
      success: false,
      message: errorBody.detail || 'ML service returned an error.',
    };
  } catch (err) {
    clearTimeout(timeoutId);

    const isTimeout = err.name === 'AbortError';
    console.warn(`[ML SERVICE WARNING] Prediction request failed (${isTimeout ? 'Timeout' : err.message})`);

    return {
      available: false,
      success: false,
      message: isTimeout
        ? 'Market prediction request timed out.'
        : 'Market prediction service is currently unavailable.',
    };
  }
}

module.exports = {
  ML_SERVICE_URL,
  checkMLHealth,
  getPricePrediction,
};
