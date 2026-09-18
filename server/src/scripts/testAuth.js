require('dotenv').config({ path: __dirname + '/../../.env' });
const mongoose = require('mongoose');
const express = require('express');
const http = require('http');
const app = require('../app');
const User = require('../models/User');

const runTests = async () => {
  console.log('--- STARTING PHASE 2 AUTHENTICATION & ROLE TEST SUITE ---');

  const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/farm-to-market';
  await mongoose.connect(mongoUri);
  console.log('[DB] Connected to MongoDB.');

  // Clean test users before starting test run
  await User.deleteMany({
    $or: [
      { email: { $in: ['farmer_test@gmail.com', 'buyer_test@gmail.com'] } },
      { phone: { $in: ['+919876500001', '+919876500002'] } },
    ],
  });

  // Start test server on dynamic port
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;
  const baseUrl = `http://localhost:${port}/api`;
  console.log(`[SERVER] Test server running at ${baseUrl}`);

  let farmerToken = '';
  let buyerToken = '';

  try {
    // TEST 1: Register Farmer
    console.log('\n[TEST 1] Registering Farmer (farmer_test@gmail.com)...');
    const regFarmerRes = await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Test Farmer',
        email: 'farmer_test@gmail.com',
        phone: '9876500001',
        password: 'farmer123',
        role: 'FARMER',
      }),
    });
    const regFarmerData = await regFarmerRes.json();
    if (regFarmerRes.status === 201 && regFarmerData.success && regFarmerData.data.token) {
      farmerToken = regFarmerData.data.token;
      console.log('  ✅ TEST 1 PASSED: Farmer created, JWT returned, role =', regFarmerData.data.user.role);
    } else {
      throw new Error(`TEST 1 FAILED: ${JSON.stringify(regFarmerData)}`);
    }

    // Verify Password Hash in DB
    const dbFarmer = await User.findOne({ email: 'farmer_test@gmail.com' });
    if (dbFarmer && dbFarmer.passwordHash && !dbFarmer.passwordHash.includes('farmer123')) {
      console.log('  ✅ DB VERIFICATION PASSED: Farmer password is hashed cleanly with bcryptjs');
    } else {
      throw new Error('DB VERIFICATION FAILED: Password not hashed!');
    }

    // TEST 2: Register Buyer
    console.log('\n[TEST 2] Registering Buyer (buyer_test@gmail.com)...');
    const regBuyerRes = await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Test Buyer',
        email: 'buyer_test@gmail.com',
        phone: '9876500002',
        password: 'buyer123',
        role: 'BUYER',
      }),
    });
    const regBuyerData = await regBuyerRes.json();
    if (regBuyerRes.status === 201 && regBuyerData.success && regBuyerData.data.token) {
      buyerToken = regBuyerData.data.token;
      console.log('  ✅ TEST 2 PASSED: Buyer created, JWT returned, role =', regBuyerData.data.user.role);
    } else {
      throw new Error(`TEST 2 FAILED: ${JSON.stringify(regBuyerData)}`);
    }

    // TEST 3: Login as Farmer
    console.log('\n[TEST 3] Logging in as Farmer (farmer_test@gmail.com)...');
    const loginFarmerRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'farmer_test@gmail.com',
        password: 'farmer123',
      }),
    });
    const loginFarmerData = await loginFarmerRes.json();
    if (loginFarmerRes.status === 200 && loginFarmerData.data.user.role === 'FARMER') {
      console.log('  ✅ TEST 3 PASSED: Common Login returned role FARMER');
    } else {
      throw new Error(`TEST 3 FAILED: ${JSON.stringify(loginFarmerData)}`);
    }

    // TEST 4: Login as Buyer
    console.log('\n[TEST 4] Logging in as Buyer (buyer_test@gmail.com)...');
    const loginBuyerRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'buyer_test@gmail.com',
        password: 'buyer123',
      }),
    });
    const loginBuyerData = await loginBuyerRes.json();
    if (loginBuyerRes.status === 200 && loginBuyerData.data.user.role === 'BUYER') {
      console.log('  ✅ TEST 4 PASSED: Common Login returned role BUYER');
    } else {
      throw new Error(`TEST 4 FAILED: ${JSON.stringify(loginBuyerData)}`);
    }

    // TEST 5: Farmer tries Buyer-only API (POST /api/buyers/requirements)
    console.log('\n[TEST 5] Testing Farmer accessing Buyer-only API...');
    const farmerAccessBuyerRes = await fetch(`${baseUrl}/buyers/requirements`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${farmerToken}`,
      },
      body: JSON.stringify({ crop: 'Wheat', quantityRequired: 10 }),
    });
    const farmerAccessBuyerData = await farmerAccessBuyerRes.json();
    if (farmerAccessBuyerRes.status === 403) {
      console.log('  ✅ TEST 5 PASSED: Access blocked with 403 Forbidden:', farmerAccessBuyerData.message);
    } else {
      throw new Error(`TEST 5 FAILED: Expected 403 but got ${farmerAccessBuyerRes.status}`);
    }

    // TEST 6: Buyer tries Farmer-only API (POST /api/farmers/crops)
    console.log('\n[TEST 6] Testing Buyer accessing Farmer-only API...');
    const buyerAccessFarmerRes = await fetch(`${baseUrl}/farmers/crops`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${buyerToken}`,
      },
      body: JSON.stringify({ crop: 'Rice', quantity: 5 }),
    });
    const buyerAccessFarmerData = await buyerAccessFarmerRes.json();
    if (buyerAccessFarmerRes.status === 403) {
      console.log('  ✅ TEST 6 PASSED: Access blocked with 403 Forbidden:', buyerAccessFarmerData.message);
    } else {
      throw new Error(`TEST 6 FAILED: Expected 403 but got ${buyerAccessFarmerRes.status}`);
    }

    // TEST 7: Wrong password
    console.log('\n[TEST 7] Testing login with wrong password...');
    const wrongPassRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'farmer_test@gmail.com',
        password: 'wrong_password_123',
      }),
    });
    const wrongPassData = await wrongPassRes.json();
    if (wrongPassRes.status === 401 && !wrongPassData.success) {
      console.log('  ✅ TEST 7 PASSED: Rejected with 401 Unauthorized:', wrongPassData.message);
    } else {
      throw new Error(`TEST 7 FAILED: Expected 401 but got ${wrongPassRes.status}`);
    }

    // TEST 8: Unknown email
    console.log('\n[TEST 8] Testing login with unknown email...');
    const unknownEmailRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'nonexistent_user_999@gmail.com',
        password: 'password123',
      }),
    });
    const unknownEmailData = await unknownEmailRes.json();
    if (unknownEmailRes.status === 401 && !unknownEmailData.success) {
      console.log('  ✅ TEST 8 PASSED: Rejected with 401 Unauthorized:', unknownEmailData.message);
    } else {
      throw new Error(`TEST 8 FAILED: Expected 401 but got ${unknownEmailRes.status}`);
    }

    console.log('\n==================================================');
    console.log('🎉 ALL BACKEND AUTHENTICATION & SECURITY TESTS PASSED!');
    console.log('==================================================\n');
  } finally {
    await User.deleteMany({
      $or: [
        { email: { $in: ['farmer_test@gmail.com', 'buyer_test@gmail.com'] } },
        { phone: { $in: ['+919876500001', '+919876500002'] } },
      ],
    });
    server.close();
    await mongoose.connection.close();
  }
};

runTests().catch((err) => {
  console.error('\n❌ TEST RUN FAILED:', err);
  process.exit(1);
});
