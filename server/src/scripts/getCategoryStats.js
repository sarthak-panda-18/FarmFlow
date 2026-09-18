require('dotenv').config({ path: __dirname + '/../../.env' });
const mongoose = require('mongoose');
const MarketPrice = require('../models/MarketPrice');
const { CATEGORY_MAP } = require('../utils/commodityCategoryMapping');

(async () => {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/farm-to-market');
  console.log('Total in DB:', await MarketPrice.countDocuments());
  
  const vegComms = CATEGORY_MAP.vegetables;
  const vegCount = await MarketPrice.countDocuments({ commodity: { $in: vegComms } });
  console.log('Vegetables total records:', vegCount, 'for commodities:', vegComms.join(', '));

  const pulseComms = CATEGORY_MAP.pulses;
  const pulseCount = await MarketPrice.countDocuments({ commodity: { $in: pulseComms } });
  console.log('Pulses total records:', pulseCount, 'for commodities:', pulseComms.join(', '));

  const allCategories = ['vegetables', 'pulses', 'cereals', 'fruits', 'oilseeds', 'commercial'];
  for (const cat of allCategories) {
    const comms = CATEGORY_MAP[cat];
    const count = await MarketPrice.countDocuments({ commodity: { $in: comms } });
    console.log(cat + ' count:', count);
  }

  // Individual commodity counts
  const commList = await MarketPrice.distinct('commodity');
  console.log('\nIndividual Commodity Counts (Total Unique: ' + commList.length + '):');
  for (const comm of commList.sort()) {
    const c = await MarketPrice.countDocuments({ commodity: comm });
    console.log(`- ${comm}: ${c} records`);
  }

  await mongoose.connection.close();
})();
