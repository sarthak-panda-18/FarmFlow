/**
 * Integration Test for Deal Creation & Mutual Deal Agreement Flow
 * Task 1: Opportunity -> Accept -> Deal creation -> Deal Details fetch
 * Task 2: Official Mutual Deal Agreement (Quintal only, 4 terms, mutual confirmation timestamps)
 */

const mongoose = require('mongoose');
const User = require('../models/User');
const Crop = require('../models/Crop');
const BuyerRequirement = require('../models/BuyerRequirement');
const Opportunity = require('../models/Opportunity');
const Deal = require('../models/Deal');

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

async function runTests() {
  console.log('\n=============================================================');
  console.log('🧪 RUNNING DEAL CREATION & MUTUAL AGREEMENT INTEGRATION TESTS');
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
    const farmerMobile = '98' + suffix.toString().slice(0, 8);
    const buyerMobile = '99' + suffix.toString().slice(0, 8);
    const password = 'Password@123';

    // 1. Register Farmer
    const regFarmer = await request('/auth/register', {
      method: 'POST',
      body: {
        name: 'Ramesh Farmer',
        phone: farmerMobile,
        password,
        role: 'FARMER',
        farmerId: 'FARM' + suffix.toString().slice(0, 6),
      },
    });
    assert(regFarmer.status === 201, 'Farmer registered successfully');
    const farmerToken = regFarmer.data.data.token;
    const farmerId = regFarmer.data.data.user.id || regFarmer.data.data.user._id;

    // 2. Register Buyer
    const regBuyer = await request('/auth/register', {
      method: 'POST',
      body: {
        name: 'Suresh Trader',
        phone: buyerMobile,
        password,
        role: 'BUYER',
        businessName: 'Nashik Agro Traders',
        gstin: '27ABCDE1234F1Z5',
      },
    });
    assert(regBuyer.status === 201, 'Buyer registered successfully');
    const buyerToken = regBuyer.data.data.token;
    const buyerId = regBuyer.data.data.user.id || regBuyer.data.data.user._id;

    // Verify phone & verification status
    await User.findByIdAndUpdate(farmerId, { phoneVerified: true, verificationStatus: 'VERIFIED', isProfileComplete: true });
    await User.findByIdAndUpdate(buyerId, { phoneVerified: true, verificationStatus: 'VERIFIED', isProfileComplete: true });

    // Set location
    await request('/location', {
      method: 'PUT',
      token: farmerToken,
      body: {
        latitude: 20.17,
        longitude: 73.98,
        address: 'Pimpalgaon Farm Yard',
        city: 'Pimpalgaon',
        district: 'Nashik',
        state: 'Maharashtra',
      },
    });
    await request('/location', {
      method: 'PUT',
      token: buyerToken,
      body: {
        latitude: 19.99,
        longitude: 73.78,
        address: 'Ambad APMC Market',
        city: 'Nashik',
        district: 'Nashik',
        state: 'Maharashtra',
      },
    });

    // 3. Farmer creates active crop listing (in Quintals)
    const cropRes = await request('/crops', {
      method: 'POST',
      token: farmerToken,
      body: {
        commodity: 'Wheat',
        cropName: 'Wheat',
        variety: 'Lokwan',
        quantity: 25,
        quantityUnit: 'quintal',
        expectedPrice: 2400,
        harvestDate: new Date(Date.now() + 86400000 * 2).toISOString(),
        state: 'Maharashtra',
        district: 'Nashik',
      },
    });
    const cropId =
      cropRes.data?.data?.crop?.id ||
      cropRes.data?.data?.crop?._id ||
      cropRes.data?.data?._id ||
      cropRes.data?.data?.id;
    assert(cropRes.status === 201 && Boolean(cropId), 'Farmer crop created in Quintals (25 Quintal @ ₹2400/Q)');

    // 4. Buyer expresses interest to create Opportunity
    const opRes = await request('/opportunities', {
      method: 'POST',
      token: buyerToken,
      body: {
        cropId,
        offeredPrice: 2400,
        notes: 'Ready to purchase 25 Quintal Lokwan Wheat',
      },
    });
    const oppId =
      opRes.data?.data?.opportunity?._id ||
      opRes.data?.data?.opportunity?.id ||
      opRes.data?.data?._id ||
      opRes.data?.data?.id;
    assert(opRes.status === 201 && Boolean(oppId), 'Buyer expressed interest and created Opportunity');

    // 6. Farmer accepts opportunity (Task 1: Opportunity -> Accept -> Deal creation)
    console.log('\n--- Testing Opportunity Acceptance & Deal Creation ---');
    const acceptRes = await request(`/opportunities/${oppId}/accept`, {
      method: 'POST',
      token: farmerToken,
    });
    assert(acceptRes.status === 200 && acceptRes.data.success, 'Farmer accepted opportunity successfully');
    assert(acceptRes.data.dealId != null && acceptRes.data.dealId.length > 0, `Returned dealId is non-empty: ${acceptRes.data.dealId}`);
    assert(acceptRes.data.deal != null, 'Returned deal object in response payload');

    const dealId = acceptRes.data.dealId;

    // 7. Verify persistent Deal in MongoDB
    const dealDoc = await Deal.findById(dealId);
    assert(dealDoc != null, 'Deal document exists in MongoDB');
    assert(dealDoc.farmerId.toString() === farmerId.toString(), 'Deal has correct farmerId');
    assert(dealDoc.buyerId.toString() === buyerId.toString(), 'Deal has correct buyerId');
    assert(dealDoc.crop === 'Wheat' || dealDoc.commodity === 'Wheat', 'Deal has correct crop');
    assert(dealDoc.quantity === 25, 'Deal has correct quantity (25 Quintal)');
    assert(dealDoc.quantityUnit === 'quintal', 'Deal quantity unit is quintal');
    assert(dealDoc.agreedPrice > 0, `Deal has agreed price: ₹${dealDoc.agreedPrice}`);
    assert(dealDoc.totalAmount === dealDoc.quantity * dealDoc.agreedPrice, `Deal totalAmount is correctly computed (₹${dealDoc.totalAmount})`);
    assert(dealDoc.farmerAgreementAccepted === false && dealDoc.buyerAgreementAccepted === false, 'Agreement flags initialized as false');
    assert(dealDoc.agreementStatus === 'AGREEMENT_PENDING', 'Initial agreement status is AGREEMENT_PENDING');

    // 8. Prevent Duplicate Deals: calling accept again returns the same dealId
    const reAcceptRes = await request(`/opportunities/${oppId}/accept`, {
      method: 'POST',
      token: farmerToken,
    });
    assert(reAcceptRes.status === 200, 'Re-accepting opportunity returns 200 OK');
    assert(reAcceptRes.data.dealId === dealId, 'No duplicate deal created (same dealId returned)');

    const totalDealsForOpp = await Deal.countDocuments({ opportunityId: oppId });
    assert(totalDealsForOpp === 1, 'Strictly 1 Deal document exists for this opportunity');

    // 9. Fetch Deal by ID (GET /api/deals/:id)
    console.log('\n--- Testing Deal Details Fetch ---');
    const fetchFarmer = await request(`/deals/${dealId}`, {
      method: 'GET',
      token: farmerToken,
    });
    assert(fetchFarmer.status === 200 && fetchFarmer.data.success, 'Farmer fetched deal details (200 OK)');
    assert(fetchFarmer.data.data != null && fetchFarmer.data.data._id === dealId, 'data._id matches dealId');
    assert(fetchFarmer.data.deal != null && fetchFarmer.data.deal._id === dealId, 'deal._id matches dealId (Flutter compatibility)');

    const fetchBuyer = await request(`/deals/${dealId}`, {
      method: 'GET',
      token: buyerToken,
    });
    assert(fetchBuyer.status === 200 && fetchBuyer.data.success, 'Buyer fetched deal details (200 OK)');

    // 10. Test Invalid & Missing Deal ID Handling
    const invalidIdRes = await request('/deals/invalid-id-999', {
      method: 'GET',
      token: farmerToken,
    });
    assert(invalidIdRes.status === 400, 'Invalid deal ID returned 400 Bad Request');

    const notFoundRes = await request('/deals/507f1f77bcf86cd799439011', {
      method: 'GET',
      token: farmerToken,
    });
    assert(notFoundRes.status === 404, 'Non-existent deal ID returned 404 Not Found');

    // 11. Task 2: Official Mutual Deal Agreement
    console.log('\n--- Testing Task 2: Official Mutual Deal Agreement ---');
    const agreementRes = await request(`/deals/${dealId}/agreement`, {
      method: 'GET',
      token: farmerToken,
    });
    assert(agreementRes.status === 200 && agreementRes.data.success, 'Fetched Deal Agreement (200 OK)');
    assert(agreementRes.data.data.termsAndConditions.length === 4, 'Deal Agreement includes exactly 4 Terms & Conditions');
    assert(agreementRes.data.data.termsAndConditions[0].includes('mutually agree'), 'Terms contain mutual agreement text');
    assert(agreementRes.data.data.termsAndConditions[1].includes('obligations'), 'Terms contain obligation text');
    assert(agreementRes.data.data.termsAndConditions[2].includes('digitally in FarmFlow'), 'Terms contain FarmFlow recording text');
    assert(agreementRes.data.data.termsAndConditions[3].includes('payment/delivery confirmation'), 'Terms contain payment/delivery confirmation text');

    // 12. Step A: Farmer Confirms Agreement
    const farmerConfirmRes = await request(`/deals/${dealId}/agreement/accept`, {
      method: 'POST',
      token: farmerToken,
      body: { agreeToTerms: true, agreementVersion: 1 },
    });
    assert(farmerConfirmRes.status === 200 && farmerConfirmRes.data.success, 'Farmer confirmed deal agreement');
    assert(farmerConfirmRes.data.bothAccepted === false, 'bothAccepted is false (waiting for buyer)');
    assert(farmerConfirmRes.data.agreementStatus === 'WAITING_FOR_BUYER', 'agreementStatus is WAITING_FOR_BUYER');

    const dealAfterFarmer = await Deal.findById(dealId);
    assert(dealAfterFarmer.farmerAgreementAccepted === true, 'MongoDB deal has farmerAgreementAccepted: true');
    assert(dealAfterFarmer.buyerAgreementAccepted === false, 'MongoDB deal has buyerAgreementAccepted: false');
    assert(dealAfterFarmer.farmerAcceptedAt != null, 'MongoDB deal has farmerAcceptedAt timestamp recorded');

    // 13. Step B: Buyer Confirms Agreement
    const buyerConfirmRes = await request(`/deals/${dealId}/agreement/accept`, {
      method: 'POST',
      token: buyerToken,
      body: { agreeToTerms: true, agreementVersion: 1 },
    });
    assert(buyerConfirmRes.status === 200 && buyerConfirmRes.data.success, 'Buyer confirmed deal agreement');
    assert(buyerConfirmRes.data.bothAccepted === true, 'bothAccepted is true (deal fully confirmed)');
    assert(buyerConfirmRes.data.agreementStatus === 'DEAL_CONFIRMED', 'agreementStatus is DEAL_CONFIRMED');

    const dealAfterBoth = await Deal.findById(dealId);
    assert(dealAfterBoth.buyerAgreementAccepted === true, 'MongoDB deal has buyerAgreementAccepted: true');
    assert(dealAfterBoth.farmerAgreementAccepted === true, 'MongoDB deal has farmerAgreementAccepted: true');
    assert(dealAfterBoth.buyerAcceptedAt != null, 'MongoDB deal has buyerAcceptedAt timestamp recorded');
    assert(dealAfterBoth.farmerAcceptedAt != null, 'MongoDB deal has farmerAcceptedAt timestamp recorded');
    assert(dealAfterBoth.agreementStatus === 'DEAL_CONFIRMED', 'Deal agreementStatus is DEAL_CONFIRMED');
    assert(dealAfterBoth.status === 'CONFIRMED' || dealAfterBoth.status === 'DEAL_CONFIRMED', 'Deal status is CONFIRMED');

    // 14. Verify Agreement Endpoint reports fully confirmed
    const finalAgreementRes = await request(`/deals/${dealId}/agreement`, {
      method: 'GET',
      token: farmerToken,
    });
    assert(finalAgreementRes.data.data.isFullyConfirmed === true, 'Agreement isFullyConfirmed is true');
    assert(finalAgreementRes.data.data.farmer.hasAccepted === true, 'Farmer hasAccepted is true');
    assert(finalAgreementRes.data.data.buyer.hasAccepted === true, 'Buyer hasAccepted is true');

    console.log('\n=============================================================');
    console.log(`📊 RESULTS: ${passed} PASSED, ${failed} FAILED`);
    console.log('=============================================================\n');

    process.exit(failed > 0 ? 1 : 0);
  } catch (err) {
    console.error('Test execution error:', err);
    process.exit(1);
  }
}

runTests();
