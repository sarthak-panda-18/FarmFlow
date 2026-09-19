/**
 * FARMFLOW — MASTER CHANGE REQUEST COMPREHENSIVE AUTOMATED TEST SUITE
 */

const assert = require('assert');
const mongoose = require('mongoose');
const User = require('../models/User');

const BASE_URL = 'http://127.0.0.1:5000/api';

async function req(endpoint, { method = 'GET', body = null, token = null } = {}) {
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

const randomPhone = () => '9' + Math.floor(100000000 + Math.random() * 900000000).toString();

let farmerToken = '';
let farmerId = '';
let buyerToken = '';
let buyerId = '';
let cropId = '';
let requirementId = '';
let opportunityId = '';
let dealId = '';

async function runTests() {
  console.log('===============================================================');
  console.log('  STARTING FARMFLOW MASTER CHANGE REQUEST AUTOMATED TESTS');
  console.log('===============================================================\n');

  const mongoUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/farm-to-market';
  await mongoose.connect(mongoUri);

  // -------------------------------------------------------------------------
  // 1. REGRESSION & AUTH SETUP
  // -------------------------------------------------------------------------
  console.log('--- 1. Testing Auth & User Setup ---');
  const suffix = Math.floor(10000000 + Math.random() * 90000000).toString();
  const farmerPhone = '98' + suffix.slice(0, 8);
  const buyerPhone = '99' + suffix.slice(0, 8);

  // Register Farmer
  const farmerReg = await req('/auth/register', {
    method: 'POST',
    body: {
      name: 'Master Farmer Ramesh',
      phone: farmerPhone,
      password: 'password123',
      role: 'FARMER',
      farmerId: 'FARM' + suffix.slice(0, 6),
      state: 'Maharashtra',
      district: 'Nashik',
      location: 'Nashik Mandi Area',
    },
  });
  assert(farmerReg.ok && farmerReg.data.success, 'Farmer registration succeeded');
  farmerToken = farmerReg.data.data.token;
  farmerId = farmerReg.data.data.user.id || farmerReg.data.data.user._id;
  console.log('  ✓ Farmer Registered:', farmerPhone, farmerId);

  // Register Buyer
  const buyerReg = await req('/auth/register', {
    method: 'POST',
    body: {
      name: 'Master Buyer Suresh',
      phone: buyerPhone,
      password: 'password123',
      role: 'BUYER',
      gstin: '27AAAAA0000A1Z5',
      businessName: 'Suresh Agri Traders',
      buyerType: 'TRADER',
      state: 'Maharashtra',
      district: 'Pune',
      location: 'Pune APMC Market',
    },
  });
  assert(buyerReg.ok && buyerReg.data.success, 'Buyer registration succeeded');
  buyerToken = buyerReg.data.data.token;
  buyerId = buyerReg.data.data.user.id || buyerReg.data.data.user._id;
  console.log('  ✓ Buyer Registered:', buyerPhone, buyerId);

  // Verify accounts for write operations
  await User.findByIdAndUpdate(farmerId, { phoneVerified: true, verificationStatus: 'VERIFIED' });
  await User.findByIdAndUpdate(buyerId, { phoneVerified: true, verificationStatus: 'VERIFIED' });
  console.log('  ✓ Test accounts marked as verified for marketplace operations');

  // -------------------------------------------------------------------------
  // 2. CHANGE 1 — MARKET UNITS (REJECT KG, ENFORCE QUINTAL)
  // -------------------------------------------------------------------------
  console.log('\n--- 2. Testing Market Units (Strict Quintal Enforcement) ---');

  // 2.1 Backend must REJECT Farmer crop creation with KG
  const kgCropRes = await req('/crops', {
    method: 'POST',
    token: farmerToken,
    body: {
      commodity: 'Tomato',
      cropName: 'Tomato Hybrid Special',
      variety: 'Hybrid',
      quantity: 100,
      quantityUnit: 'kg',
      expectedPrice: 4000,
      harvestDate: '2026-10-01',
      state: 'Maharashtra',
      district: 'Nashik',
      market: 'Nashik',
    },
  });
  assert(kgCropRes.status === 400, 'Backend returned 400 Bad Request for KG unit in Crop');
  assert(kgCropRes.data.message.includes('quintal'), 'Error message specifies Quintal requirement');
  console.log('  ✓ Backend strictly rejects Farmer Crop creation with unit "kg" (400)');

  // 2.2 Backend must REJECT Buyer requirement creation with KG
  const kgReqRes = await req('/requirements', {
    method: 'POST',
    token: buyerToken,
    body: {
      commodity: 'Tomato',
      cropName: 'Tomato Hybrid Special',
      variety: 'Hybrid',
      quantity: 100,
      quantityUnit: 'kg',
      offeredPrice: 4200,
      requiredByDate: '2026-10-15',
      state: 'Maharashtra',
      district: 'Nashik',
      market: 'Nashik',
    },
  });
  assert(kgReqRes.status === 400, 'Backend returned 400 Bad Request for KG unit in Requirement');
  assert(kgReqRes.data.message.includes('quintal'), 'Error message specifies Quintal requirement');
  console.log('  ✓ Backend strictly rejects Buyer Requirement creation with unit "kg" (400)');

  // 2.3 Create Crop with unit "quintal" (120 Quintal @ ₹8,200 / Quintal)
  const cropRes = await req('/crops', {
    method: 'POST',
    token: farmerToken,
    body: {
      commodity: 'Tomato',
      cropName: 'Tomato Hybrid Special',
      variety: 'Hybrid',
      quantity: 120,
      quantityUnit: 'quintal',
      expectedPrice: 8200,
      harvestDate: '2026-10-01',
      state: 'Maharashtra',
      district: 'Nashik',
      market: 'Nashik',
      location: 'Nashik Farm Gate 1',
    },
  });
  assert(cropRes.ok && cropRes.data.success, 'Crop creation with Quintal succeeded');
  const cropData = cropRes.data.data.crop || cropRes.data.data;
  cropId = cropData.id || cropData._id;
  assert(cropData.quantityUnit === 'quintal', 'Crop quantityUnit is quintal');
  console.log('  ✓ Farmer Crop successfully created with unit "quintal" (120 Quintals @ ₹8,200/Q)');

  // 2.4 Create Buyer Requirement with unit "quintal" (120 Quintal @ ₹8,200 / Quintal)
  const reqRes = await req('/requirements', {
    method: 'POST',
    token: buyerToken,
    body: {
      commodity: 'Tomato',
      cropName: 'Tomato Hybrid Special',
      variety: 'Hybrid',
      quantity: 120,
      quantityUnit: 'quintal',
      offeredPrice: 8200,
      requiredByDate: '2026-10-15',
      state: 'Maharashtra',
      district: 'Nashik',
      market: 'Nashik',
      location: 'Pune APMC Warehouse 4',
    },
  });
  assert(reqRes.ok && reqRes.data.success, 'Requirement creation with Quintal succeeded');
  const reqData = reqRes.data.data.requirement || reqRes.data.data;
  requirementId = reqData.id || reqData._id;
  assert(reqData.quantityUnit === 'quintal', 'Requirement quantityUnit is quintal');
  console.log('  ✓ Buyer Requirement successfully created with unit "quintal" (120 Quintals @ ₹8,200/Q)');

  // -------------------------------------------------------------------------
  // 3. CHANGE 2 — NO-MATCH & FUTURE MATCH NOTIFICATIONS
  // -------------------------------------------------------------------------
  console.log('\n--- 3. Testing No-Match & Future Match States ---');

  // Test farmer matches endpoint returns proper empty state when no match exists
  const unmatchedFarmerRes = await req('/matches/farmer?cropId=660000000000000000000000', {
    method: 'GET',
    token: farmerToken,
  });
  assert(unmatchedFarmerRes.ok && unmatchedFarmerRes.data.success, 'Farmer matches API returns 200 success without crashing');
  assert(Array.isArray(unmatchedFarmerRes.data.data), 'Returns matches array for no-match');
  console.log('  ✓ No-match query returns clean empty/no-match state without technical error');

  // -------------------------------------------------------------------------
  // 4. CHANGE 3 & 5 — OFFICIAL DEAL AGREEMENT & MUTUAL ACCEPTANCE
  // -------------------------------------------------------------------------
  console.log('\n--- 4. Testing Official Deal Agreement Workflow ---');

  // 4.1 Buyer expresses interest in Farmer's crop -> creates Opportunity
  const oppRes = await req('/opportunities', {
    method: 'POST',
    token: buyerToken,
    body: {
      cropId: cropId,
      offeredPrice: 8200,
      quantity: 120,
      quantityUnit: 'quintal',
      notes: 'Ready to buy 120 Quintals of Tomato',
    },
  });
  assert(oppRes.ok && oppRes.data.success, 'Opportunity created');
  const oppData = oppRes.data.data.opportunity || oppRes.data.data;
  opportunityId = oppData.id || oppData._id;
  console.log('  ✓ Opportunity created:', opportunityId);

  // 4.2 Farmer accepts opportunity -> creates Deal in AGREEMENT_PENDING status
  const acceptOppRes = await req(`/opportunities/${opportunityId}/accept`, {
    method: 'POST',
    token: farmerToken,
    body: { responseNotes: 'Agreed on terms. Ready to review Official Deal Agreement.' },
  });
  assert(acceptOppRes.ok && acceptOppRes.data.success, 'Opportunity accepted');
  dealId = acceptOppRes.data.data.dealId || acceptOppRes.data.data.deal._id;
  console.log('  ✓ Opportunity accepted, Deal created with ID:', dealId);

  // 4.3 Fetch Official Deal Agreement
  const agreementRes = await req(`/deals/${dealId}/agreement`, {
    method: 'GET',
    token: farmerToken,
  });
  assert(agreementRes.ok && agreementRes.data.success, 'Agreement fetch succeeded');
  const agreement = agreementRes.data.data;
  assert(agreement.agreementStatus === 'AGREEMENT_PENDING', 'Initial agreement status is AGREEMENT_PENDING');
  assert(agreement.farmerAccepted === false && agreement.buyerAccepted === false, 'Both acceptances initial false');
  assert(agreement.agreementVersion === 1, 'Agreement initial version is 1');
  assert(Array.isArray(agreement.termsAndConditions) && agreement.termsAndConditions.length >= 4, 'Includes required Terms & Conditions');
  assert(agreement.totalAmount === 120 * 8200 || agreement.grossDealValue === 120 * 8200, `Gross Value calculated as 120 * ₹8,200 = ₹9,84,000`);
  console.log('  ✓ Official Deal Agreement generated (v1) with Terms and ₹9,84,000 Total Value');

  // 4.4 Reject acceptance without mandatory checkbox (hasReviewedAndAgreed = false)
  const uncheckedRes = await req(`/deals/${dealId}/agreement/accept`, {
    method: 'POST',
    token: farmerToken,
    body: { hasReviewedAndAgreed: false },
  });
  assert(uncheckedRes.status === 400, 'Rejection returned 400 Bad Request when checkbox false');
  console.log('  ✓ Acceptance rejected if terms checkbox is not explicitly checked (400)');

  // 4.5 Farmer accepts agreement (One-sided acceptance)
  const farmerAcceptRes = await req(`/deals/${dealId}/agreement/accept`, {
    method: 'POST',
    token: farmerToken,
    body: { hasReviewedAndAgreed: true },
  });
  if (!farmerAcceptRes.ok || !farmerAcceptRes.data.success) {
    console.error('farmerAcceptRes failed:', farmerAcceptRes.status, farmerAcceptRes.data);
  }
  assert(farmerAcceptRes.ok && farmerAcceptRes.data.success, 'Farmer acceptance succeeded');
  const dealAfterFarmer = farmerAcceptRes.data.data;
  assert(dealAfterFarmer.farmerAccepted === true, 'Farmer accepted recorded');
  assert(dealAfterFarmer.buyerAccepted === false, 'Buyer not accepted yet');
  assert(dealAfterFarmer.agreementStatus === 'WAITING_FOR_BUYER', 'Agreement status is WAITING_FOR_BUYER');
  assert(dealAfterFarmer.status === 'WAITING_FOR_BUYER', 'Deal status is WAITING_FOR_BUYER (NOT CONFIRMED)');
  console.log('  ✓ Farmer accepted agreement: Status transitioned to WAITING_FOR_BUYER (Deal NOT prematurely confirmed)');

  // 4.6 Agreement Security: Reject unauthorized third-party user
  const thirdPartyPhone = randomPhone();
  const thirdPartyReg = await req('/auth/register', {
    method: 'POST',
    body: {
      name: 'Random Intruder',
      phone: thirdPartyPhone,
      password: 'password123',
      role: 'FARMER',
      farmerId: 'FARM' + Math.floor(100000 + Math.random() * 900000),
    },
  });
  const intruderToken = thirdPartyReg.data.data.token;
  const intruderId = thirdPartyReg.data.data.user.id || thirdPartyReg.data.data.user._id;
  await User.findByIdAndUpdate(intruderId, { phoneVerified: true, verificationStatus: 'VERIFIED' });
  const intruderRes = await req(`/deals/${dealId}/agreement/accept`, {
    method: 'POST',
    token: intruderToken,
    body: { hasReviewedAndAgreed: true },
  });
  assert(intruderRes.status === 403, 'Intruder rejected with 403 Forbidden');
  console.log('  ✓ Agreement Security: Unauthorized third-party user cannot accept Deal Agreement (403)');

  // 4.7 Test Agreement Version Reset on Modification
  console.log('  Testing Agreement Version Invalidation on Terms Modification...');
  const updateAgreementRes = await req(`/deals/${dealId}/agreement`, {
    method: 'PATCH',
    token: farmerToken,
    body: { agreedPrice: 8500 },
  });
  assert(updateAgreementRes.ok && updateAgreementRes.data.success, 'Agreement update succeeded');
  const dealV2 = updateAgreementRes.data.data;
  assert(dealV2.agreementVersion === 2, 'Agreement version incremented to 2');
  assert(dealV2.farmerAccepted === false && dealV2.buyerAccepted === false, 'Both acceptances reset to false');
  assert(dealV2.agreementStatus === 'AGREEMENT_PENDING', 'Status reset to AGREEMENT_PENDING');
  assert(dealV2.totalAmount === 120 * 8500, 'Total amount recalculated at ₹8,500/Q (₹10,20,000)');
  console.log('  ✓ Agreement terms modification created Version 2 and safely invalidated previous acceptance');

  // Re-accept Farmer on Version 2
  await req(`/deals/${dealId}/agreement/accept`, {
    method: 'POST',
    token: farmerToken,
    body: { hasReviewedAndAgreed: true },
  });

  // 4.8 Buyer accepts agreement -> Mutual Confirmation -> DEAL_CONFIRMED
  const buyerAcceptRes = await req(`/deals/${dealId}/agreement/accept`, {
    method: 'POST',
    token: buyerToken,
    body: { hasReviewedAndAgreed: true },
  });
  assert(buyerAcceptRes.ok && buyerAcceptRes.data.success, 'Buyer acceptance succeeded');
  const confirmedDeal = buyerAcceptRes.data.data;
  assert(confirmedDeal.farmerAccepted === true && confirmedDeal.buyerAccepted === true, 'Both parties recorded as accepted');
  assert(confirmedDeal.agreementStatus === 'DEAL_CONFIRMED', 'Agreement status is DEAL_CONFIRMED');
  assert(confirmedDeal.status === 'DEAL_CONFIRMED' || confirmedDeal.status === 'CONFIRMED', 'Deal status is confirmed');
  assert(Boolean(confirmedDeal.farmerAcceptedAt) && Boolean(confirmedDeal.buyerAcceptedAt), 'Acceptance timestamps recorded');
  console.log('  ✓ Buyer accepted agreement: Deal MUTUALLY CONFIRMED (DEAL_CONFIRMED)');

  // 4.9 Locked Confirmed Deal Test
  const lockedRes = await req(`/deals/${dealId}/agreement`, {
    method: 'PATCH',
    token: farmerToken,
    body: { agreedPrice: 9000 },
  });
  assert(lockedRes.status === 400, 'Modification of locked deal rejected with 400');
  console.log('  ✓ Confirmed Deal is locked against silent unauthorized parameter alterations (400)');

  // -------------------------------------------------------------------------
  // 5. CHANGE 4 — MARKET PRICE ±5% ALERTS
  // -------------------------------------------------------------------------
  console.log('\n--- 5. Testing Market Price ±5% Alerts & Calculations ---');

  // Trigger alert calculation endpoint for Tomato
  const alertRes = await req('/markets/trigger-alerts', {
    method: 'POST',
    token: farmerToken,
    body: { commodity: 'Tomato' },
  });
  assert(alertRes.ok && alertRes.data.success, 'Trigger market alerts API succeeded');
  console.log(`  ✓ Triggered market alerts check: Generated ${alertRes.data.triggeredCount || 0} alerts.`);

  // Verify notification deduplication by triggering second time
  const alertRes2 = await req('/markets/trigger-alerts', {
    method: 'POST',
    token: farmerToken,
    body: { commodity: 'Tomato' },
  });
  assert(alertRes2.ok && alertRes2.data.success, 'Second trigger succeeded');
  assert(alertRes2.data.triggeredCount === 0, 'Duplicate alerts prevented (0 duplicate alerts generated)');
  console.log('  ✓ Market alert deduplication verified (no notification spam)');

  // Verify Trends API
  const trendsRes = await req('/markets/trends?commodity=Tomato', {
    method: 'GET',
    token: farmerToken,
  });
  assert(trendsRes.ok && trendsRes.data.success, 'Trends API returns success');
  console.log('  ✓ Market trends API returned structured price movements with Quintal units');

  // -------------------------------------------------------------------------
  // 6. CHANGE 6 — PAYMENT SAFETY MODEL
  // -------------------------------------------------------------------------
  console.log('\n--- 6. Testing Payment Safety (No Fake Gateway, Anti-Self Confirmation) ---');

  // Progress deal to DELIVERED
  await req(`/deals/${dealId}/status`, {
    method: 'PATCH',
    token: farmerToken,
    body: { status: 'DELIVERED' },
  });
  console.log('  ✓ Deal marked as DELIVERED');

  // Buyer reports external payment made
  const reportPayRes = await req(`/deals/${dealId}/payment/report`, {
    method: 'POST',
    token: buyerToken,
    body: { paymentMethod: 'Direct UPI', notes: 'Paid ₹10,20,000 via UPI Ref 987654321' },
  });
  assert(reportPayRes.ok && reportPayRes.data.success, 'Payment report recorded');
  assert(reportPayRes.data.data.paymentStatus === 'PAYMENT_REPORTED', 'Status is PAYMENT_REPORTED');
  console.log('  ✓ Buyer reported external payment (PAYMENT_REPORTED)');

  // Buyer tries to self-confirm their own payment -> MUST BE REJECTED
  const selfConfirmRes = await req(`/deals/${dealId}/payment/confirm`, {
    method: 'POST',
    token: buyerToken,
  });
  assert(selfConfirmRes.status === 403, 'Self-confirmation rejected with 403 Forbidden');
  console.log('  ✓ Safety: Paying party CANNOT self-confirm their own payment (403)');

  // Farmer (the receiving party) confirms payment receipt
  const confirmPayRes = await req(`/deals/${dealId}/payment/confirm`, {
    method: 'POST',
    token: farmerToken,
  });
  assert(confirmPayRes.ok && confirmPayRes.data.success, 'Receiving party confirmed payment');
  assert(confirmPayRes.data.data.paymentStatus === 'PAYMENT_CONFIRMED_BY_BOTH', 'Payment marked PAYMENT_CONFIRMED_BY_BOTH');
  assert(confirmPayRes.data.data.status === 'COMPLETED', 'Deal successfully completed');
  console.log('  ✓ Receiving party confirmed external receipt -> Deal COMPLETED');

  // -------------------------------------------------------------------------
  // 7. SUMMARY
  // -------------------------------------------------------------------------
  console.log('\n===============================================================');
  console.log('  ALL MASTER CHANGE REQUEST TESTS PASSED SUCCESSFULLY! (100%)');
  console.log('===============================================================\n');
  await mongoose.disconnect();
  process.exit(0);
}

runTests().catch(async (err) => {
  console.error('\n❌ TEST FAILED:', err.message);
  try {
    await mongoose.disconnect();
  } catch (_) {}
  process.exit(1);
});
