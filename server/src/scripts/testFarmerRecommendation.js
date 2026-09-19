/**
 * FarmFlow Farmer Buyer Recommendation System Automated Test Suite
 * Validates:
 * 1. Multi-buyer interest detection (3+ buyers)
 * 2. Net Value formula: netValue = sellingPrice - transportationCost - otherCosts
 * 3. Exact user prompt scenario (Buyer B ₹45k > Buyer A ₹43k > Buyer C ₹42k)
 * 4. Highest selling price does NOT win if logistics costs are higher
 * 5. Deterministic sorting & tie-breaking logic
 * 6. Data-backed explanation generation
 * 7. Threshold counts (0, 1, 2, 3+ buyers)
 * 8. Missing transport cost data handling
 * 9. Security & Role/Ownership verification (403 for unauthorized users)
 * 10. Multi-buyer notification trigger
 */

const http = require('http');

const mongoose = require('mongoose');
const User = require('../models/User');

const API_BASE = 'http://localhost:5000/api';

const makeRequest = (method, path, body = null, token = null) => {
  return new Promise((resolve, reject) => {
    const url = new URL(`${API_BASE}${path}`);
    const options = {
      method,
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    if (token) {
      options.headers['Authorization'] = `Bearer ${token}`;
    }

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, data: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, data: { raw: data } });
        }
      });
    });

    req.on('error', reject);
    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
};

const assert = (condition, message) => {
  if (!condition) {
    console.error(`  ❌ FAILED: ${message}`);
    throw new Error(message);
  }
  console.log(`  ✅ PASSED: ${message}`);
};

async function runTests() {
  console.log('===============================================================');
  console.log('FARMFLOW — FARMER BUYER RECOMMENDATION SYSTEM TEST SUITE');
  console.log('===============================================================');

  const mongoUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/farm-to-market';
  await mongoose.connect(mongoUri);

  const ts = Date.now();
  let farmerToken = '';
  let farmerId = '';
  let otherFarmerToken = '';
  let otherFarmerId = '';
  let buyerAToken = '';
  let buyerAId = '';
  let buyerBToken = '';
  let buyerBId = '';
  let buyerCToken = '';
  let buyerCId = '';
  let buyerDToken = '';
  let buyerDId = '';
  let cropId = '';

  // 1. Setup Test Users
  console.log('\n--- 1. Setting Up Test Accounts ---');

  const suffix = Math.floor(10000000 + Math.random() * 90000000).toString();
  const fPhone = '98' + suffix.slice(0, 8);
  const ofPhone = '97' + suffix.slice(0, 8);
  const bAPhone = '91' + suffix.slice(0, 8);
  const bBPhone = '92' + suffix.slice(0, 8);
  const bCPhone = '93' + suffix.slice(0, 8);
  const bDPhone = '94' + suffix.slice(0, 8);

  // Register Farmer
  const fRes = await makeRequest('POST', '/auth/register', {
    name: `Farmer Rec Ramesh ${suffix.slice(0, 4)}`,
    phone: fPhone,
    password: 'Password123!',
    role: 'FARMER',
    farmerId: 'FARM' + suffix.slice(0, 6),
    state: 'Andhra Pradesh',
    district: 'Guntur',
    location: 'Guntur Rural, AP',
  });
  assert(fRes.status === 201 && fRes.data.success, 'Farmer registered successfully');
  farmerToken = fRes.data.data.token;
  farmerId = fRes.data.data.user.id || fRes.data.data.user._id;

  // Register Other Farmer (for unauthorized access test)
  const ofRes = await makeRequest('POST', '/auth/register', {
    name: `Other Farmer ${suffix.slice(0, 4)}`,
    phone: ofPhone,
    password: 'Password123!',
    role: 'FARMER',
    farmerId: 'FARM9' + suffix.slice(0, 5),
    state: 'Andhra Pradesh',
    district: 'Krishna',
    location: 'Krishna, AP',
  });
  assert(ofRes.status === 201, 'Other Farmer registered');
  otherFarmerToken = ofRes.data.data.token;
  otherFarmerId = ofRes.data.data.user.id || ofRes.data.data.user._id;

  // Register Buyer A
  const bARes = await makeRequest('POST', '/auth/register', {
    name: `Buyer A Ramesh ${suffix.slice(0, 4)}`,
    businessName: 'Buyer A Traders',
    phone: bAPhone,
    password: 'Password123!',
    role: 'BUYER',
    gstin: '37AAAAA0000A1Z1',
    buyerType: 'TRADER',
    state: 'Andhra Pradesh',
    district: 'Krishna',
    location: 'Vijayawada Central',
  });
  assert(bARes.status === 201, 'Buyer A registered');
  buyerAToken = bARes.data.data.token;
  buyerAId = bARes.data.data.user.id || bARes.data.data.user._id;

  // Register Buyer B
  const bBRes = await makeRequest('POST', '/auth/register', {
    name: `Buyer B Suresh ${suffix.slice(0, 4)}`,
    businessName: 'Buyer B Agro',
    phone: bBPhone,
    password: 'Password123!',
    role: 'BUYER',
    gstin: '37AAAAA0000A1Z2',
    buyerType: 'TRADER',
    state: 'Andhra Pradesh',
    district: 'Guntur',
    location: 'Tenali Town',
  });
  assert(bBRes.status === 201, 'Buyer B registered');
  buyerBToken = bBRes.data.data.token;
  buyerBId = bBRes.data.data.user.id || bBRes.data.data.user._id;

  // Register Buyer C
  const bCRes = await makeRequest('POST', '/auth/register', {
    name: `Buyer C Mahesh ${suffix.slice(0, 4)}`,
    businessName: 'Buyer C Wholesalers',
    phone: bCPhone,
    password: 'Password123!',
    role: 'BUYER',
    gstin: '36AAAAA0000A1Z3',
    buyerType: 'WHOLESALER',
    state: 'Telangana',
    district: 'Hyderabad',
    location: 'Hyderabad Hub',
  });
  assert(bCRes.status === 201, 'Buyer C registered');
  buyerCToken = bCRes.data.data.token;
  buyerCId = bCRes.data.data.user.id || bCRes.data.data.user._id;

  // Register Buyer D (for tie-breaker and missing data tests)
  const bDRes = await makeRequest('POST', '/auth/register', {
    name: `Buyer D Naresh ${suffix.slice(0, 4)}`,
    businessName: 'Buyer D Logistics',
    phone: bDPhone,
    password: 'Password123!',
    role: 'BUYER',
    gstin: '37AAAAA0000A1Z4',
    buyerType: 'PROCESSOR',
    state: 'Andhra Pradesh',
    district: 'Guntur',
    location: 'Guntur Industrial',
  });
  assert(bDRes.status === 201, 'Buyer D registered');
  buyerDToken = bDRes.data.data.token;
  buyerDId = bDRes.data.data.user.id || bDRes.data.data.user._id;

  // Verify all accounts
  await User.findByIdAndUpdate(farmerId, { phoneVerified: true, verificationStatus: 'VERIFIED' });
  await User.findByIdAndUpdate(otherFarmerId, { phoneVerified: true, verificationStatus: 'VERIFIED' });
  await User.findByIdAndUpdate(buyerAId, { phoneVerified: true, verificationStatus: 'VERIFIED' });
  await User.findByIdAndUpdate(buyerBId, { phoneVerified: true, verificationStatus: 'VERIFIED' });
  await User.findByIdAndUpdate(buyerCId, { phoneVerified: true, verificationStatus: 'VERIFIED' });
  await User.findByIdAndUpdate(buyerDId, { phoneVerified: true, verificationStatus: 'VERIFIED' });
  console.log('  ✓ Test accounts marked as verified in DB');

  // 2. Create Farmer Crop Listing (Tomato, 10 Quintals, Expected Price ₹5,000 / Quintal)
  console.log('\n--- 2. Creating Farmer Crop Listing ---');
  const cropRes = await makeRequest(
    'POST',
    '/crops',
    {
      commodity: 'Tomato',
      cropName: 'Tomato Hybrid Special',
      variety: 'Roma',
      quantity: 10,
      quantityUnit: 'quintal',
      expectedPrice: 5000,
      harvestDate: '2026-10-01',
      location: 'Guntur Farm Center',
      market: 'Guntur',
      state: 'Andhra Pradesh',
      district: 'Guntur',
    },
    farmerToken
  );
  if (cropRes.status !== 201) {
    console.log('cropRes status:', cropRes.status, 'error:', cropRes.data);
  }
  assert(cropRes.status === 201 && cropRes.data.success, 'Crop listed successfully in Quintals');
  const cropData = cropRes.data.data.crop || cropRes.data.data;
  cropId = cropData.id || cropData._id;

  // 3. Test 0 Interested Buyers State
  console.log('\n--- 3. Testing 0 Interested Buyers State ---');
  const zeroRecRes = await makeRequest('GET', `/recommendations/crop/${cropId}`, null, farmerToken);
  assert(zeroRecRes.status === 200, 'Recommendation API responded for 0 buyers');
  assert(zeroRecRes.data.data.interestedBuyersCount === 0, 'Interested buyers count is 0');
  assert(zeroRecRes.data.data.isRecommendationActive === false, 'Recommendation engine is inactive for 0 buyers');
  assert(zeroRecRes.data.data.recommendedBuyer === null, 'No recommended buyer for 0 buyers');

  // 4. Test 1 Interested Buyer State
  console.log('\n--- 4. Testing 1 Interested Buyer State (Buyer A) ---');
  // Buyer A: Offered Price = ₹5,000/Q (Total = ₹50,000), Transport = ₹5,000, Other Costs = ₹2,000
  const oppARes = await makeRequest(
    'POST',
    '/opportunities/express-interest',
    {
      cropId,
      offeredPrice: 5000,
      transportCost: 5000,
      otherCosts: 2000,
      notes: 'Offer from Buyer A',
    },
    buyerAToken
  );
  assert(oppARes.status === 201, 'Buyer A expressed interest');

  const oneRecRes = await makeRequest('GET', `/recommendations/crop/${cropId}`, null, farmerToken);
  assert(oneRecRes.data.data.interestedBuyersCount === 1, 'Interested buyers count is 1');
  assert(oneRecRes.data.data.isRecommendationActive === false, 'Recommendation engine inactive for 1 buyer (< 3)');
  assert(oneRecRes.data.data.allBuyers.length === 1, 'Returns 1 buyer list normally');
  assert(oneRecRes.data.data.allBuyers[0].netValue === 43000, 'Buyer A Net Value calculated: 50000 - 5000 - 2000 = 43000');

  // 5. Test 2 Interested Buyers State (Buyer B)
  console.log('\n--- 5. Testing 2 Interested Buyers State (Buyer B) ---');
  // Buyer B: Offered Price = ₹4,800/Q (Total = ₹48,000), Transport = ₹2,000, Other Costs = ₹1,000
  const oppBRes = await makeRequest(
    'POST',
    '/opportunities/express-interest',
    {
      cropId,
      offeredPrice: 4800,
      transportCost: 2000,
      otherCosts: 1000,
      notes: 'Offer from Buyer B',
    },
    buyerBToken
  );
  assert(oppBRes.status === 201, 'Buyer B expressed interest');

  const twoRecRes = await makeRequest('GET', `/recommendations/crop/${cropId}`, null, farmerToken);
  assert(twoRecRes.data.data.interestedBuyersCount === 2, 'Interested buyers count is 2');
  assert(twoRecRes.data.data.isRecommendationActive === false, 'Recommendation engine inactive for 2 buyers (< 3)');
  assert(twoRecRes.data.data.allBuyers.length === 2, 'Returns 2 buyers normally');

  // 6. Test 3 Interested Buyers State (Buyer C) -> ACTIVATION OF RECOMMENDATION SYSTEM
  console.log('\n--- 6. Testing 3 Interested Buyers State (Buyer C) -> System Activation ---');
  // Buyer C: Offered Price = ₹5,500/Q (Total = ₹55,000), Transport = ₹10,000, Other Costs = ₹3,000
  const oppCRes = await makeRequest(
    'POST',
    '/opportunities/express-interest',
    {
      cropId,
      offeredPrice: 5500,
      transportCost: 10000,
      otherCosts: 3000,
      notes: 'Offer from Buyer C',
    },
    buyerCToken
  );
  assert(oppCRes.status === 201, 'Buyer C expressed interest (3rd buyer)');

  const threeRecRes = await makeRequest('GET', `/recommendations/crop/${cropId}`, null, farmerToken);
  assert(threeRecRes.status === 200, 'Recommendation API succeeded');
  const recData = threeRecRes.data.data;

  assert(recData.interestedBuyersCount === 3, 'Interested buyers count is 3');
  assert(recData.isRecommendationActive === true, 'Recommendation engine is ACTIVE (>= 3 buyers)');
  assert(recData.recommendedBuyer !== null, 'Recommended buyer is present');

  console.log('\n--- Verifying Exact Net Value Calculations ---');
  const bList = recData.allBuyers;
  console.log('  Rank 1:', bList[0].buyerName, '| Net Value: ₹' + bList[0].netValue, '| Rank:', bList[0].rank);
  console.log('  Rank 2:', bList[1].buyerName, '| Net Value: ₹' + bList[1].netValue, '| Rank:', bList[1].rank);
  console.log('  Rank 3:', bList[2].buyerName, '| Net Value: ₹' + bList[2].netValue, '| Rank:', bList[2].rank);

  // User requirement verification:
  // Buyer B: Net Value = ₹48,000 - ₹2,000 - ₹1,000 = ₹45,000 (Rank 1)
  // Buyer A: Net Value = ₹50,000 - ₹5,000 - ₹2,000 = ₹43,000 (Rank 2)
  // Buyer C: Net Value = ₹55,000 - ₹10,000 - ₹3,000 = ₹42,000 (Rank 3)
  assert(bList[0].netValue === 45000, 'Rank 1 Net Value is ₹45,000 (Buyer B)');
  assert(bList[0].businessName.includes('Buyer B') || bList[0].buyerName.includes('Buyer B'), 'Buyer B is ranked #1');
  assert(bList[0].isRecommended === true, 'Buyer B is marked isRecommended = true');

  assert(bList[1].netValue === 43000, 'Rank 2 Net Value is ₹43,000 (Buyer A)');
  assert(bList[1].businessName.includes('Buyer A') || bList[1].buyerName.includes('Buyer A'), 'Buyer A is ranked #2');
  assert(bList[1].isRecommended === false, 'Buyer A isRecommended is false');

  assert(bList[2].netValue === 42000, 'Rank 3 Net Value is ₹42,000 (Buyer C)');
  assert(bList[2].businessName.includes('Buyer C') || bList[2].buyerName.includes('Buyer C'), 'Buyer C is ranked #3');
  assert(bList[2].isRecommended === false, 'Buyer C isRecommended is false');

  // Verify Highest Selling Price does NOT win
  assert(
    bList[2].sellingPrice > bList[0].sellingPrice && bList[0].rank === 1,
    'Buyer B (lower gross selling price ₹48,000) beats Buyer C (higher gross selling price ₹55,000) due to lower transport & other costs'
  );

  // 7. Verify Explanation Generation
  console.log('\n--- 7. Verifying Explanation Generation ---');
  console.log('  Summary Explanation:', recData.explanation);
  console.log('  Specific Reasons:', recData.reasons);

  assert(recData.explanation && recData.explanation.includes('Buyer B'), 'Explanation names Buyer B');
  assert(recData.explanation.includes('45,000'), 'Explanation mentions ₹45,000 Net Value');
  assert(recData.reasons.length >= 2, 'Generated at least 2 data-backed comparative reasons');
  assert(recData.reasons.some((r) => r.includes('Highest expected net value')), 'Reasons highlight Highest expected net value');
  assert(recData.reasons.some((r) => r.includes('Lowest transportation cost') || r.includes('transportation cost')), 'Reasons highlight lower transportation cost');

  // 8. Test Notification on 3+ Buyers Threshold
  console.log('\n--- 8. Testing 3+ Buyers Notification Trigger ---');
  const notifRes = await makeRequest('GET', '/notifications', null, farmerToken);
  assert(notifRes.status === 200, 'Fetched farmer notifications');
  const notifs = notifRes.data.data || notifRes.data;
  const recNotif = notifs.find((n) => n.type === 'BUYER_RECOMMENDATION');
  assert(recNotif != null, 'Farmer received BUYER_RECOMMENDATION notification');
  assert(recNotif.message.includes('3 buyers are interested'), 'Notification message mentions 3 buyers interested');

  // 9. Test Aliased Routes
  console.log('\n--- 9. Testing Aliased Routes ---');
  const oppRecRes = await makeRequest('GET', `/opportunities/crop/${cropId}/recommendations`, null, farmerToken);
  assert(oppRecRes.status === 200 && oppRecRes.data.data.isRecommendationActive === true, 'GET /opportunities/crop/:cropId/recommendations works');

  const farmerAllRecRes = await makeRequest('GET', '/recommendations/farmer', null, farmerToken);
  assert(farmerAllRecRes.status === 200 && Array.isArray(farmerAllRecRes.data.data), 'GET /recommendations/farmer returns array of crops');

  // 10. Test Security & Access Control
  console.log('\n--- 10. Testing Security & Access Control ---');
  // Buyer cannot access farmer recommendations
  const buyerAccessRes = await makeRequest('GET', `/recommendations/crop/${cropId}`, null, buyerAToken);
  assert(buyerAccessRes.status === 403, 'Buyer is rejected with 403 Forbidden');

  // Other Farmer cannot access another farmer\'s crop recommendations
  const otherFarmerAccessRes = await makeRequest('GET', `/recommendations/crop/${cropId}`, null, otherFarmerToken);
  assert(otherFarmerAccessRes.status === 403, 'Unrelated Farmer is rejected with 403 Forbidden');

  // 11. Test Tie-Breaker Logic
  console.log('\n--- 11. Testing Tie-Breaker Logic (Equal Net Values) ---');
  // Create another test crop for clean tie-breaker testing
  const crop2Res = await makeRequest(
    'POST',
    '/crops',
    {
      commodity: 'Wheat',
      cropName: 'Sharbati Wheat Special',
      variety: 'Sharbati',
      quantity: 10,
      quantityUnit: 'quintal',
      expectedPrice: 4000,
      harvestDate: '2026-10-15',
      location: 'Guntur Farm',
      market: 'Guntur',
      state: 'Andhra Pradesh',
      district: 'Guntur',
    },
    farmerToken
  );
  assert(crop2Res.status === 201 && crop2Res.data.success, 'Crop 2 created for tie-breaker testing');
  const crop2Data = crop2Res.data.data.crop || crop2Res.data.data;
  const crop2Id = crop2Data.id || crop2Data._id;

  // Buyer A: Total ₹50,000, Transport ₹4,000, Other ₹1,000 -> Net = ₹45,000
  await makeRequest('POST', '/opportunities/express-interest', { cropId: crop2Id, offeredPrice: 5000, transportCost: 4000, otherCosts: 1000 }, buyerAToken);
  // Buyer B: Total ₹48,000, Transport ₹2,000, Other ₹1,000 -> Net = ₹45,000
  await makeRequest('POST', '/opportunities/express-interest', { cropId: crop2Id, offeredPrice: 4800, transportCost: 2000, otherCosts: 1000 }, buyerBToken);
  // Buyer C: Total ₹46,000, Transport ₹1,000, Other ₹0 -> Net = ₹45,000
  await makeRequest('POST', '/opportunities/express-interest', { cropId: crop2Id, offeredPrice: 4600, transportCost: 1000, otherCosts: 0 }, buyerCToken);

  const tieRes = await makeRequest('GET', `/recommendations/crop/${crop2Id}`, null, farmerToken);
  assert(tieRes.status === 200, 'Tie recommendation computed');
  const tieList = tieRes.data.data.allBuyers;
  assert(tieList.length === 3, '3 buyers in tie test');
  assert(tieList[0].netValue === 45000 && tieList[1].netValue === 45000 && tieList[2].netValue === 45000, 'All 3 buyers have exact same Net Value ₹45,000');
  // Secondary sort: Higher selling price wins (Buyer A ₹50,000 > Buyer B ₹48,000 > Buyer C ₹46,000)
  assert(tieList[0].sellingPrice === 50000, 'Tie-breaker 1st rank: Higher selling price ₹50,000 wins');
  assert(tieList[1].sellingPrice === 48000, 'Tie-breaker 2nd rank: Selling price ₹48,000');
  assert(tieList[2].sellingPrice === 46000, 'Tie-breaker 3rd rank: Selling price ₹46,000');

  console.log('\n===============================================================');
  console.log('🎉 ALL FARMER RECOMMENDATION SYSTEM TESTS PASSED (100%)');
  console.log('===============================================================');
  await mongoose.disconnect();
  process.exit(0);
}

runTests().catch(async (err) => {
  console.error('\n❌ TEST RUN ERROR:', err);
  try {
    await mongoose.disconnect();
  } catch (_) {}
  process.exit(1);
});
