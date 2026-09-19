require('dotenv').config({ path: __dirname + '/../../.env' });
const mongoose = require('mongoose');
const http = require('http');
const app = require('../app');
const User = require('../models/User');
const Crop = require('../models/Crop');
const BuyerRequirement = require('../models/BuyerRequirement');

async function runEdgeCaseValidation() {
  console.log('🧪 RUNNING MATCHING NULL-SAFETY AND DISTANCE FILTER VALIDATION SUITE');

  const mongoUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/farm-to-market';
  await mongoose.connect(mongoUri);

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;
  const baseUrl = `http://localhost:${port}/api`;

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
    const suffix = Math.floor(10000000 + Math.random() * 90000000);
    const password = 'Password123!';

    // Register Farmer 1 (with coordinates: Guntur [16.3067, 80.4365])
    const regFarmer1 = await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Guntur Farmer',
        phone: '98' + suffix.toString().slice(0, 8),
        password,
        role: 'FARMER',
        farmerId: 'FARM' + suffix.toString().slice(0, 6),
      }),
    }).then(r => r.json());
    const farmer1Token = regFarmer1.data.token;
    const farmer1Id = regFarmer1.data.user.id;
    await User.findByIdAndUpdate(farmer1Id, {
      phoneVerified: true,
      verificationStatus: 'VERIFIED',
      location: { type: 'Point', coordinates: [80.4365, 16.3067] },
    });

    // Register Farmer 2 (WITHOUT coordinates / missing location)
    const regFarmer2 = await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'No Coordinates Farmer',
        phone: '97' + suffix.toString().slice(0, 8),
        password,
        role: 'FARMER',
        farmerId: 'FARM2' + suffix.toString().slice(0, 5),
      }),
    }).then(r => r.json());
    const farmer2Token = regFarmer2.data.token;
    const farmer2Id = regFarmer2.data.user.id;
    await User.findByIdAndUpdate(farmer2Id, {
      phoneVerified: true,
      verificationStatus: 'VERIFIED',
      location: null,
    });

    // Register Buyer 1 (Vijayawada [16.5062, 80.6480] ~31.6km from Guntur)
    const regBuyer1 = await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Vijayawada Buyer',
        businessName: 'VJA Wholesale Foods',
        phone: '96' + suffix.toString().slice(0, 8),
        password,
        role: 'BUYER',
        gstin: '37AAAAA1111A1Z1',
      }),
    }).then(r => r.json());
    const buyer1Token = regBuyer1.data.token;
    const buyer1Id = regBuyer1.data.user.id;
    await User.findByIdAndUpdate(buyer1Id, {
      phoneVerified: true,
      verificationStatus: 'VERIFIED',
      location: { type: 'Point', coordinates: [80.6480, 16.5062] },
    });

    // Register Buyer 2 (Vizag [17.6868, 83.2185] ~310km from Guntur)
    const regBuyer2 = await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Vizag Buyer',
        businessName: 'Vizag Mega Traders',
        phone: '95' + suffix.toString().slice(0, 8),
        password,
        role: 'BUYER',
        gstin: '37AAAAA2222A1Z2',
      }),
    }).then(r => r.json());
    const buyer2Token = regBuyer2.data.token;
    const buyer2Id = regBuyer2.data.user.id;
    await User.findByIdAndUpdate(buyer2Id, {
      phoneVerified: true,
      verificationStatus: 'VERIFIED',
      location: { type: 'Point', coordinates: [83.2185, 17.6868] },
    });

    // Register Buyer 3 (WITHOUT coordinates)
    const regBuyer3 = await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'No Coords Buyer',
        businessName: 'Remote Buyer Ltd',
        phone: '94' + suffix.toString().slice(0, 8),
        password,
        role: 'BUYER',
        gstin: '37AAAAA3333A1Z3',
      }),
    }).then(r => r.json());
    const buyer3Token = regBuyer3.data.token;
    const buyer3Id = regBuyer3.data.user.id;
    await User.findByIdAndUpdate(buyer3Id, {
      phoneVerified: true,
      verificationStatus: 'VERIFIED',
      location: null,
      state: '',
      district: '',
      city: '',
      address: '',
    });

    const comm = 'Bhindi(Ladies Finger)';
    const futureDate = new Date(Date.now() + 15 * 86400000).toISOString().split('T')[0];

    // Crop 1 for Farmer 1
    const c1 = await Crop.create({
      farmerId: farmer1Id,
      commodity: comm,
      cropName: 'Guntur Bhindi',
      quantity: 50,
      quantityUnit: 'quintal',
      expectedPrice: 2000,
      harvestDate: futureDate,
      state: 'Andhra Pradesh',
      district: 'Guntur',
      status: 'AVAILABLE',
    });

    // Requirement 1 for Buyer 1 (Vijayawada ~31.6km)
    const r1 = await BuyerRequirement.create({
      buyerId: buyer1Id,
      commodity: comm,
      cropName: 'Bhindi',
      quantity: 50,
      quantityUnit: 'quintal',
      offeredPrice: 2100,
      requiredByDate: futureDate,
      state: 'Andhra Pradesh',
      district: 'Krishna',
      status: 'ACTIVE',
    });

    // Requirement 2 for Buyer 2 (Vizag ~310km)
    const r2 = await BuyerRequirement.create({
      buyerId: buyer2Id,
      commodity: comm,
      cropName: 'Bhindi',
      quantity: 50,
      quantityUnit: 'quintal',
      offeredPrice: 2200,
      requiredByDate: futureDate,
      state: 'Andhra Pradesh',
      district: 'Visakhapatnam',
      status: 'ACTIVE',
    });

    // Requirement 3 for Buyer 3 (No Coordinates and No APMC district fallback)
    const r3 = await BuyerRequirement.create({
      buyerId: buyer3Id,
      commodity: comm,
      cropName: 'Bhindi',
      quantity: 50,
      quantityUnit: 'quintal',
      offeredPrice: 2150,
      requiredByDate: futureDate,
      state: 'Custom State',
      district: 'Custom District',
      status: 'ACTIVE',
    });

    // Requirement 4 with a DELETED/ORPHANED Buyer ID (to test null reference crash resilience)
    const fakeBuyerId = new mongoose.Types.ObjectId();
    const r4Orphaned = await BuyerRequirement.create({
      buyerId: fakeBuyerId,
      commodity: comm,
      cropName: 'Bhindi',
      quantity: 20,
      quantityUnit: 'quintal',
      offeredPrice: 1950,
      requiredByDate: futureDate,
      state: 'Andhra Pradesh',
      district: 'Guntur',
      status: 'ACTIVE',
    });

    console.log('\n--- 1. Testing Farmer Matches with Orphaned / Null Buyer reference ---');
    const fResAll = await fetch(`${baseUrl}/matches/farmer`, {
      headers: { Authorization: `Bearer ${farmer1Token}` },
    }).then(r => r.json());

    assert(fResAll.success === true, 'Farmer Matches API responds 200 without throwing toString error on null buyerId');
    assert(fResAll.data.length >= 4, `Found all matching requirements (count: ${fResAll.data.length})`);

    const orphanedMatch = fResAll.data.find(m => m.requirementId === r4Orphaned._id.toString());
    assert(orphanedMatch !== undefined, 'Orphaned buyer requirement is safely handled without throwing null toString error');
    assert(orphanedMatch && orphanedMatch.buyerName === 'Verified Buyer', 'Orphaned buyer has fallback display name');

    console.log('\n--- 2. Testing Distance Filtering on Farmer Matches ---');
    // Filter at 25km (Vijayawada is 31.6km, Vizag is 310km) -> neither 31.6km nor 310km should pass, but missing coordinates are preserved
    const fRes25 = await fetch(`${baseUrl}/matches/farmer?maxDistance=25`, {
      headers: { Authorization: `Bearer ${farmer1Token}` },
    }).then(r => r.json());
    assert(fRes25.success === true, 'Matches query with maxDistance=25 succeeds');
    const hasVja25 = fRes25.data.some(m => m.requirementId === r1._id.toString());
    const hasVizag25 = fRes25.data.some(m => m.requirementId === r2._id.toString());
    assert(!hasVja25, 'Vijayawada (31.6km) excluded when maxDistance=25');
    assert(!hasVizag25, 'Vizag (310km) excluded when maxDistance=25');

    // Filter at 50km (Vijayawada is 31.6km -> included, Vizag is 310km -> excluded)
    const fRes50 = await fetch(`${baseUrl}/matches/farmer?maxDistance=50`, {
      headers: { Authorization: `Bearer ${farmer1Token}` },
    }).then(r => r.json());
    const hasVja50 = fRes50.data.some(m => m.requirementId === r1._id.toString());
    const hasVizag50 = fRes50.data.some(m => m.requirementId === r2._id.toString());
    assert(hasVja50, 'Vijayawada (31.6km) included when maxDistance=50');
    assert(!hasVizag50, 'Vizag (310km) excluded when maxDistance=50');

    // Filter at 500km (Vizag is 310km -> included)
    const fRes500 = await fetch(`${baseUrl}/matches/farmer?maxDistance=500`, {
      headers: { Authorization: `Bearer ${farmer1Token}` },
    }).then(r => r.json());
    const hasVizag500 = fRes500.data.some(m => m.requirementId === r2._id.toString());
    assert(hasVizag500, 'Vizag (310km) included when maxDistance=500');

    console.log('\n--- 3. Testing Missing Coordinates Handling ---');
    // Buyer 3 has null coordinates -> distanceKm should be null, NOT 0 km!
    const noCoordsMatch = fResAll.data.find(m => m.requirementId === r3._id.toString());
    console.log('    noCoordsMatch:', JSON.stringify(noCoordsMatch, null, 2));
    assert(noCoordsMatch !== undefined, 'Requirement with missing coordinates returned');
    assert(noCoordsMatch && noCoordsMatch.distanceKm === null, 'Missing coordinates are kept as distanceKm: null (NOT 0 km)');
    assert(noCoordsMatch && noCoordsMatch.buyerCoordinates === null, 'buyerCoordinates is null');

    console.log('\n--- 4. Testing Buyer Matches with Null / Orphaned Farmer reference ---');
    // Crop with deleted / orphaned farmer ID
    const fakeFarmerId = new mongoose.Types.ObjectId();
    const cOrphaned = await Crop.create({
      farmerId: fakeFarmerId,
      commodity: comm,
      cropName: 'Orphaned Crop',
      quantity: 40,
      quantityUnit: 'quintal',
      expectedPrice: 2050,
      harvestDate: futureDate,
      state: 'Andhra Pradesh',
      district: 'Guntur',
      status: 'AVAILABLE',
    });

    const bResAll = await fetch(`${baseUrl}/matches/buyer`, {
      headers: { Authorization: `Bearer ${buyer1Token}` },
    }).then(r => r.json());

    assert(bResAll.success === true, 'Buyer Matches API responds 200 without throwing toString error');
    const orphanedCropMatch = bResAll.data.find(m => m.cropId === cOrphaned._id.toString());
    assert(orphanedCropMatch !== undefined, 'Orphaned farmer crop is safely handled in buyer matches');
    assert(orphanedCropMatch && orphanedCropMatch.farmerName === 'Verified Farmer', 'Orphaned farmer has fallback display name');

    console.log('\n--- 5. Testing Buyer Matches Distance Filtering ---');
    const bRes25 = await fetch(`${baseUrl}/matches/buyer?maxDistance=25`, {
      headers: { Authorization: `Bearer ${buyer1Token}` },
    }).then(r => r.json());
    assert(bRes25.success === true, 'Buyer query with maxDistance=25 succeeds');
    const hasGuntur25 = bRes25.data.some(m => m.cropId === c1._id.toString());
    assert(!hasGuntur25, 'Guntur crop (31.6km) excluded when maxDistance=25 for Buyer 1');

    const bRes50 = await fetch(`${baseUrl}/matches/buyer?maxDistance=50`, {
      headers: { Authorization: `Bearer ${buyer1Token}` },
    }).then(r => r.json());
    const hasGuntur50 = bRes50.data.some(m => m.cropId === c1._id.toString());
    assert(hasGuntur50, 'Guntur crop (31.6km) included when maxDistance=50 for Buyer 1');

    console.log('\n--- 6. Testing Empty State ---');
    // Create new Farmer with no crops
    const regFarmerEmpty = await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Empty Farmer',
        phone: '93' + suffix.toString().slice(0, 8),
        password,
        role: 'FARMER',
        farmerId: 'FARM_EMPTY_' + suffix.toString().slice(0, 4),
      }),
    }).then(r => r.json());
    const emptyFarmerToken = regFarmerEmpty.data.token;

    const fEmptyRes = await fetch(`${baseUrl}/matches/farmer`, {
      headers: { Authorization: `Bearer ${emptyFarmerToken}` },
    }).then(r => r.json());
    assert(fEmptyRes.success === true && fEmptyRes.count === 0 && fEmptyRes.data.length === 0, 'Farmer with no crops returns clean empty state with count=0');

    // Clean up
    await Crop.deleteMany({ _id: { $in: [c1._id, cOrphaned._id] } });
    await BuyerRequirement.deleteMany({ _id: { $in: [r1._id, r2._id, r3._id, r4Orphaned._id] } });
    await User.deleteMany({ _id: { $in: [farmer1Id, farmer2Id, buyer1Id, buyer2Id, buyer3Id, regFarmerEmpty.data.user.id] } });

    server.close();
    await mongoose.disconnect();

    console.log('\n=============================================================');
    console.log(`📊 TEST SUITE FINISHED: Passed: ${passed}, Failed: ${failed}`);
    console.log('=============================================================\n');

    if (failed > 0) {
      process.exit(1);
    } else {
      process.exit(0);
    }
  } catch (err) {
    console.error('Test execution error:', err);
    server.close();
    await mongoose.disconnect();
    process.exit(1);
  }
}

runEdgeCaseValidation();
