require('dotenv').config({ path: __dirname + '/../../.env' });
const mongoose = require('mongoose');
const http = require('http');
const app = require('../app');
const User = require('../models/User');
const Crop = require('../models/Crop');
const BuyerRequirement = require('../models/BuyerRequirement');
const { calculateHaversineDistance, isValidCoordinates, buildGoogleMapsUrl } = require('../utils/geoUtils');

const runPhase6And7Tests = async () => {
  console.log('--- STARTING PHASE 6 & PHASE 7 TEST SUITE ---');

  const mongoUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/farm-to-market';
  await mongoose.connect(mongoUri);
  console.log('[DB] Connected to MongoDB.');

  await User.updateMany({ 'location.coordinates': { $exists: false } }, { $unset: { location: 1 } });
  await Crop.updateMany({ 'locationCoordinates.coordinates': { $exists: false } }, { $unset: { locationCoordinates: 1 } });
  await BuyerRequirement.updateMany({ 'locationCoordinates.coordinates': { $exists: false } }, { $unset: { locationCoordinates: 1 } });

  await Promise.allSettled([
    User.syncIndexes(),
    Crop.syncIndexes(),
    BuyerRequirement.syncIndexes(),
  ]);

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;
  const baseUrl = `http://localhost:${port}/api`;
  console.log(`[SERVER] Test server running at ${baseUrl}`);

  try {
    // 1. Test Haversine Distance Utility
    console.log('\n[TEST 1] Testing Haversine Distance & Geo Utilities...');
    // Guntur (16.3067, 80.4365) to Vijayawada (16.5062, 80.6480) is approx 31-33 km
    const dist = calculateHaversineDistance(16.3067, 80.4365, 16.5062, 80.6480);
    console.log(`  Calculated distance Guntur to Vijayawada: ${dist} km`);
    if (dist >= 30 && dist <= 35) {
      console.log('  ✅ TEST 1A PASSED: Haversine distance calculation is accurate');
    } else {
      throw new Error(`TEST 1A FAILED: Unexpected distance ${dist} km`);
    }

    if (isValidCoordinates(16.3067, 80.4365) && !isValidCoordinates(95, 200)) {
      console.log('  ✅ TEST 1B PASSED: Coordinate validation works properly');
    } else {
      throw new Error('TEST 1B FAILED: Coordinate validation error');
    }

    const mapUrl = buildGoogleMapsUrl(16.3067, 80.4365, 'Test Farmer');
    if (mapUrl.includes('https://www.google.com/maps/search/?api=1&query=16.3067%2C80.4365')) {
      console.log('  ✅ TEST 1C PASSED: Google Maps URL generator works properly');
    } else {
      throw new Error(`TEST 1C FAILED: Unexpected map URL ${mapUrl}`);
    }

    // 2. Setup Test Farmer & Buyer Users
    console.log('\n[TEST 2] Setting up Test Farmer & Buyer Accounts...');
    const testFarmerPhone = `99990${Date.now().toString().slice(-5)}`;
    const testBuyerPhone = `99991${Date.now().toString().slice(-5)}`;

    // Register Farmer
    const regFarmerRes = await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Ramesh Farmer',
        phone: testFarmerPhone,
        password: 'Password123!',
        role: 'FARMER',
        farmerId: 'FARMER98765',
      }),
    });
    const regFarmerData = await regFarmerRes.json();
    if (!regFarmerData.success) {
      throw new Error(`Farmer registration failed: ${JSON.stringify(regFarmerData)}`);
    }
    const farmerToken = regFarmerData.data.token;
    const farmerId = regFarmerData.data.user.id;

    // Register Buyer
    const regBuyerRes = await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Suresh Agri Traders',
        businessName: 'Suresh Agro Foods',
        phone: testBuyerPhone,
        password: 'Password123!',
        role: 'BUYER',
        gstin: '37AAAAA0000A1Z5',
      }),
    });
    const regBuyerData = await regBuyerRes.json();
    if (!regBuyerData.success) {
      throw new Error(`Buyer registration failed: ${JSON.stringify(regBuyerData)}`);
    }
    const buyerToken = regBuyerData.data.token;
    const buyerId = regBuyerData.data.user.id;

    console.log('  ✅ TEST 2 PASSED: Test Farmer and Buyer accounts created');

    // 3. Test Location Update API (Phase 6)
    console.log('\n[TEST 3] Testing Location Update (PUT /api/location)...');
    const updateFarmerLocRes = await fetch(`${baseUrl}/location`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${farmerToken}`,
      },
      body: JSON.stringify({
        latitude: 16.3067,
        longitude: 80.4365,
        address: 'Guntur Rural Farm',
        district: 'Guntur',
        state: 'Andhra Pradesh',
      }),
    });
    const farmerLocData = await updateFarmerLocRes.json();
    if (updateFarmerLocRes.status === 200 && farmerLocData.data.latitude === 16.3067) {
      console.log('  ✅ TEST 3A PASSED: Farmer GPS coordinates updated to [16.3067, 80.4365]');
    } else {
      throw new Error(`TEST 3A FAILED: ${JSON.stringify(farmerLocData)}`);
    }

    const updateBuyerLocRes = await fetch(`${baseUrl}/location`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${buyerToken}`,
      },
      body: JSON.stringify({
        latitude: 16.5062,
        longitude: 80.6480,
        address: 'Vijayawada Market Yard',
        district: 'Krishna',
        state: 'Andhra Pradesh',
      }),
    });
    const buyerLocData = await updateBuyerLocRes.json();
    if (updateBuyerLocRes.status === 200 && buyerLocData.data.latitude === 16.5062) {
      console.log('  ✅ TEST 3B PASSED: Buyer GPS coordinates updated to [16.5062, 80.6480]');
    } else {
      throw new Error(`TEST 3B FAILED: ${JSON.stringify(buyerLocData)}`);
    }

    // 4. Test Get Location API
    console.log('\n[TEST 4] Testing Get My Location (GET /api/location/me)...');
    const getMeLocRes = await fetch(`${baseUrl}/location/me`, {
      headers: { Authorization: `Bearer ${farmerToken}` },
    });
    const getMeData = await getMeLocRes.json();
    if (getMeLocRes.status === 200 && getMeData.data.hasCoordinates && getMeData.data.googleMapsUrl) {
      console.log('  ✅ TEST 4 PASSED: User location retrieved with Google Maps URL:', getMeData.data.googleMapsUrl);
    } else {
      throw new Error(`TEST 4 FAILED: ${JSON.stringify(getMeData)}`);
    }

    // 5. Test Nearby Discovery APIs
    console.log('\n[TEST 5] Testing Geospatial Nearby Discovery APIs...');
    const nearbyFarmersRes = await fetch(`${baseUrl}/location/nearby-farmers?maxDistanceKm=100`, {
      headers: { Authorization: `Bearer ${buyerToken}` },
    });
    const nearbyFarmersData = await nearbyFarmersRes.json();
    if (nearbyFarmersRes.status === 200 && Array.isArray(nearbyFarmersData.data)) {
      console.log(`  ✅ TEST 5A PASSED: Nearby farmers endpoint returned ${nearbyFarmersData.count} farmers within 100km`);
    } else {
      throw new Error(`TEST 5A FAILED: ${JSON.stringify(nearbyFarmersData)}`);
    }

    const nearbyMarketsRes = await fetch(`${baseUrl}/location/nearby-markets?state=Andhra%20Pradesh&limit=5`);
    const nearbyMarketsData = await nearbyMarketsRes.json();
    if (nearbyMarketsRes.status === 200 && nearbyMarketsData.data.length > 0) {
      console.log(`  ✅ TEST 5B PASSED: Nearby APMC markets returned ${nearbyMarketsData.count} markets with Google Maps search links`);
    } else {
      throw new Error(`TEST 5B FAILED: ${JSON.stringify(nearbyMarketsData)}`);
    }

    // 6. Test Farmer Crop Creation & Buyer Requirement Creation
    console.log('\n[TEST 6] Setting up Test Crop and Buyer Requirement...');
    // Verify phone for write operations
    await User.findByIdAndUpdate(farmerId, { phoneVerified: true, verificationStatus: 'VERIFIED' });
    await User.findByIdAndUpdate(buyerId, { phoneVerified: true, verificationStatus: 'VERIFIED' });

    const cropRes = await fetch(`${baseUrl}/crops`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${farmerToken}`,
      },
      body: JSON.stringify({
        commodity: 'Bhindi(Ladies Finger)',
        cropName: 'Fresh Green Bhindi',
        variety: 'Standard',
        grade: 'FAQ',
        quantity: 500,
        quantityUnit: 'kg',
        expectedPrice: 1800, // per quintal
        harvestDate: new Date(Date.now() + 86400000 * 3).toISOString().split('T')[0],
        state: 'Andhra Pradesh',
        district: 'Guntur',
      }),
    });
    const cropData = await cropRes.json();
    const testCropId = (cropData.data.crop?.id || cropData.data._id || cropData.data.id).toString();
    console.log('  Created Test Farmer Crop: Bhindi 500 kg @ ₹1800/Q, ID:', testCropId);

    const reqRes = await fetch(`${baseUrl}/requirements`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${buyerToken}`,
      },
      body: JSON.stringify({
        commodity: 'Bhindi(Ladies Finger)',
        cropName: 'Bhindi',
        quantity: 300,
        quantityUnit: 'kg',
        offeredPrice: 1900, // per quintal
        requiredByDate: new Date(Date.now() + 86400000 * 7).toISOString().split('T')[0],
        state: 'Andhra Pradesh',
        district: 'Krishna',
      }),
    });
    const reqData = await reqRes.json();
    const testReqId = (reqData.data.requirement?.id || reqData.data._id || reqData.data.id).toString();
    console.log('  Created Test Buyer Requirement: Bhindi 300 kg @ ₹1900/Q, ID:', testReqId);
    console.log('  ✅ TEST 6 PASSED: Crop and Requirement successfully registered');

    // 7. Test Farmer Matching API (Phase 7)
    console.log('\n[TEST 7] Testing Farmer Matches Engine (GET /api/matches/farmer)...');
    const fMatchesRes = await fetch(`${baseUrl}/matches/farmer`, {
      headers: { Authorization: `Bearer ${farmerToken}` },
    });
    const fMatchesData = await fMatchesRes.json();
    if (fMatchesRes.status === 200 && fMatchesData.success && fMatchesData.count > 0) {
      const match = fMatchesData.data.find((m) => m.cropId === testCropId && m.requirementId === testReqId);
      if (match) {
        console.log('  ✅ TEST 7 PASSED: Farmer Match Found!');
        console.log('     Commodity            :', match.commodity);
        console.log('     Buyer Business Name  :', match.buyerBusinessName || match.buyerName);
        console.log('     Farmer Available Qty :', `${match.farmerAvailableQty} ${match.farmerUnit}`);
        console.log('     Buyer Required Qty   :', `${match.buyerRequiredQty} ${match.buyerUnit}`);
        console.log('     Farmer Expected Price:', `₹${match.farmerExpectedPrice}/Q`);
        console.log('     Buyer Offered Price  :', `₹${match.buyerExpectedPrice}/Q`);
        console.log('     Market Reference Rate:', `₹${match.marketReferencePrice}/Q (${match.marketSource})`);
        console.log('     Distance             :', `${match.distanceKm} km`);
        console.log('     Match Score          :', `${match.matchScore}% (${match.compatibility})`);
        console.log('     Google Maps URL      :', match.googleMapsUrl);
      } else {
        throw new Error(`TEST 7 FAILED: Target match not found in returned matches: ${JSON.stringify(fMatchesData)}`);
      }
    } else {
      throw new Error(`TEST 7 FAILED: ${JSON.stringify(fMatchesData)}`);
    }

    // 8. Test Buyer Matching API (Phase 7)
    console.log('\n[TEST 8] Testing Buyer Matches Engine (GET /api/matches/buyer)...');
    const bMatchesRes = await fetch(`${baseUrl}/matches/buyer`, {
      headers: { Authorization: `Bearer ${buyerToken}` },
    });
    const bMatchesData = await bMatchesRes.json();
    if (bMatchesRes.status === 200 && bMatchesData.success && bMatchesData.count > 0) {
      const match = bMatchesData.data.find((m) => m.cropId === testCropId && m.requirementId === testReqId);
      if (match) {
        console.log('  ✅ TEST 8 PASSED: Buyer Match Found!');
        console.log('     Matched Farmer Name  :', match.farmerName);
        console.log('     Farmer Available Qty :', `${match.farmerAvailableQty} ${match.farmerUnit}`);
        console.log('     Distance             :', `${match.distanceKm} km`);
        console.log('     Match Score          :', `${match.matchScore}% (${match.compatibility})`);
        console.log('     Google Maps URL      :', match.googleMapsUrl);
      } else {
        throw new Error(`TEST 8 FAILED: Target match not found in returned buyer matches`);
      }
    } else {
      throw new Error(`TEST 8 FAILED: ${JSON.stringify(bMatchesData)}`);
    }

    // 9. Test Single Match Detail API
    console.log('\n[TEST 9] Testing Single Match Detail (GET /api/matches/:id)...');
    const matchId = `FMATCH_${testCropId}_${testReqId}`;
    const matchDetailRes = await fetch(`${baseUrl}/matches/${matchId}`, {
      headers: { Authorization: `Bearer ${farmerToken}` },
    });
    const matchDetailData = await matchDetailRes.json();
    if (matchDetailRes.status === 200 && matchDetailData.success && matchDetailData.data.matchScore > 0) {
      console.log('  ✅ TEST 9 PASSED: Single match detail retrieved with full breakdown:');
      console.log('     Breakdown:', JSON.stringify(matchDetailData.data.breakdown));
    } else {
      throw new Error(`TEST 9 FAILED: ${JSON.stringify(matchDetailData)}`);
    }

    // 10. Clean up test records
    await Crop.findByIdAndDelete(testCropId);
    await BuyerRequirement.findByIdAndDelete(testReqId);
    await User.findByIdAndDelete(farmerId);
    await User.findByIdAndDelete(buyerId);
    console.log('\n[CLEANUP] Temporary test records cleaned up.');

    console.log('\n==================================================');
    console.log('🎉 ALL PHASE 6 & PHASE 7 BACKEND TESTS PASSED!');
    console.log('==================================================\n');
  } finally {
    server.close();
    await mongoose.connection.close();
  }
};

runPhase6And7Tests().catch((err) => {
  console.error('\n❌ PHASE 6 & 7 TEST RUN FAILED:', err);
  process.exit(1);
});
