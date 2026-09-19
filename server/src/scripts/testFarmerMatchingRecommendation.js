const mongoose = require('mongoose');
const User = require('../models/User');
const Crop = require('../models/Crop');
const BuyerRequirement = require('../models/BuyerRequirement');

const BASE_URL = 'http://127.0.0.1:5000/api';

async function request(endpoint, { method = 'GET', body = null, token = null } = {}) {
  const headers = {};
  if (body) headers['Content-Type'] = 'application/json';
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const res = await fetch(`${BASE_URL}${endpoint}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : null,
  });

  const status = res.status;
  let data = null;
  try {
    data = await res.json();
  } catch (_) {
    data = null;
  }
  return { status, data, ok: res.ok };
}

async function runMatchingRecommendationTests() {
  console.log('\n=============================================================');
  console.log('🧪 RUNNING FARMER MATCHING BUYER RECOMMENDATION TESTS');
  console.log('=============================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition, message) {
    if (condition) {
      console.log(`  ✅ [PASS] ${message}`);
      passed++;
    } else {
      console.error(`  ❌ [FAIL] ${message}`);
      failed++;
    }
  }

  try {
    const mongoUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/farm-to-market';
    await mongoose.connect(mongoUri);

    const suffix = Math.floor(10000000 + Math.random() * 90000000);
    const password = 'Password@123';

    // 1. Create Farmer
    const farmerMobile = '98' + suffix.toString().slice(0, 8);
    const regFarmer = await request('/auth/register', {
      method: 'POST',
      body: {
        name: 'Babanrao Shinde',
        phone: farmerMobile,
        password,
        role: 'FARMER',
        farmerId: 'FARM' + suffix.toString().slice(0, 6),
        district: 'Guntur',
        state: 'Andhra Pradesh',
        address: 'Tenali Rural Road',
      },
    });
    assert(regFarmer.status === 201, 'Farmer registered');
    const farmerToken = regFarmer.data.data.token;
    const farmerId = regFarmer.data.data.user.id || regFarmer.data.data.user._id;

    await User.findByIdAndUpdate(farmerId, {
      phoneVerified: true,
      verificationStatus: 'VERIFIED',
      location: { type: 'Point', coordinates: [80.6475, 16.2433] }, // Tenali, Guntur
    });

    const testCommodity = 'Red Chilli ' + suffix;

    // 2. Create Farmer Crop (Chilli, 50 Quintals, Expected Price ₹15,000/Q)
    const harvestDate = new Date(Date.now() + 10 * 24 * 60 * 60 * 1000).toISOString();
    const createCropRes = await request('/crops', {
      method: 'POST',
      token: farmerToken,
      body: {
        commodity: testCommodity,
        cropName: 'Teja Red Chilli',
        variety: 'Teja',
        grade: 'Grade A',
        quantity: 50,
        quantityUnit: 'quintal',
        expectedPrice: 15000,
        harvestDate,
        state: 'Andhra Pradesh',
        district: 'Guntur',
        market: 'Guntur APMC Mandi',
        location: 'Tenali Rural Road, Guntur',
      },
    });
    assert(createCropRes.status === 201, 'Farmer Crop created');
    const cropId = createCropRes.data?.data?.crop?.id || createCropRes.data?.data?.crop?._id || createCropRes.data?.data?.id;

    // -------------------------------------------------------------
    // CASE 7: No Matched Buyers (initially 0 requirements for unique commodity)
    // -------------------------------------------------------------
    console.log('\n--- Case 7: Zero matched buyers ---');
    const initialMatchesRes = await request(`/matches/farmer?cropId=${cropId}`, {
      token: farmerToken,
    });
    assert(initialMatchesRes.status === 200, 'Matches API returns 200 for empty state');
    assert(initialMatchesRes.data.count === 0, 'Count is 0 when no buyers match');
    assert(Array.isArray(initialMatchesRes.data.data) && initialMatchesRes.data.data.length === 0, 'Data array is empty');

    // -------------------------------------------------------------
    // Register 3 Buyers with different economic parameters
    // -------------------------------------------------------------
    console.log('\n--- Registering Matched Buyers ---');
    const requiredDate = new Date(Date.now() + 20 * 24 * 60 * 60 * 1000).toISOString();

    // Buyer A (High Gross Price ₹18,000/Q, High Distance/Transport ₹20,000, Other ₹5,000)
    // Gross = 50 * 18,000 = ₹9,00,000. Transport = ₹20,000, Other = ₹5,000 -> Net Value = ₹8,75,000 (Net/Q = ₹17,500)
    const buyerAMobile = '97' + suffix.toString().slice(0, 8);
    const regBuyerA = await request('/auth/register', {
      method: 'POST',
      body: {
        name: 'Apex Spices Exporters',
        phone: buyerAMobile,
        password,
        role: 'BUYER',
        gstin: '37ABCDE1234F1Z1',
        district: 'Visakhapatnam',
        state: 'Andhra Pradesh',
        address: 'Vizag Port Road',
      },
    });
    const buyerAToken = regBuyerA.data.data.token;
    const buyerAId = regBuyerA.data.data.user.id || regBuyerA.data.data.user._id;
    await User.findByIdAndUpdate(buyerAId, {
      phoneVerified: true,
      verificationStatus: 'VERIFIED',
      location: { type: 'Point', coordinates: [83.2185, 17.6868] }, // Vizag (far)
    });

    const reqARes = await request('/requirements', {
      method: 'POST',
      token: buyerAToken,
      body: {
        commodity: testCommodity,
        variety: 'Teja',
        quantity: 50,
        quantityUnit: 'quintal',
        offeredPrice: 18000,
        requiredByDate: requiredDate,
        state: 'Andhra Pradesh',
        district: 'Visakhapatnam',
        transportCost: 20000,
        otherCosts: 5000,
      },
    });
    assert(reqARes.status === 201, 'Buyer A requirement created');

    // -------------------------------------------------------------
    // CASE 1: Single Matched Buyer
    // -------------------------------------------------------------
    console.log('\n--- Case 1: Single matched buyer ---');
    const singleMatchRes = await request(`/matches/farmer?cropId=${cropId}`, {
      token: farmerToken,
    });
    assert(singleMatchRes.status === 200, 'Matches API returns 200');
    assert(singleMatchRes.data.count === 1, 'Returns 1 matched buyer');
    const singleMatch = singleMatchRes.data.data[0];
    assert(singleMatch.rank === 1, 'Top buyer has rank 1');
    assert(singleMatch.isRecommended === true, 'Top buyer is marked isRecommended = true');
    assert(singleMatch.netValue === 875000, `Net value correctly calculated as ₹8,75,000 (actual: ₹${singleMatch.netValue})`);
    assert(singleMatch.netValuePerQ === 17500, `Net value per quintal is ₹17,500 (actual: ₹${singleMatch.netValuePerQ})`);
    assert(singleMatch.recommendationReasons.length > 0, 'Recommendation reasons generated');

    // Buyer B (Medium Gross Price ₹18,500/Q, Nearby Guntur Mandi, Low Transport ₹1,000, Other ₹500)
    // Gross = 50 * 18,500 = ₹9,25,000. Transport = ₹1,000, Other = ₹500 -> Net Value = ₹9,23,500 (Net/Q = ₹18,470)
    // Buyer B SHOULD WIN OVER Buyer A!
    const buyerBMobile = '96' + suffix.toString().slice(0, 8);
    const regBuyerB = await request('/auth/register', {
      method: 'POST',
      body: {
        name: 'Guntur Spice Traders Pvt Ltd',
        phone: buyerBMobile,
        password,
        role: 'BUYER',
        gstin: '37BCDEF2345G1Z2',
        district: 'Guntur',
        state: 'Andhra Pradesh',
        address: 'Guntur Mandi Complex',
      },
    });
    const buyerBToken = regBuyerB.data.data.token;
    const buyerBId = regBuyerB.data.data.user.id || regBuyerB.data.data.user._id;
    await User.findByIdAndUpdate(buyerBId, {
      phoneVerified: true,
      verificationStatus: 'VERIFIED',
      location: { type: 'Point', coordinates: [80.4365, 16.3067] }, // Guntur APMC (close)
    });

    const reqBRes = await request('/requirements', {
      method: 'POST',
      token: buyerBToken,
      body: {
        commodity: testCommodity,
        variety: 'Teja',
        quantity: 50,
        quantityUnit: 'quintal',
        offeredPrice: 18500,
        requiredByDate: requiredDate,
        state: 'Andhra Pradesh',
        district: 'Guntur',
        transportCost: 1000,
        otherCosts: 500,
      },
    });
    assert(reqBRes.status === 201, 'Buyer B requirement created');

    // -------------------------------------------------------------
    // CASE 2: Two Matched Buyers with Different Prices & Net Values
    // -------------------------------------------------------------
    console.log('\n--- Case 2: Two matched buyers ---');
    const twoMatchesRes = await request(`/matches/farmer?cropId=${cropId}`, {
      token: farmerToken,
    });
    assert(twoMatchesRes.status === 200, 'Matches API returns 200');
    assert(twoMatchesRes.data.count === 2, 'Returns 2 matched buyers');
    assert(twoMatchesRes.data.data[0].buyerName === 'Guntur Spice Traders Pvt Ltd', 'Buyer B (Guntur Spice Traders) is ranked #1');
    assert(twoMatchesRes.data.data[0].isRecommended === true, 'Rank #1 isRecommended = true');
    assert(twoMatchesRes.data.data[1].isRecommended === false, 'Rank #2 isRecommended = false');

    // Buyer C (Highest Gross Price ₹19,500/Q, Extreme distance / High Transport ₹60,000, Other ₹10,000)
    // Gross = 50 * 19,500 = ₹9,75,000. Transport = ₹60,000, Other = ₹10,000 -> Net Value = ₹9,05,000
    // Notice: Buyer C has the HIGHEST Gross Price (₹19,500 vs ₹18,500), BUT lower Net Value (₹9,05,000 vs ₹9,23,500)!
    // Buyer B MUST REMAIN RANK #1 due to superior Net Value!
    const buyerCMobile = '95' + suffix.toString().slice(0, 8);
    const regBuyerC = await request('/auth/register', {
      method: 'POST',
      body: {
        name: 'Global Export Hub',
        phone: buyerCMobile,
        password,
        role: 'BUYER',
        gstin: '37CDEFG3456H1Z3',
        district: 'Kurnool',
        state: 'Andhra Pradesh',
        address: 'Kurnool Highway Logistics Park',
      },
    });
    const buyerCToken = regBuyerC.data.data.token;
    const buyerCId = regBuyerC.data.data.user.id || regBuyerC.data.data.user._id;
    await User.findByIdAndUpdate(buyerCId, {
      phoneVerified: true,
      verificationStatus: 'VERIFIED',
      location: { type: 'Point', coordinates: [78.0373, 15.8281] },
    });

    const reqCRes = await request('/requirements', {
      method: 'POST',
      token: buyerCToken,
      body: {
        commodity: testCommodity,
        variety: 'Teja',
        quantity: 50,
        quantityUnit: 'quintal',
        offeredPrice: 19500,
        requiredByDate: requiredDate,
        state: 'Andhra Pradesh',
        district: 'Kurnool',
        transportCost: 60000,
        otherCosts: 10000,
      },
    });
    assert(reqCRes.status === 201, 'Buyer C requirement created');

    // -------------------------------------------------------------
    // CASE 3 & 4: Three Buyers - Highest Gross Price does NOT beat Best Net Value
    // -------------------------------------------------------------
    console.log('\n--- Case 3 & 4: Economic Net Value Ranking ---');
    const threeMatchesRes = await request(`/matches/farmer?cropId=${cropId}`, {
      token: farmerToken,
    });
    assert(threeMatchesRes.status === 200, 'Matches API returns 200');
    assert(threeMatchesRes.data.count === 3, 'Returns 3 matched buyers');

    const rank1 = threeMatchesRes.data.data[0];
    const rank2 = threeMatchesRes.data.data[1];
    const rank3 = threeMatchesRes.data.data[2];

    assert(rank1.buyerName === 'Guntur Spice Traders Pvt Ltd', `Rank #1 is Buyer B (Highest Net Value ₹9,23,500, actual: ${rank1.buyerName})`);
    assert(rank1.netValue === 923500, `Rank #1 Net Value is ₹9,23,500 (actual: ₹${rank1.netValue})`);
    assert(rank1.isRecommended === true, 'Rank #1 has isRecommended = true');

    assert(rank2.buyerName === 'Global Export Hub', `Rank #2 is Buyer C (Gross ₹19,500, Net Value ₹9,05,000, actual: ${rank2.buyerName})`);
    assert(rank2.netValue === 905000, `Rank #2 Net Value is ₹9,05,000 (actual: ₹${rank2.netValue})`);
    assert(rank2.isRecommended === false, 'Rank #2 has isRecommended = false');

    assert(rank3.buyerName === 'Apex Spices Exporters', `Rank #3 is Buyer A (Net Value ₹8,75,000, actual: ${rank3.buyerName})`);
    assert(rank3.netValue === 875000, `Rank #3 Net Value is ₹8,75,000 (actual: ₹${rank3.netValue})`);

    // -------------------------------------------------------------
    // CASE 8: ML Model Signal / Predictions
    // -------------------------------------------------------------
    console.log('\n--- Case 8: ML Model Predictions Integration ---');
    assert(rank1.mlPrediction !== undefined && rank1.mlPrediction !== null, 'ML Prediction object exists on match');
    console.log('    ML Prediction payload:', rank1.mlPrediction);

    // -------------------------------------------------------------
    // CASE 10: "Why This Buyer?" Explanations
    // -------------------------------------------------------------
    console.log('\n--- Case 10: Data-Driven Explanations ---');
    assert(Array.isArray(rank1.recommendationReasons), 'Rank #1 has recommendationReasons array');
    assert(rank1.recommendationReasons.length >= 2, `Reasons count >= 2 (actual: ${rank1.recommendationReasons.length})`);
    rank1.recommendationReasons.forEach((r) => console.log(`    • ${r}`));
    assert(
      rank1.recommendationReasons.some((r) => r.includes('Highest expected net value')),
      'Reasons mention Highest expected net value'
    );

    // -------------------------------------------------------------
    // Clean up test data
    // -------------------------------------------------------------
    await Crop.findByIdAndDelete(cropId);
    const reqAId = reqARes.data?.data?.requirement?.id || reqARes.data?.data?.requirement?._id || reqARes.data?.data?.id;
    const reqBId = reqBRes.data?.data?.requirement?.id || reqBRes.data?.data?.requirement?._id || reqBRes.data?.data?.id;
    const reqCId = reqCRes.data?.data?.requirement?.id || reqCRes.data?.data?.requirement?._id || reqCRes.data?.data?.id;
    await BuyerRequirement.deleteMany({ _id: { $in: [reqAId, reqBId, reqCId].filter(Boolean) } });
    await User.deleteMany({ _id: { $in: [farmerId, buyerAId, buyerBId, buyerCId].filter(Boolean) } });

    console.log('\n=============================================================');
    console.log(`📊 TEST SUMMARY: Passed: ${passed}, Failed: ${failed}`);
    console.log('=============================================================\n');

    await mongoose.disconnect();
    process.exit(failed === 0 ? 0 : 1);
  } catch (err) {
    console.error('Test execution error:', err);
    await mongoose.disconnect();
    process.exit(1);
  }
}

runMatchingRecommendationTests();
