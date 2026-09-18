require('dotenv').config({ path: __dirname + '/../../.env' });
const mongoose = require('mongoose');
const http = require('http');
const app = require('../app');

const runPhase3Tests = async () => {
  console.log('--- STARTING PHASE 3 API & DATASET TEST SUITE ---');

  const mongoUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/farm-to-market';
  await mongoose.connect(mongoUri);
  console.log('[DB] Connected to MongoDB.');

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;
  const baseUrl = `http://localhost:${port}/api`;
  console.log(`[SERVER] Test server running at ${baseUrl}`);

  try {
    // 1. Health check
    console.log('\n[TEST 1] Testing Health Endpoint...');
    const healthRes = await fetch(`${baseUrl}/health`);
    const healthData = await healthRes.json();
    if (healthRes.status === 200 && healthData.database === 'connected') {
      console.log('  ✅ TEST 1 PASSED: Health API database = connected');
    } else {
      throw new Error(`TEST 1 FAILED: ${JSON.stringify(healthData)}`);
    }

    // 2. Dataset Stats API
    console.log('\n[TEST 2] Testing Market Stats Endpoint (GET /api/markets/stats)...');
    const statsRes = await fetch(`${baseUrl}/markets/stats`);
    const statsData = await statsRes.json();
    if (statsRes.status === 200 && statsData.success && statsData.data.totalRecords > 0) {
      console.log('  ✅ TEST 2 PASSED: Stats returned from MongoDB:');
      console.log('     Total Records     :', statsData.data.totalRecords);
      console.log('     Unique Commodities:', statsData.data.uniqueCommodities);
      console.log('     Unique Markets    :', statsData.data.uniqueMarkets);
      console.log('     Unique States     :', statsData.data.uniqueStates);
      console.log('     Unique Districts  :', statsData.data.uniqueDistricts);
      console.log('     Earliest Date     :', statsData.data.earliestDate);
      console.log('     Latest Date       :', statsData.data.latestDate);
    } else {
      throw new Error(`TEST 2 FAILED: ${JSON.stringify(statsData)}`);
    }

    // 3. Commodity Catalog API
    console.log('\n[TEST 3] Testing Commodity Catalog Endpoint (GET /api/commodities)...');
    const commRes = await fetch(`${baseUrl}/commodities`);
    const commData = await commRes.json();
    if (commRes.status === 200 && commData.success && Array.isArray(commData.data) && commData.data.length > 0) {
      console.log('  ✅ TEST 3 PASSED: Commodities catalog returned', commData.data.length, 'items:');
      console.log('     Sample Commodities:', commData.data.slice(0, 5).join(', '));
    } else {
      throw new Error(`TEST 3 FAILED: ${JSON.stringify(commData)}`);
    }

    // 4. Location APIs (States & Districts)
    console.log('\n[TEST 4] Testing Location Catalog Endpoints...');
    const stateRes = await fetch(`${baseUrl}/commodities/states`);
    const stateData = await stateRes.json();
    if (stateRes.status === 200 && stateData.data.length > 0) {
      console.log('  ✅ TEST 4A PASSED: States catalog returned', stateData.data.length, 'states');
    } else {
      throw new Error(`TEST 4A FAILED: ${JSON.stringify(stateData)}`);
    }

    const testState = stateData.data[0];
    const distRes = await fetch(`${baseUrl}/commodities/districts?state=${encodeURIComponent(testState)}`);
    const distData = await distRes.json();
    if (distRes.status === 200 && distData.data.length > 0) {
      console.log(`  ✅ TEST 4B PASSED: Districts catalog for [${testState}] returned`, distData.data.length, 'districts');
    } else {
      throw new Error(`TEST 4B FAILED: ${JSON.stringify(distData)}`);
    }

    // 5. Paginated Market Prices API
    console.log('\n[TEST 5] Testing Paginated Market Prices Endpoint (GET /api/markets/prices?limit=5)...');
    const pricesRes = await fetch(`${baseUrl}/markets/prices?limit=5`);
    const pricesData = await pricesRes.json();
    if (pricesRes.status === 200 && pricesData.success && pricesData.data.length === 5) {
      console.log('  ✅ TEST 5 PASSED: Market prices returned 5 items per page (Total: ' + pricesData.total + ', Pages: ' + pricesData.pages + ')');
      console.log('     Sample Record:', JSON.stringify(pricesData.data[0]));
    } else {
      throw new Error(`TEST 5 FAILED: ${JSON.stringify(pricesData)}`);
    }

    // 6. Filtered Market Prices API
    const testCommodity = commData.data[0];
    console.log(`\n[TEST 6] Testing Filtered Market Prices Endpoint (GET /api/markets/prices?commodity=${testCommodity})...`);
    const filterRes = await fetch(`${baseUrl}/markets/prices?commodity=${encodeURIComponent(testCommodity)}&limit=5`);
    const filterData = await filterRes.json();
    if (filterRes.status === 200 && filterData.data.every((r) => r.commodity.toLowerCase() === testCommodity.toLowerCase())) {
      console.log(`  ✅ TEST 6 PASSED: Filter returned ${filterData.total} matching records for commodity [${testCommodity}]`);
    } else {
      throw new Error(`TEST 6 FAILED: ${JSON.stringify(filterData)}`);
    }

    // 7. Search API
    console.log(`\n[TEST 7] Testing Market Search Endpoint (GET /api/markets/search?q=${testCommodity})...`);
    const searchRes = await fetch(`${baseUrl}/markets/search?q=${encodeURIComponent(testCommodity)}&limit=5`);
    const searchData = await searchRes.json();
    if (searchRes.status === 200 && searchData.data.length > 0) {
      console.log(`  ✅ TEST 7 PASSED: Search returned ${searchData.total} matching results for query [${testCommodity}]`);
    } else {
      throw new Error(`TEST 7 FAILED: ${JSON.stringify(searchData)}`);
    }

    // 8. Categories API
    console.log('\n[TEST 8] Testing Categories Endpoint (GET /api/commodities/categories)...');
    const catRes = await fetch(`${baseUrl}/commodities/categories`);
    const catData = await catRes.json();
    if (catRes.status === 200 && catData.success && catData.data.length >= 6) {
      console.log('  ✅ TEST 8 PASSED: Categories returned:', catData.data.map(c => c.name).join(', '));
    } else {
      throw new Error(`TEST 8 FAILED: ${JSON.stringify(catData)}`);
    }

    // 9. Vegetables Category Prices
    console.log('\n[TEST 9] Testing Vegetables Category Endpoint (GET /api/markets/category/vegetables)...');
    const vegRes = await fetch(`${baseUrl}/markets/category/vegetables`);
    const vegData = await vegRes.json();
    if (vegRes.status === 200 && vegData.success && vegData.data.length > 0) {
      console.log(`  ✅ TEST 9 PASSED: Vegetables returned ${vegData.data.length} commodities:`);
      vegData.data.forEach(v => console.log(`     - ${v.commodity}: ₹${v.modalPrice}/Q (${v.market}, ${v.state})`));
    } else {
      throw new Error(`TEST 9 FAILED: ${JSON.stringify(vegData)}`);
    }

    // 10. Pulses Category Prices
    console.log('\n[TEST 10] Testing Pulses Category Endpoint (GET /api/markets/category/pulses)...');
    const pulseRes = await fetch(`${baseUrl}/markets/category/pulses`);
    const pulseData = await pulseRes.json();
    if (pulseRes.status === 200 && pulseData.success && pulseData.data.length > 0) {
      console.log(`  ✅ TEST 10 PASSED: Pulses returned ${pulseData.data.length} commodities:`);
      pulseData.data.forEach(p => console.log(`     - ${p.commodity}: ₹${p.modalPrice}/Q (${p.market}, ${p.state})`));
    } else {
      throw new Error(`TEST 10 FAILED: ${JSON.stringify(pulseData)}`);
    }

    // 11. Historical Prices API
    console.log('\n[TEST 11] Testing Historical Prices Endpoint (GET /api/markets/history?commodity=Wheat&limit=10)...');
    const histRes = await fetch(`${baseUrl}/markets/history?commodity=Wheat&limit=10`);
    const histData = await histRes.json();
    if (histRes.status === 200 && histData.success && histData.data.length > 0) {
      console.log(`  ✅ TEST 11 PASSED: History returned ${histData.count} data points for Wheat`);
      console.log(`     Date range in sample: ${histData.data[0].date} to ${histData.data[histData.data.length - 1].date}`);
    } else {
      throw new Error(`TEST 11 FAILED: ${JSON.stringify(histData)}`);
    }

    // 12. /api/market-prices alias with latest & history
    console.log('\n[TEST 12] Testing /api/market-prices/latest alias...');
    const aliasRes = await fetch(`${baseUrl}/market-prices/latest?commodity=Tomato`);
    const aliasData = await aliasRes.json();
    if (aliasRes.status === 200 && aliasData.success) {
      console.log(`  ✅ TEST 12 PASSED: Reference price for Tomato returned:`, aliasData.data ? `₹${aliasData.data.modalPrice}/Q` : 'Not found');
    } else {
      throw new Error(`TEST 12 FAILED: ${JSON.stringify(aliasData)}`);
    }

    console.log('\n==================================================');
    console.log('🎉 ALL PHASE 3 BACKEND & DATASET TESTS PASSED!');
    console.log('==================================================\n');
  } finally {
    server.close();
    await mongoose.connection.close();
  }
};

runPhase3Tests().catch((err) => {
  console.error('\n❌ TEST RUN FAILED:', err);
  process.exit(1);
});
