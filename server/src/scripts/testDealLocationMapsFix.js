/**
 * Integration Test for Google Maps Location Data Flow in Deals
 * Verifies:
 * 1. Coordinates and complete sanitized addresses are correctly resolved from User / Listing / Mandi lookup.
 * 2. Deal creation never produces "," or empty queries.
 * 3. GET /api/deals/:id and GET /api/deals/:id/agreement return valid pickup/delivery locations and mapsUrls.
 * 4. Legacy deals with "," or missing coordinates are dynamically healed and enriched on retrieval.
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
  console.log('🧪 RUNNING GOOGLE MAPS LOCATION DATA INTEGRATION TESTS');
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

    // 1. Register Farmer with District and State
    const regFarmer = await request('/auth/register', {
      method: 'POST',
      body: {
        name: 'Ramesh Patil',
        phone: farmerMobile,
        password,
        role: 'FARMER',
        farmerId: 'FARM' + suffix.toString().slice(0, 6),
        district: 'Nashik',
        state: 'Maharashtra',
        address: 'Pimpalgaon Farm House',
      },
    });
    assert(regFarmer.status === 201, 'Farmer registered with address/district/state');
    const farmerToken = regFarmer.data.data.token;
    const farmerId = regFarmer.data.data.user.id || regFarmer.data.data.user._id;

    // 2. Register Buyer with District and State
    const regBuyer = await request('/auth/register', {
      method: 'POST',
      body: {
        name: 'Suresh Agarwal',
        phone: buyerMobile,
        password,
        role: 'BUYER',
        businessName: 'Nashik Agro Traders',
        gstin: '27ABCDE1234F1Z5',
        district: 'Pune',
        state: 'Maharashtra',
        address: 'Market Yard Gate 2',
      },
    });
    assert(regBuyer.status === 201, 'Buyer registered with address/district/state');
    const buyerToken = regBuyer.data.data.token;
    const buyerId = regBuyer.data.data.user.id || regBuyer.data.data.user._id;

    await User.findByIdAndUpdate(farmerId, { phoneVerified: true, verificationStatus: 'VERIFIED', isProfileComplete: true });
    await User.findByIdAndUpdate(buyerId, { phoneVerified: true, verificationStatus: 'VERIFIED', isProfileComplete: true });

    // 3. Farmer creates Crop listing
    const cropRes = await request('/crops', {
      method: 'POST',
      token: farmerToken,
      body: {
        commodity: 'Wheat',
        cropName: 'Wheat',
        variety: 'Lokwan',
        quantity: 30,
        quantityUnit: 'quintal',
        expectedPrice: 2500,
        harvestDate: new Date(Date.now() + 86400000 * 2).toISOString(),
        state: 'Maharashtra',
        district: 'Nashik',
        market: 'Pimpalgaon',
        location: 'Pimpalgaon APMC Yard',
      },
    });
    assert(cropRes.status === 201, 'Crop listing created');
    const cropId =
      cropRes.data?.data?.crop?.id ||
      cropRes.data?.data?.crop?._id ||
      cropRes.data?.data?._id ||
      cropRes.data?.data?.id ||
      cropRes.data?.crop?._id ||
      cropRes.data?.crop?.id;

    // 4. Buyer creates Requirement listing
    const reqRes = await request('/requirements', {
      method: 'POST',
      token: buyerToken,
      body: {
        commodity: 'Wheat',
        cropName: 'Wheat',
        quantity: 30,
        quantityUnit: 'quintal',
        offeredPrice: 2500,
        requiredByDate: new Date(Date.now() + 86400000 * 5).toISOString(),
        state: 'Maharashtra',
        district: 'Pune',
        market: 'Pune',
        location: 'Market Yard Pune Gultekdi',
      },
    });
    assert(reqRes.status === 201, 'Buyer requirement created');
    const requirementId = reqRes.data?.data?.id || reqRes.data?.data?._id;

    // 5. Buyer expresses interest in Crop
    const oppRes = await request('/opportunities', {
      method: 'POST',
      token: buyerToken,
      body: {
        cropId,
        offeredPrice: 2500,
        notes: 'Ready for quick delivery',
      },
    });
    console.log('oppRes:', oppRes.status, oppRes.data);
    const opportunityId =
      oppRes.data?.data?.opportunity?.id ||
      oppRes.data?.data?.opportunity?._id ||
      oppRes.data?.data?.id ||
      oppRes.data?.data?._id;
    assert(oppRes.status === 201 && Boolean(opportunityId), 'Opportunity created from interest');

    // 6. Farmer accepts Opportunity -> Creates Deal
    const acceptRes = await request(`/opportunities/${opportunityId}/accept`, {
      method: 'POST',
      token: farmerToken,
      body: { notes: 'Accepted agreed price' },
    });
    assert(acceptRes.status === 200, 'Opportunity accepted by farmer');
    const dealId = acceptRes.data?.dealId || acceptRes.data?.data?.opportunity?.dealId;
    assert(dealId != null && dealId.length > 0, `Deal ID returned from accept: ${dealId}`);

    // 7. Verify Deal document in MongoDB directly
    const dbDeal = await Deal.findById(dealId);
    assert(dbDeal != null, 'Deal persisted in MongoDB');
    assert(dbDeal.pickupLocation.address !== ', ' && dbDeal.pickupLocation.address.length > 0, `Farmer Pickup address stored: "${dbDeal.pickupLocation.address}"`);
    assert(dbDeal.deliveryLocation.address !== ', ' && dbDeal.deliveryLocation.address.length > 0, `Buyer Delivery address stored: "${dbDeal.deliveryLocation.address}"`);
    assert(dbDeal.pickupLocation.latitude != null && dbDeal.pickupLocation.longitude != null, `Farmer GPS Coordinates stored: ${dbDeal.pickupLocation.latitude}, ${dbDeal.pickupLocation.longitude}`);
    assert(dbDeal.deliveryLocation.latitude != null && dbDeal.deliveryLocation.longitude != null, `Buyer GPS Coordinates stored: ${dbDeal.deliveryLocation.latitude}, ${dbDeal.deliveryLocation.longitude}`);
    assert(dbDeal.distanceKm != null && dbDeal.distanceKm > 0, `Distance calculated: ${dbDeal.distanceKm} km`);

    // 8. Test GET /api/deals/:id as Farmer
    const getDealFarmer = await request(`/deals/${dealId}`, {
      method: 'GET',
      token: farmerToken,
    });
    assert(getDealFarmer.status === 200, 'GET /api/deals/:id succeeded for Farmer');
    const dealData = getDealFarmer.data.data;
    assert(!dealData.pickupAddress.includes(', ,') && dealData.pickupAddress !== ', ', `deal.pickupAddress clean: "${dealData.pickupAddress}"`);
    assert(!dealData.deliveryAddress.includes(', ,') && dealData.deliveryAddress !== ', ', `deal.deliveryAddress clean: "${dealData.deliveryAddress}"`);
    assert(dealData.pickupMapsUrl != null && !dealData.pickupMapsUrl.includes('query=,') && !dealData.pickupMapsUrl.includes('query=%2C'), `pickupMapsUrl valid: ${dealData.pickupMapsUrl}`);
    assert(dealData.deliveryMapsUrl != null && !dealData.deliveryMapsUrl.includes('query=,') && !dealData.deliveryMapsUrl.includes('query=%2C'), `deliveryMapsUrl valid: ${dealData.deliveryMapsUrl}`);

    // 9. Test GET /api/deals/:id/agreement as Buyer
    const getAgreementBuyer = await request(`/deals/${dealId}/agreement`, {
      method: 'GET',
      token: buyerToken,
    });
    assert(getAgreementBuyer.status === 200, 'GET /api/deals/:id/agreement succeeded for Buyer');
    const agData = getAgreementBuyer.data.data;
    assert(agData.pickupLocation.address.length > 0 && agData.pickupLocation.address !== ', ', `Agreement pickup address: "${agData.pickupLocation.address}"`);
    assert(agData.deliveryLocation.address.length > 0 && agData.deliveryLocation.address !== ', ', `Agreement delivery address: "${agData.deliveryLocation.address}"`);
    assert(agData.pickupLocation.mapsUrl != null && !agData.pickupLocation.mapsUrl.includes('query=,'), `Agreement pickup mapsUrl: ${agData.pickupLocation.mapsUrl}`);
    assert(agData.deliveryLocation.mapsUrl != null && !agData.deliveryLocation.mapsUrl.includes('query=,'), `Agreement delivery mapsUrl: ${agData.deliveryLocation.mapsUrl}`);

    // 10. Test Dynamic Healing of Legacy Deal with broken "," address and missing coords
    const legacyDeal = await Deal.create({
      farmerId,
      buyerId,
      opportunityId,
      cropId,
      requirementId,
      commodity: 'Wheat',
      crop: 'Wheat',
      quantity: 10,
      quantityUnit: 'quintal',
      agreedPrice: 2500,
      agreedPriceUnit: 'quintal',
      status: 'AGREEMENT_PENDING',
      agreementStatus: 'AGREEMENT_PENDING',
      pickupLocation: {
        address: ', ',
        latitude: null,
        longitude: null,
      },
      deliveryLocation: {
        address: ', ',
        latitude: null,
        longitude: null,
      },
    });

    const getHealedDeal = await request(`/deals/${legacyDeal._id}`, {
      method: 'GET',
      token: farmerToken,
    });
    assert(getHealedDeal.status === 200, 'GET /api/deals/:legacyId succeeded');
    const healedData = getHealedDeal.data.data;
    assert(healedData.pickupAddress !== ', ' && healedData.pickupAddress.length > 0, `Legacy deal pickupAddress dynamically healed: "${healedData.pickupAddress}"`);
    assert(healedData.deliveryAddress !== ', ' && healedData.deliveryAddress.length > 0, `Legacy deal deliveryAddress dynamically healed: "${healedData.deliveryAddress}"`);
    assert(healedData.pickupLat != null && healedData.pickupLng != null, `Legacy deal coordinates dynamically resolved: ${healedData.pickupLat}, ${healedData.pickupLng}`);
    assert(healedData.pickupMapsUrl != null && !healedData.pickupMapsUrl.includes('query=,'), `Legacy deal mapsUrl valid: ${healedData.pickupMapsUrl}`);

  } catch (err) {
    console.error('💥 Integration test exception:', err);
    failed++;
  } finally {
    await mongoose.disconnect();
    console.log('\n=============================================================');
    console.log(`📊 TEST SUMMARY: Passed: ${passed}, Failed: ${failed}`);
    console.log('=============================================================\n');
    process.exit(failed > 0 ? 1 : 0);
  }
}

runTests();
