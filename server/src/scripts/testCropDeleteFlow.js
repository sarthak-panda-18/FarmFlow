const mongoose = require('mongoose');
const User = require('../models/User');

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

async function runCropDeleteTest() {
  console.log('\n=============================================================');
  console.log('🧪 RUNNING CROP DELETE INTEGRATION TESTS');
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
    const farmer1Mobile = '98' + suffix.toString().slice(0, 8);
    const farmer2Mobile = '97' + suffix.toString().slice(0, 8);
    const password = 'Password@123';

    // 1. Register Farmer 1
    const regFarmer1 = await request('/auth/register', {
      method: 'POST',
      body: {
        name: 'Suresh Patil',
        phone: farmer1Mobile,
        password,
        role: 'FARMER',
        farmerId: 'FARM' + suffix.toString().slice(0, 6),
        district: 'Nashik',
        state: 'Maharashtra',
        address: 'Pimpalgaon Farm House',
      },
    });
    assert(regFarmer1.status === 201, 'Farmer 1 registered successfully');
    const farmer1Token = regFarmer1.data.data.token;
    const farmer1Id = regFarmer1.data.data.user.id || regFarmer1.data.data.user._id;

    // 2. Register Farmer 2 (Non-Owner)
    const regFarmer2 = await request('/auth/register', {
      method: 'POST',
      body: {
        name: 'Ramesh Patil',
        phone: farmer2Mobile,
        password,
        role: 'FARMER',
        farmerId: 'FARM' + (suffix + 1).toString().slice(0, 6),
        district: 'Nashik',
        state: 'Maharashtra',
        address: 'Nashik Shindi Road',
      },
    });
    assert(regFarmer2.status === 201, 'Farmer 2 (Non-Owner) registered successfully');
    const farmer2Token = regFarmer2.data.data.token;
    const farmer2Id = regFarmer2.data.data.user.id || regFarmer2.data.data.user._id;

    await User.findByIdAndUpdate(farmer1Id, { phoneVerified: true, verificationStatus: 'VERIFIED', isProfileComplete: true });
    await User.findByIdAndUpdate(farmer2Id, { phoneVerified: true, verificationStatus: 'VERIFIED', isProfileComplete: true });

    // 3. Create Crop Listing for Farmer 1
    const createCropRes = await request('/crops', {
      method: 'POST',
      token: farmer1Token,
      body: {
        commodity: 'Soyabean',
        cropName: 'Yellow Soyabean',
        variety: 'JS 335',
        quantity: 50,
        quantityUnit: 'quintal',
        expectedPrice: 4200,
        harvestDate: new Date(Date.now() + 86400000 * 2).toISOString(),
        state: 'Maharashtra',
        district: 'Nashik',
        market: 'Lasalgaon Mandi',
        description: 'Clean harvested soyabean ready for sale',
      },
    });
    assert(createCropRes.status === 201, 'Crop listing created');
    const cropId = createCropRes.data.data.crop?.id || createCropRes.data.data.crop?._id || createCropRes.data.data.id || createCropRes.data.data._id;
    assert(cropId != null, `Crop created with ID: ${cropId}`);

    // 4. Verify Crop Exists
    const getCropRes = await request(`/crops/${cropId}`, {
      token: farmer1Token,
    });
    const fetchedCommodity = getCropRes.data?.data?.crop?.commodity || getCropRes.data?.data?.commodity;
    assert(fetchedCommodity === 'Soyabean', 'Fetched crop verified');

    // 5. Attempt Delete from Non-Owner (Should fail with 403)
    const nonOwnerDeleteRes = await request(`/crops/${cropId}`, {
      method: 'DELETE',
      token: farmer2Token,
    });
    assert(nonOwnerDeleteRes.status === 403, 'Non-owner deletion rejected with 403 Forbidden');

    // 6. Delete Crop by Owner (Should succeed with 200)
    const deleteRes = await request(`/crops/${cropId}`, {
      method: 'DELETE',
      token: farmer1Token,
    });
    assert(deleteRes.status === 200 && deleteRes.data?.success === true, 'Crop deleted successfully by owner');

    // 7. Verify Crop is Gone (Should return 404)
    const getDeletedRes = await request(`/crops/${cropId}`, {
      token: farmer1Token,
    });
    assert(getDeletedRes.status === 404, 'Deleted crop returns 404 Not Found');

    await mongoose.disconnect();
  } catch (err) {
    console.error('Fatal test error:', err);
    failed++;
  }

  console.log('\n=============================================================');
  console.log(`📊 TEST SUMMARY: Passed: ${passed}, Failed: ${failed}`);
  console.log('=============================================================\n');

  if (failed > 0) process.exit(1);
}

runCropDeleteTest();
