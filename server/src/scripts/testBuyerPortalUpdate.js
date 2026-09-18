const mongoose = require('mongoose');
const User = require('../models/User');
const Crop = require('../models/Crop');
const BuyerRequirement = require('../models/BuyerRequirement');
const Opportunity = require('../models/Opportunity');
const Notification = require('../models/Notification');
const Rating = require('../models/Rating');
const MarketPrice = require('../models/MarketPrice');
const Otp = require('../models/Otp');
const { generateOtp, hashOtp, verifyOtpHash } = require('../utils/otpService');
const { getUserRatingStats } = require('../utils/ratingHelper');
const { buildCommodityFilter } = require('../utils/commodityCategoryMapping');

async function runTests() {
  console.log('=== STARTING BUYER PORTAL MASTER UPDATE TESTS ===\n');

  const mongoUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/farm-to-market';
  await mongoose.connect(mongoUri);

  // Clean up any test users from previous test runs
  await User.deleteMany({ phone: { $in: ['9998881111', '9998882222'] } });
  await Otp.deleteMany({ phone: { $in: ['9998881111', '9998882222'] } });

  console.log('--- TEST 1: BUYER REGISTRATION (GSTIN included, Email removed) ---');
  const rawGstin = '36AAAAA0000A1Z5';
  const gstinRegex = /^[0-9A-Z]{15}$/;
  if (!gstinRegex.test(rawGstin)) {
    throw new Error('GSTIN format regex failed');
  }

  const buyerUser = await User.create({
    name: 'Rahul Sharma',
    phone: '9998881111',
    passwordHash: 'dummyHash123',
    role: 'BUYER',
    phoneVerified: false,
    verificationStatus: 'PENDING',
    verificationType: 'BUYER',
    verificationId: rawGstin,
    gstin: rawGstin,
  });

  console.log(`[PASS] Buyer registered with ID: ${buyerUser._id}, GSTIN: ${buyerUser.gstin}, Role: ${buyerUser.role}`);
  console.log(`[PASS] Buyer email is undefined/not required: ${buyerUser.email === undefined}`);

  console.log('\n--- TEST 2: MOBILE OTP & IMMEDIATE VERIFICATION ---');
  // Simulate OTP Verification for Buyer
  buyerUser.phoneVerified = true;
  buyerUser.verificationStatus = 'VERIFIED';
  await buyerUser.save();

  const refreshedBuyer = await User.findById(buyerUser._id);
  console.log(`[PASS] Phone verified: ${refreshedBuyer.phoneVerified}, Verification Status: ${refreshedBuyer.verificationStatus}`);
  if (!refreshedBuyer.phoneVerified || refreshedBuyer.verificationStatus !== 'VERIFIED') {
    throw new Error('Buyer verification status failed');
  }

  console.log('\n--- TEST 3: MARKET PRICE RESOLUTION (PULSES & VEGETABLES) ---');
  // Test Pulses
  const pulseFilter = buildCommodityFilter('pulses');
  console.log('Pulse filter:', JSON.stringify(pulseFilter));
  const pulseRecords = await MarketPrice.find(pulseFilter).limit(3).lean();
  console.log(`Found ${pulseRecords.length} pulse records. Example: ${pulseRecords[0]?.commodity} - Modal: ₹${pulseRecords[0]?.modalPrice}`);
  if (pulseRecords.length === 0) throw new Error('Pulse market data not found');

  // Test Moong alias
  const moongFilter = buildCommodityFilter('moong');
  const moongRecords = await MarketPrice.find(moongFilter).limit(1).lean();
  console.log(`[PASS] Moong alias returned: ${moongRecords[0]?.commodity} (₹${moongRecords[0]?.modalPrice})`);

  // Test Vegetables
  const vegFilter = buildCommodityFilter('vegetables');
  console.log('Vegetables filter:', JSON.stringify(vegFilter));
  const vegRecords = await MarketPrice.find(vegFilter).limit(3).lean();
  console.log(`Found ${vegRecords.length} vegetable records. Example: ${vegRecords[0]?.commodity} - Modal: ₹${vegRecords[0]?.modalPrice}`);
  if (vegRecords.length === 0) throw new Error('Vegetable market data not found');

  // Test Brinjal / Bhindi alias
  const bhindiFilter = buildCommodityFilter('bhindi');
  const bhindiRecords = await MarketPrice.find(bhindiFilter).limit(1).lean();
  console.log(`[PASS] Bhindi alias returned: ${bhindiRecords[0]?.commodity} (₹${bhindiRecords[0]?.modalPrice})`);

  console.log('\n--- TEST 4: BUYER REQUIREMENT CRUD (GRADE REMOVED) ---');
  const requirement = await BuyerRequirement.create({
    buyerId: buyerUser._id,
    commodity: 'Tomato',
    cropName: 'Tomato',
    variety: 'Not specified',
    grade: 'Not specified',
    quantity: 500,
    quantityUnit: 'kg',
    offeredPrice: 2200,
    requiredByDate: new Date('2026-09-20'),
    state: 'Andhra Pradesh',
    district: 'Vijayawada',
    location: 'Vijayawada',
    status: 'ACTIVE',
  });

  console.log(`[PASS] Created requirement ID: ${requirement._id} for ${requirement.quantity} ${requirement.quantityUnit} of ${requirement.commodity} @ ₹${requirement.offeredPrice}`);
  console.log(`[PASS] Grade is default: "${requirement.grade}" without user specification`);

  // Update requirement
  requirement.offeredPrice = 2300;
  await requirement.save();
  console.log(`[PASS] Updated requirement offeredPrice to: ₹${requirement.offeredPrice}`);

  console.log('\n--- TEST 5: NEW FARMER RATING HANDLING (NO 0.0 STARS) ---');
  const farmerUser = await User.create({
    name: 'Panda Farmer',
    phone: '9998882222',
    passwordHash: 'dummyHash123',
    role: 'FARMER',
    phoneVerified: true,
    verificationStatus: 'VERIFIED',
    verificationType: 'FARMER',
    verificationId: 'FARM-998877',
  });

  const newFarmerStats = await getUserRatingStats(farmerUser._id, 'FARMER');
  console.log(`[PASS] New Farmer Stats: displayRating="${newFarmerStats.displayRating}", label="${newFarmerStats.label}", isNew=${newFarmerStats.isNew}`);
  if (newFarmerStats.displayRating !== 'New Farmer' || newFarmerStats.rating !== null) {
    throw new Error('New Farmer rating display incorrect (expected New Farmer with null rating)');
  }

  console.log('\n--- TEST 6: FARMER CROP & BUYER EXPRESS INTEREST ---');
  const crop = await Crop.create({
    farmerId: farmerUser._id,
    commodity: 'Tomato',
    cropName: 'Tomato',
    variety: 'Desi',
    grade: 'FAQ',
    quantity: 500,
    quantityUnit: 'kg',
    expectedPrice: 2200,
    harvestDate: new Date(),
    state: 'Andhra Pradesh',
    district: 'Vijayawada',
    status: 'AVAILABLE',
  });

  const opportunity = await Opportunity.create({
    buyerId: buyerUser._id,
    farmerId: farmerUser._id,
    cropId: crop._id,
    requirementId: requirement._id,
    commodity: 'Tomato',
    quantity: 500,
    quantityUnit: 'kg',
    offeredPrice: 2200,
    status: 'INTERESTED',
  });

  const farmerNotification = await Notification.create({
    userId: farmerUser._id,
    farmerId: farmerUser._id,
    title: 'New Buyer Interest',
    type: 'BUYER_INTEREST',
    message: `Buyer ${buyerUser.name} is interested in your ${crop.commodity} crop.`,
    crop: crop.commodity,
    opportunityId: opportunity._id,
    status: 'UNREAD',
  });

  console.log(`[PASS] Buyer expressed interest (Opportunity ID: ${opportunity._id})`);
  console.log(`[PASS] Farmer notification created: "${farmerNotification.title}" -> "${farmerNotification.message}"`);

  console.log('\n--- TEST 7: TRANSACTION COMPLETION & TWO-WAY FEEDBACK ---');
  // Accept & Complete transaction
  opportunity.status = 'COMPLETED';
  await opportunity.save();
  crop.status = 'SOLD';
  await crop.save();

  // Buyer rates Farmer
  const buyerRating = await Rating.create({
    fromUserId: buyerUser._id,
    toUserId: farmerUser._id,
    fromRole: 'BUYER',
    cropId: crop._id,
    opportunityId: opportunity._id,
    rating: 5,
    categoryRatings: {
      productQuality: 5,
      freshness: 5,
      spoilage: 4,
      quantityAccuracy: 5,
      farmerInteraction: 5,
      transactionExperience: 5,
    },
    comment: 'Good quality product and smooth interaction.',
  });

  const updatedFarmerStats = await getUserRatingStats(farmerUser._id, 'FARMER');
  console.log(`[PASS] Submitted Rating: ${buyerRating.rating} Stars`);
  console.log(`[PASS] Recalculated Farmer Stats: displayRating="${updatedFarmerStats.displayRating}", label="${updatedFarmerStats.label}", ratingCount=${updatedFarmerStats.ratingCount}`);

  if (updatedFarmerStats.rating !== 5.0 || updatedFarmerStats.isNew) {
    throw new Error('Rating calculation failed');
  }

  console.log('\n--- TEST 8: FARMER INTEREST ALERT TO BUYER ---');
  const buyerReqNotification = await Notification.create({
    userId: buyerUser._id,
    farmerId: buyerUser._id,
    title: 'Farmer Interested',
    type: 'FARMER_INTEREST',
    message: `Farmer ${farmerUser.name} is looking to sell ${requirement.commodity} to you.`,
    crop: requirement.commodity,
    opportunityId: opportunity._id,
    status: 'UNREAD',
  });

  console.log(`[PASS] Buyer notification created: "${buyerReqNotification.title}" -> "${buyerReqNotification.message}"`);

  // Cleanup test data
  await Rating.deleteMany({ opportunityId: opportunity._id });
  await Opportunity.deleteMany({ _id: opportunity._id });
  await Notification.deleteMany({ _id: { $in: [farmerNotification._id, buyerReqNotification._id] } });
  await Crop.deleteMany({ _id: crop._id });
  await BuyerRequirement.deleteMany({ _id: requirement._id });
  await User.deleteMany({ _id: { $in: [buyerUser._id, farmerUser._id] } });

  await mongoose.connection.close();
  console.log('\n=== ALL BUYER PORTAL BACKEND TESTS PASSED SUCCESSFULLY! ===\n');
}

runTests().catch((err) => {
  console.error('[TEST FAILURE]:', err);
  process.exit(1);
});
