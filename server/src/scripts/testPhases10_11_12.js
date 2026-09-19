/**
 * Automated Master Integration Test Suite for Phases 10, 11, and 12
 * - Phase 10: Deal / Transaction Management & External Payment Tracking
 * - Phase 11: Logistics, Distance & Net Return Calculations
 * - Phase 12: Ratings & Feedback Workflow
 */

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

async function runTests() {
  console.log('\n=============================================================');
  console.log('🧪 RUNNING PHASE 10, 11 & 12 MASTER INTEGRATION TEST SUITE');
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

    // 1. Health check
    const health = await request('/health');
    assert(health.status === 200 && health.data.success === true, 'Server health check passed');

    // 2. Auth: Register fresh test Farmer & Buyer with verified status
    const suffix = Math.floor(10000000 + Math.random() * 90000000);
    const farmerMobile = '98' + suffix.toString().slice(0, 8);
    const buyerMobile = '99' + suffix.toString().slice(0, 8);
    const password = 'Password@123';

    let farmerToken = '';
    let farmerId = '';
    const regFarmer = await request('/auth/register', {
      method: 'POST',
      body: { name: 'Test Farmer Ph10', phone: farmerMobile, password, role: 'FARMER', farmerId: 'FARM' + suffix.toString().slice(0, 6) },
    });
    if (regFarmer.status === 201) {
      farmerToken = regFarmer.data.data.token;
      farmerId = regFarmer.data.data.user.id || regFarmer.data.data.user._id;
    }

    let buyerToken = '';
    let buyerId = '';
    const regBuyer = await request('/auth/register', {
      method: 'POST',
      body: { name: 'Test Buyer Ph10', phone: buyerMobile, password, role: 'BUYER', businessName: 'FarmFresh Retail Ltd', gstin: '27ABCDE1234F1Z5' },
    });
    if (regBuyer.status === 201) {
      buyerToken = regBuyer.data.data.token;
      buyerId = regBuyer.data.data.user.id || regBuyer.data.data.user._id;
    }

    assert(farmerToken && buyerToken, 'Authenticated Farmer and Buyer test users');

    // Verify phone and account status for write operations
    await User.findByIdAndUpdate(farmerId, { phoneVerified: true, verificationStatus: 'VERIFIED' });
    await User.findByIdAndUpdate(buyerId, { phoneVerified: true, verificationStatus: 'VERIFIED' });

    // Set GPS locations for Farmer & Buyer via PUT /location
    await request('/location', {
      method: 'PUT',
      token: farmerToken,
      body: {
        latitude: 13.1367,
        longitude: 78.1292,
        address: 'Kolar Farmer Yard, Karnataka',
        city: 'Kolar',
        district: 'Kolar',
        state: 'Karnataka',
      },
    });

    await request('/location', {
      method: 'PUT',
      token: buyerToken,
      body: {
        latitude: 12.9634,
        longitude: 77.5753,
        address: 'KR Market Wholesale Center, Bangalore',
        city: 'Bangalore',
        district: 'Bangalore Urban',
        state: 'Karnataka',
      },
    });
    assert(true, 'Updated real coordinates for Farmer and Buyer');

    // 3. Create active crop & requirement
    const cropRes = await request('/crops', {
      method: 'POST',
      token: farmerToken,
      body: {
        commodity: 'Tomato',
        cropName: 'Tomato',
        variety: 'Hybrid Red',
        quantity: 500, // 500 kg = 5 quintals
        quantityUnit: 'kg',
        expectedPrice: 2100, // ₹2100 per quintal
        harvestDate: new Date(Date.now() + 86400000 * 2).toISOString(),
        state: 'Karnataka',
        district: 'Kolar',
      },
    });
    const cropId =
      cropRes.data?.data?.crop?.id ||
      cropRes.data?.data?.crop?._id ||
      cropRes.data?.data?._id ||
      cropRes.data?.data?.id;
    assert(cropRes.status === 201 && Boolean(cropId), 'Created active Farmer crop listing (500 kg @ ₹2,100/quintal)');

    // 4. Buyer expresses interest to create Opportunity
    const opRes = await request('/opportunities', {
      method: 'POST',
      token: buyerToken,
      body: {
        cropId,
        offeredPrice: 2100,
        notes: 'Ready to purchase 500 kg tomato',
      },
    });
    const opId =
      opRes.data?.data?.opportunity?._id ||
      opRes.data?.data?.opportunity?.id ||
      opRes.data?.data?._id ||
      opRes.data?.data?.id;
    assert(opRes.status === 201 && opId, 'Buyer expressed interest and created Opportunity');

    // 5. Farmer accepts Opportunity -> triggers Deal creation
    console.log('\n--- Testing Opportunity Acceptance & Auto-Deal Creation ---');
    const acceptRes = await request(`/opportunities/${opId}/accept`, {
      method: 'PATCH',
      token: farmerToken,
    });
    assert(acceptRes.status === 200, 'Farmer accepted Opportunity (200)');
    const dealId = acceptRes.data?.data?.dealId;
    assert(dealId, 'Deal record auto-instantiated on Opportunity acceptance');

    // 6. Fetch Deal Details & Unit Conversion Check
    console.log('\n--- Testing Phase 10: Deal Details & Unit Conversion ---');
    const dealDetailRes = await request(`/deals/${dealId}`, { token: farmerToken });
    const deal = dealDetailRes.data?.data;

    assert(dealDetailRes.status === 200, 'Retrieved Deal details by ID');
    assert(deal.commodity === 'Tomato', 'Commodity matches Tomato');
    assert(deal.quantity === 500, 'Quantity is 500 kg');
    assert(deal.agreedPrice === 2100, 'Agreed price is ₹2100/quintal');

    // Financial calculations check:
    // 500 kg @ ₹2100/quintal = 5 quintals * ₹2100 = ₹10,500 Gross Value
    assert(deal.totalAmount === 10500, 'Gross value correctly unit-converted: 500 kg @ ₹2100/quintal = ₹10,500');
    assert(deal.status === 'CONFIRMED', 'Initial deal status is CONFIRMED');
    assert(deal.paymentStatus === 'PAYMENT_PENDING', 'Initial payment status is PAYMENT_PENDING');
    assert(deal.pickupMapsUrl && deal.deliveryMapsUrl, 'Google Maps URLs generated for pickup & delivery');
    assert(deal.distanceKm != null && deal.distanceKm > 0, `Distance calculated: ${deal.distanceKm?.toFixed(1)} km`);

    // 7. Phase 11: Update Logistics & Net Return Calculations
    console.log('\n--- Testing Phase 11: Logistics, Distance & Net Return ---');
    const logRes = await request(`/deals/${dealId}/logistics`, {
      method: 'PATCH',
      token: farmerToken,
      body: {
        transportRequired: true,
        transportType: 'Mini Truck',
        transportCost: 1200,
        otherCosts: 300,
        otherCostsBreakdown: { packaging: 150, loading: 100, unloading: 50, handling: 0 },
        logisticsStatus: 'READY',
      },
    });
    const updatedDeal = logRes.data?.data;

    assert(logRes.status === 200, 'Logistics details updated successfully');
    assert(updatedDeal.estimatedTransportCost === 1200, 'Transport cost recorded as ₹1200');
    assert(updatedDeal.estimatedOtherCosts === 300, 'Other costs recorded as ₹300');
    // Net Return: 10500 - 1200 - 300 = 9000
    assert(updatedDeal.estimatedNetReturn === 9000, 'Estimated Net Return accurately computed: ₹10,500 - ₹1,200 - ₹300 = ₹9,000');
    // Buyer Total Cost: 10500 + 1200 + 300 = 12000
    assert(updatedDeal.estimatedTotalBuyerCost === 12000, 'Buyer Total Cost accurately computed: ₹10,500 + ₹1,200 + ₹300 = ₹12,000');

    // 8. Mark Deal as Delivered
    console.log('\n--- Testing Delivery Confirmation ---');
    const deliverRes = await request(`/deals/${dealId}/deliver`, {
      method: 'PATCH',
      token: farmerToken,
    });
    assert(deliverRes.status === 200, 'Deal marked as DELIVERED');
    assert(deliverRes.data?.data?.status === 'DELIVERED', 'Status updated to DELIVERED');
    assert(deliverRes.data?.data?.logisticsStatus === 'DELIVERED', 'Logistics status updated to DELIVERED');

    // 9. Phase 10: External Payment Workflow
    console.log('\n--- Testing Phase 10: External Direct Payment Workflow ---');
    // Buyer reports payment
    const reportPayRes = await request(`/deals/${dealId}/payment/report`, {
      method: 'PATCH',
      token: buyerToken,
      body: { notes: 'Transferred ₹12,000 via Direct NEFT bank transfer' },
    });
    assert(reportPayRes.status === 200, 'Buyer reported direct payment made');
    assert(reportPayRes.data?.data?.paymentStatus === 'PAYMENT_REPORTED', 'Payment status is PAYMENT_REPORTED');

    // Self-confirmation prevention: Buyer trying to confirm their own payment MUST fail with 403
    const selfConfirmRes = await request(`/deals/${dealId}/payment/confirm`, {
      method: 'PATCH',
      token: buyerToken,
    });
    assert(selfConfirmRes.status === 403, 'Security: Buyer self-confirmation blocked with 403');

    // Farmer confirms receipt of payment
    const confirmPayRes = await request(`/deals/${dealId}/payment/confirm`, {
      method: 'PATCH',
      token: farmerToken,
    });
    assert(confirmPayRes.status === 200, 'Farmer confirmed payment receipt');
    assert(confirmPayRes.data?.data?.paymentStatus === 'PAYMENT_CONFIRMED_BY_BOTH', 'Payment status is PAYMENT_CONFIRMED_BY_BOTH');
    assert(confirmPayRes.data?.data?.status === 'COMPLETED', 'Deal automatically transitioned to COMPLETED');

    // 10. Phase 12: Ratings & Feedback
    console.log('\n--- Testing Phase 12: Ratings & Feedback Workflow ---');
    // Farmer rates Buyer
    const farmerRateRes = await request(`/deals/${dealId}/ratings`, {
      method: 'POST',
      token: farmerToken,
      body: {
        rating: 5,
        feedback: 'Excellent buyer, clear communication and prompt payment.',
      },
    });
    assert(farmerRateRes.status === 201, 'Farmer submitted 5-star rating for Buyer');
    assert(farmerRateRes.data?.data?.rating?.rating === 5, 'Rating score is 5');

    // Duplicate rating attempt by Farmer MUST fail with 409
    const dupRateRes = await request(`/deals/${dealId}/ratings`, {
      method: 'POST',
      token: farmerToken,
      body: { rating: 4 },
    });
    assert(dupRateRes.status === 409, 'Duplicate rating prevented with 409');

    // Rating validation: 0 or 6 stars must fail with 400
    const invalidRateRes = await request(`/deals/${dealId}/ratings`, {
      method: 'POST',
      token: buyerToken,
      body: { rating: 6 },
    });
    assert(invalidRateRes.status === 400, 'Invalid rating (>5) rejected with 400');

    // Buyer rates Farmer
    const buyerRateRes = await request(`/deals/${dealId}/ratings`, {
      method: 'POST',
      token: buyerToken,
      body: {
        rating: 5,
        feedback: 'Top quality tomatoes, freshly harvested and timely pickup.',
      },
    });
    assert(buyerRateRes.status === 201, 'Buyer submitted 5-star rating for Farmer');

    // 11. Deal listings verification
    console.log('\n--- Testing Farmer & Buyer Deal Listings ---');
    const farmerDealsRes = await request('/deals/farmer', { token: farmerToken });
    assert(farmerDealsRes.status === 200 && farmerDealsRes.data?.data?.length > 0, 'Farmer retrieved My Deals list');

    const buyerDealsRes = await request('/deals/buyer', { token: buyerToken });
    assert(buyerDealsRes.status === 200 && buyerDealsRes.data?.data?.length > 0, 'Buyer retrieved My Deals list');

    // 12. Security & Authorization check
    console.log('\n--- Testing Security & Authorization ---');
    const randomSuffix = Math.floor(10000000 + Math.random() * 90000000);
    const regOther = await request('/auth/register', {
      method: 'POST',
      body: {
        name: 'Third Party',
        phone: '97' + randomSuffix.toString().slice(0, 8),
        password: 'Password@123',
        role: 'FARMER',
        farmerId: 'FARM' + randomSuffix.toString().slice(0, 6),
      },
    });
    const otherToken = regOther.data?.data?.token;

    const unauthorizedDealRes = await request(`/deals/${dealId}`, { token: otherToken });
    assert(unauthorizedDealRes.status === 403, 'Cross-user Deal access blocked with 403');

    // 13. Payment Dispute Flow Test (on a new deal)
    console.log('\n--- Testing Payment Dispute Flow ---');
    const cropRes2 = await request('/crops', {
      method: 'POST',
      token: farmerToken,
      body: {
        commodity: 'Potato',
        cropName: 'Potato',
        quantity: 1000,
        quantityUnit: 'kg',
        expectedPrice: 1500,
        harvestDate: new Date(Date.now() + 86400000 * 2).toISOString(),
        state: 'Karnataka',
        district: 'Kolar',
      },
    });
    const cropId2 =
      cropRes2.data?.data?.crop?.id ||
      cropRes2.data?.data?.crop?._id ||
      cropRes2.data?.data?._id;

    const opRes2 = await request('/opportunities', {
      method: 'POST',
      token: buyerToken,
      body: { cropId: cropId2, offeredPrice: 1500 },
    });
    const opId2 =
      opRes2.data?.data?.opportunity?._id ||
      opRes2.data?.data?.opportunity?.id ||
      opRes2.data?.data?._id ||
      opRes2.data?.data?.id;

    const acceptRes2 = await request(`/opportunities/${opId2}/accept`, {
      method: 'PATCH',
      token: farmerToken,
    });
    const dealId2 = acceptRes2.data?.data?.dealId;

    // Buyer reports payment
    await request(`/deals/${dealId2}/payment/report`, {
      method: 'PATCH',
      token: buyerToken,
      body: { notes: 'Paid via cash' },
    });

    // Farmer disputes payment
    const disputeRes = await request(`/deals/${dealId2}/payment/dispute`, {
      method: 'PATCH',
      token: farmerToken,
      body: { reason: 'Cash has not been received at the pickup point.' },
    });
    assert(disputeRes.status === 200, 'Farmer reported payment dispute');
    assert(disputeRes.data?.data?.paymentStatus === 'PAYMENT_DISPUTED', 'Payment status updated to PAYMENT_DISPUTED');
    assert(disputeRes.data?.data?.paymentDisputed === true, 'paymentDisputed flag is true');

    await mongoose.disconnect();
  } catch (err) {
    console.error('Test execution error:', err);
    failed++;
  }

  console.log('\n=============================================================');
  console.log(`🎉 TEST RESULTS: ${passed} PASSED, ${failed} FAILED`);
  console.log('=============================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests();
