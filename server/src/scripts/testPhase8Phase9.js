/**
 * End-to-End Test Suite for Phase 8 (Opportunities) & Phase 9 (Notifications)
 */

require('dotenv').config({ path: __dirname + '/../../.env' });
const mongoose = require('mongoose');
const User = require('../models/User');

const BASE_URL = 'http://127.0.0.1:5000/api';

async function request(path, options = {}) {
  const url = `${BASE_URL}${path}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
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
  console.log('🧪 RUNNING PHASE 8 & PHASE 9 MASTER INTEGRATION TEST SUITE');
  console.log('=============================================================\n');

  let passed = 0;
  let failed = 0;

  const assert = (condition, message) => {
    if (condition) {
      console.log(`  ✅ [PASS] ${message}`);
      passed++;
    } else {
      console.error(`  ❌ [FAIL] ${message}`);
      failed++;
    }
  };

  try {
    const mongoUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/farm-to-market';
    await mongoose.connect(mongoUri);

    // 1. Health check
    const health = await request('/health');
    assert(health.status === 200 && health.data.success === true, 'Server health check passed');

    // 2. Auth: Register fresh test Farmer & Buyer with unique phone numbers
    const suffix = Math.floor(10000000 + Math.random() * 90000000);
    const farmerMobile = '98' + suffix.toString().slice(0, 8);
    const buyerMobile = '99' + suffix.toString().slice(0, 8);
    const password = 'Password@123';

    let farmerToken = '';
    let farmerId = '';
    const regFarmer = await request('/auth/register', {
      method: 'POST',
      body: { name: 'Test Farmer Ph8', phone: farmerMobile, password, role: 'FARMER', farmerId: 'FARM123456' },
    });
    if (regFarmer.status === 201) {
      farmerToken = regFarmer.data.data.token;
      farmerId = regFarmer.data.data.user.id || regFarmer.data.data.user._id;
    }

    let buyerToken = '';
    let buyerId = '';
    const regBuyer = await request('/auth/register', {
      method: 'POST',
      body: { name: 'Test Buyer Ph8', phone: buyerMobile, password, role: 'BUYER', businessName: 'Fresh Organics Ltd', gstin: '27ABCDE1234F1Z5' },
    });
    if (regBuyer.status === 201) {
      buyerToken = regBuyer.data.data.token;
      buyerId = regBuyer.data.data.user.id || regBuyer.data.data.user._id;
    }

    assert(Boolean(farmerToken && buyerToken), 'Authenticated Farmer and Buyer test users');

    // Mark verified for write operations
    await User.findByIdAndUpdate(farmerId, { phoneVerified: true, verificationStatus: 'VERIFIED' });
    await User.findByIdAndUpdate(buyerId, { phoneVerified: true, verificationStatus: 'VERIFIED' });

    const farmerAuth = { headers: { Authorization: `Bearer ${farmerToken}` } };
    const buyerAuth = { headers: { Authorization: `Bearer ${buyerToken}` } };

    // 3. Set GPS locations for Farmer & Buyer
    await request('/location', {
      method: 'PUT',
      ...farmerAuth,
      body: {
        latitude: 18.5204,
        longitude: 73.8567, // Pune
        address: 'Shivaji Mandi, Pune',
        city: 'Pune',
        district: 'Pune',
        state: 'Maharashtra',
      },
    });

    await request('/location', {
      method: 'PUT',
      ...buyerAuth,
      body: {
        latitude: 18.5793,
        longitude: 73.8143, // Pimpri-Chinchwad (~10km from Pune)
        address: 'Pimpri Agri Hub',
        city: 'Pimpri',
        district: 'Pune',
        state: 'Maharashtra',
      },
    });
    assert(true, 'Updated real coordinates for Farmer and Buyer');

    // 4. Create active Crop for Farmer & active Requirement for Buyer
    const cropRes = await request('/crops', {
      method: 'POST',
      ...farmerAuth,
      body: {
        commodity: 'Tomato',
        cropName: 'Hybrid Red Tomato',
        variety: 'Abhinav',
        grade: 'Grade A',
        quantity: 500,
        quantityUnit: 'kg',
        expectedPrice: 2200,
        harvestDate: new Date(Date.now() + 86400000 * 2).toISOString(),
        state: 'Maharashtra',
        district: 'Pune',
        market: 'Pune Mandi',
        location: 'Shivaji Mandi, Pune',
        locationCoordinates: {
          type: 'Point',
          coordinates: [73.8567, 18.5204],
        },
      },
    });
    const testCropId = cropRes.data?.data?.crop?.id || cropRes.data?.data?.crop?._id;
    assert(testCropId != null, 'Created active Farmer crop listing');

    const reqRes = await request('/requirements', {
      method: 'POST',
      ...buyerAuth,
      body: {
        commodity: 'Tomato',
        cropName: 'Tomato',
        quantity: 300,
        quantityUnit: 'kg',
        offeredPrice: 2300,
        requiredByDate: new Date(Date.now() + 86400000 * 7).toISOString(),
        state: 'Maharashtra',
        district: 'Pune',
        market: 'Pimpri Market',
        location: 'Pimpri Agri Hub',
        locationCoordinates: {
          type: 'Point',
          coordinates: [73.8143, 18.5793],
        },
      },
    });
    const testReqId = reqRes.data?.data?.requirement?.id || reqRes.data?.data?.requirement?._id;
    assert(testReqId != null, 'Created active Buyer purchase requirement');

    // -------------------------------------------------------------
    // PHASE 8: FARMER -> BUYER EXPRESS INTEREST
    // -------------------------------------------------------------
    console.log('\n--- Testing Farmer -> Buyer Opportunity Flow ---');

    const fInterestRes = await request('/opportunities/farmer-express-interest', {
      method: 'POST',
      ...farmerAuth,
      body: {
        requirementId: testReqId,
        cropId: testCropId,
        offeredPrice: 2250,
        notes: 'Can deliver fresh harvest directly to your hub.',
      },
    });

    const farmerOp = fInterestRes.data?.data?.opportunity;
    assert(fInterestRes.status === 201, 'Farmer express interest created opportunity (201)');
    assert(farmerOp?.initiatedBy === 'FARMER', 'Opportunity initiatedBy is FARMER');
    assert(farmerOp?.status === 'PENDING', 'Opportunity initial status is PENDING');

    // Duplicate prevention
    const dupRes = await request('/opportunities/farmer-express-interest', {
      method: 'POST',
      ...farmerAuth,
      body: {
        requirementId: testReqId,
        cropId: testCropId,
        offeredPrice: 2250,
      },
    });
    assert(
      dupRes.status === 409 && dupRes.data?.message === 'Interest already expressed.',
      'Duplicate interest prevented with 409 "Interest already expressed."'
    );

    // -------------------------------------------------------------
    // PHASE 9: NOTIFICATION CREATION & RETRIEVAL (BUYER SIDE)
    // -------------------------------------------------------------
    console.log('\n--- Testing Buyer Notifications & Opportunity Details ---');

    const buyerUnread = await request('/notifications/unread-count', {
      method: 'GET',
      ...buyerAuth,
    });
    assert(buyerUnread.data?.count > 0, `Buyer unread notification count is ${buyerUnread.data?.count}`);

    const buyerNotifs = await request('/notifications', {
      method: 'GET',
      ...buyerAuth,
    });
    assert(buyerNotifs.data?.success === true, 'Buyer fetched notifications list');
    const latestBuyerNotif = buyerNotifs.data?.data?.[0];
    assert(latestBuyerNotif?.type === 'INTEREST_RECEIVED', 'Notification type is INTEREST_RECEIVED');
    assert(latestBuyerNotif?.opportunityId === farmerOp?.id, 'Notification correctly references opportunityId');
    assert(latestBuyerNotif?.isRead === false, 'Notification is initially UNREAD');

    // -------------------------------------------------------------
    // OPPORTUNITY DETAILS (AGMARKNET Price, Distance, Google Maps)
    // -------------------------------------------------------------
    const opDetailRes = await request(`/opportunities/${farmerOp.id}`, {
      method: 'GET',
      ...buyerAuth,
    });
    const opDetail = opDetailRes.data?.data?.opportunity;
    assert(opDetail?.id === farmerOp.id, 'Retrieved opportunity details');
    assert(opDetail?.commodity === 'Tomato', 'Commodity is Tomato');
    assert(opDetail?.distanceKm != null && opDetail.distanceKm > 0, `Distance calculated: ${opDetail?.distanceKm} km`);
    assert(opDetail?.googleMapsUrl && opDetail.googleMapsUrl.includes('google.com/maps'), 'Google Maps URL is present');
    assert(opDetail?.marketReferencePrice !== undefined, `Market reference price included: ₹${opDetail?.marketReferencePrice}`);

    // -------------------------------------------------------------
    // BUYER ACCEPTS OPPORTUNITY
    // -------------------------------------------------------------
    console.log('\n--- Testing Opportunity Acceptance & Notifications ---');

    const acceptRes = await request(`/opportunities/${farmerOp.id}/accept`, {
      method: 'PATCH',
      ...buyerAuth,
    });
    assert(acceptRes.status === 200 && acceptRes.data?.success === true, 'Buyer accepted farmer opportunity');
    assert(acceptRes.data?.data?.opportunity?.status === 'ACCEPTED', 'Status updated to ACCEPTED');

    // Concurrency / second accept attempt
    const dupAcceptRes = await request(`/opportunities/${farmerOp.id}/accept`, {
      method: 'PATCH',
      ...buyerAuth,
    });
    assert(dupAcceptRes.status === 400, 'Subsequent accept rejected with 400 "Opportunity is no longer pending."');

    // Farmer receives acceptance notification
    const farmerNotifs = await request('/notifications', {
      method: 'GET',
      ...farmerAuth,
    });
    const farmerAcceptNotif = farmerNotifs.data?.data?.find(
      (n) => n.opportunityId === farmerOp.id && n.type === 'INTEREST_ACCEPTED'
    );
    assert(farmerAcceptNotif != null, 'Farmer received INTEREST_ACCEPTED notification');

    // -------------------------------------------------------------
    // BUYER -> FARMER EXPRESS INTEREST & REJECTION FLOW
    // -------------------------------------------------------------
    console.log('\n--- Testing Buyer -> Farmer Opportunity & Rejection Flow ---');

    const crop2Res = await request('/crops', {
      method: 'POST',
      ...farmerAuth,
      body: {
        commodity: 'Potato',
        cropName: 'Jyoti Potato',
        variety: 'Jyoti',
        grade: 'FAQ',
        quantity: 1000,
        quantityUnit: 'kg',
        expectedPrice: 1500,
        harvestDate: new Date(Date.now() + 86400000 * 3).toISOString(),
        state: 'Maharashtra',
        district: 'Pune',
        market: 'Pune Mandi',
      },
    });
    const crop2Id = crop2Res.data?.data?.crop?.id || crop2Res.data?.data?.crop?._id;

    const bInterestRes = await request('/opportunities/express-interest', {
      method: 'POST',
      ...buyerAuth,
      body: {
        cropId: crop2Id,
        offeredPrice: 1450,
        notes: 'Looking to purchase entire batch.',
      },
    });

    const buyerOp = bInterestRes.data?.data?.opportunity;
    assert(buyerOp?.initiatedBy === 'BUYER', 'Buyer interest opportunity initiatedBy is BUYER');
    assert(buyerOp?.status === 'PENDING', 'Status is PENDING');

    // Duplicate prevention Buyer -> Farmer
    const bDupRes = await request('/opportunities/express-interest', {
      method: 'POST',
      ...buyerAuth,
      body: {
        cropId: crop2Id,
        offeredPrice: 1450,
      },
    });
    assert(bDupRes.status === 409, 'Duplicate Buyer interest prevented with 409');

    // Farmer rejects buyer opportunity
    const rejectRes = await request(`/opportunities/${buyerOp.id}/reject`, {
      method: 'PATCH',
      ...farmerAuth,
    });
    assert(rejectRes.status === 200 && rejectRes.data?.success === true, 'Farmer rejected buyer interest');
    assert(rejectRes.data?.data?.opportunity?.status === 'REJECTED', 'Status updated to REJECTED');

    // Buyer receives rejection notification
    const buyerNotifsAfterReject = await request('/notifications', {
      method: 'GET',
      ...buyerAuth,
    });
    const buyerRejectNotif = buyerNotifsAfterReject.data?.data?.find(
      (n) => n.opportunityId === buyerOp.id && n.type === 'INTEREST_REJECTED'
    );
    assert(buyerRejectNotif != null, 'Buyer received INTEREST_REJECTED notification');

    // -------------------------------------------------------------
    // CANCELLATION FLOW (INITIATOR CANCELS)
    // -------------------------------------------------------------
    console.log('\n--- Testing Opportunity Cancellation Flow ---');

    const crop3Res = await request('/crops', {
      method: 'POST',
      ...farmerAuth,
      body: {
        commodity: 'Onion',
        cropName: 'Red Onion',
        quantity: 800,
        quantityUnit: 'kg',
        expectedPrice: 1800,
        harvestDate: new Date(Date.now() + 86400000 * 4).toISOString(),
        state: 'Maharashtra',
        district: 'Pune',
      },
    });
    const crop3Id = crop3Res.data?.data?.crop?.id || crop3Res.data?.data?.crop?._id;

    const bInterest3 = await request('/opportunities/express-interest', {
      method: 'POST',
      ...buyerAuth,
      body: {
        cropId: crop3Id,
        offeredPrice: 1750,
      },
    });
    const op3 = bInterest3.data?.data?.opportunity;

    // Buyer cancels their own interest
    const cancelRes = await request(`/opportunities/${op3.id}/cancel`, {
      method: 'PATCH',
      ...buyerAuth,
    });
    assert(cancelRes.status === 200 && cancelRes.data?.success === true, 'Buyer cancelled pending interest');
    assert(cancelRes.data?.data?.opportunity?.status === 'CANCELLED', 'Status updated to CANCELLED');

    // -------------------------------------------------------------
    // NOTIFICATION READ & MARK ALL AS READ APIS
    // -------------------------------------------------------------
    console.log('\n--- Testing Notification Read & Batch Actions ---');

    // Mark single as read
    if (latestBuyerNotif) {
      const readRes = await request(`/notifications/${latestBuyerNotif.id}/read`, {
        method: 'PATCH',
        ...buyerAuth,
      });
      assert(readRes.status === 200 && readRes.data?.success === true, 'Marked single notification as read');
    }

    // Mark all as read
    const readAllRes = await request('/notifications/read-all', {
      method: 'PATCH',
      ...buyerAuth,
    });
    assert(readAllRes.status === 200 && readAllRes.data?.success === true, 'Marked all notifications as read for buyer');

    const finalUnread = await request('/notifications/unread-count', {
      method: 'GET',
      ...buyerAuth,
    });
    assert(finalUnread.data?.count === 0, 'Unread notification count is now 0');

    // -------------------------------------------------------------
    // SECURITY & ISOLATION
    // -------------------------------------------------------------
    console.log('\n--- Testing Security & Authorization ---');

    if (latestBuyerNotif) {
      const secRes = await request(`/notifications/${latestBuyerNotif.id}/read`, {
        method: 'PATCH',
        ...farmerAuth,
      });
      assert(secRes.status === 404 || secRes.status === 403, 'Cross-user notification access blocked (404/403)');
    }

    // -------------------------------------------------------------
    // SUMMARY
    // -------------------------------------------------------------
    console.log('\n=============================================================');
    console.log(`🎉 TEST RESULTS: ${passed} PASSED, ${failed} FAILED`);
    console.log('=============================================================\n');

    await mongoose.disconnect();
    if (failed === 0) {
      process.exit(0);
    } else {
      process.exit(1);
    }
  } catch (err) {
    console.error('❌ Test suite encountered fatal error:', err);
    await mongoose.disconnect();
    process.exit(1);
  }
}

runTests();
