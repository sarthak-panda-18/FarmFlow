const fs = require('fs');
const readline = require('readline');
const path = require('path');
const mongoose = require('mongoose');

const csvFilePath = path.join(__dirname, '../../../dataset/agmarknet_india_historical_prices_2024_2025.csv');
const MarketPrice = require('../models/MarketPrice');

// CSV line splitter handling quotes
const parseCSVLine = (text) => {
  const result = [];
  let cur = '';
  let inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === '"') {
      inQuotes = !inQuotes;
    } else if (c === ',' && !inQuotes) {
      result.push(cur.trim().replace(/^"|"$/g, ''));
      cur = '';
    } else {
      cur += c;
    }
  }
  result.push(cur.trim().replace(/^"|"$/g, ''));
  return result;
};

async function check() {
  const mongoUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/farm-to-market';
  await mongoose.connect(mongoUri);

  const dbCommodities = await MarketPrice.distinct('commodity');
  console.log('--- MONGO DB COMMODITIES (' + dbCommodities.length + ') ---');
  console.log(dbCommodities);

  if (fs.existsSync(csvFilePath)) {
    const rl = readline.createInterface({
      input: fs.createReadStream(csvFilePath),
      crlfDelay: Infinity,
    });

    const csvCommodities = new Map();
    let headers = null;

    for await (const line of rl) {
      if (!line || !line.trim()) continue;
      const values = parseCSVLine(line);
      if (!headers) {
        headers = values;
        continue;
      }
      const commIdx = headers.indexOf('Commodity');
      if (commIdx !== -1 && values[commIdx]) {
        const c = values[commIdx].trim();
        csvCommodities.set(c, (csvCommodities.get(c) || 0) + 1);
      }
    }

    console.log('\n--- CSV COMMODITIES (' + csvCommodities.size + ') ---');
    console.log(Object.fromEntries(csvCommodities));
  } else {
    console.log('CSV file not found at:', csvFilePath);
  }

  await mongoose.connection.close();
}

check().catch(console.error);
