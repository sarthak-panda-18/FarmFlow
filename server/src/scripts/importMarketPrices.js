require('dotenv').config({ path: __dirname + '/../../.env' });
const fs = require('fs');
const readline = require('readline');
const path = require('path');
const mongoose = require('mongoose');
const MarketPrice = require('../models/MarketPrice');

const csvFilePath = path.join(__dirname, '../../../dataset/agmarknet_india_historical_prices_2024_2025.csv');

// Helper to parse date strings like "05-Apr-25" or ISO strings
const parseDate = (dateStr) => {
  if (!dateStr || dateStr.trim() === '') return null;
  const str = dateStr.trim();

  let d = new Date(str);
  if (!isNaN(d.getTime())) return d;

  const parts = str.split('-');
  if (parts.length === 3) {
    const day = parseInt(parts[0], 10);
    const monthStr = parts[1];
    let year = parseInt(parts[2], 10);
    if (year < 100) year += 2000;

    const months = {
      jan: 0, feb: 1, mar: 2, apr: 3, may: 4, jun: 5,
      jul: 6, aug: 7, sep: 8, oct: 9, nov: 10, dec: 11,
    };

    const month = months[monthStr.toLowerCase()];
    if (month !== undefined && !isNaN(day) && !isNaN(year)) {
      return new Date(Date.UTC(year, month, day));
    }
  }

  return null;
};

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

const importDataset = async () => {
  console.log('--- STARTING AGMARKNET BULK DATASET IMPORT ---');
  console.log('File:', csvFilePath);

  if (!fs.existsSync(csvFilePath)) {
    console.error('FATAL: CSV Dataset file not found:', csvFilePath);
    process.exit(1);
  }

  const mongoUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/farm-to-market';
  console.log('Connecting to MongoDB...');
  await mongoose.connect(mongoUri);
  console.log('Connected to MongoDB.');

  // Create indexes if not exists
  await MarketPrice.createIndexes();

  const rl = readline.createInterface({
    input: fs.createReadStream(csvFilePath),
    crlfDelay: Infinity,
  });

  let totalRows = 0;
  let validRowsCount = 0;
  let invalidRowsCount = 0;
  let insertedCount = 0;
  let upsertedCount = 0;
  let headers = [];

  const BATCH_SIZE = 5000;
  let bulkOps = [];

  for await (const line of rl) {
    if (!line || line.trim().length === 0) continue;

    if (totalRows === 0) {
      headers = parseCSVLine(line);
      totalRows++;
      continue;
    }

    totalRows++;

    const values = parseCSVLine(line);
    const rowObj = {};
    headers.forEach((h, i) => {
      rowObj[h] = values[i] !== undefined ? values[i] : '';
    });

    const state = (rowObj['State'] || '').trim();
    const district = (rowObj['District Name'] || rowObj['District'] || '').trim();
    const market = (rowObj['Market Name'] || rowObj['Market'] || '').trim();
    const commodity = (rowObj['Commodity'] || '').trim();
    const variety = (rowObj['Variety'] || 'Other').trim();
    const grade = (rowObj['Grade'] || 'FAQ').trim();

    const minPrice = parseFloat(rowObj['Min Price (Rs./Quintal)'] || '0');
    const maxPrice = parseFloat(rowObj['Max Price (Rs./Quintal)'] || '0');
    const modalPrice = parseFloat(rowObj['Modal Price (Rs./Quintal)'] || '0');
    const dateStr = rowObj['Price Date'] || '';

    const parsedDate = parseDate(dateStr);

    const isValidPrice =
      !isNaN(minPrice) &&
      !isNaN(maxPrice) &&
      !isNaN(modalPrice) &&
      minPrice >= 0 &&
      maxPrice >= 0 &&
      modalPrice >= 0 &&
      minPrice <= modalPrice &&
      modalPrice <= maxPrice;

    const isValid = isValidPrice && parsedDate !== null && state && commodity && market && district;

    if (!isValid) {
      invalidRowsCount++;
      continue;
    }

    validRowsCount++;

    const filter = {
      state,
      district,
      market,
      commodity,
      variety,
      grade,
      date: parsedDate,
    };

    const update = {
      $set: {
        state,
        district,
        market,
        commodity,
        variety,
        grade,
        minPrice,
        maxPrice,
        modalPrice,
        date: parsedDate,
      },
    };

    bulkOps.push({
      updateOne: {
        filter,
        update,
        upsert: true,
      },
    });

    if (bulkOps.length >= BATCH_SIZE) {
      const res = await MarketPrice.bulkWrite(bulkOps, { ordered: false });
      insertedCount += res.insertedCount || 0;
      upsertedCount += res.upsertedCount || res.nUpserted || 0;
      process.stdout.write(`\rImported ${validRowsCount} / ${totalRows - 1} records...`);
      bulkOps = [];
    }
  }

  if (bulkOps.length > 0) {
    const res = await MarketPrice.bulkWrite(bulkOps, { ordered: false });
    insertedCount += res.insertedCount || 0;
    upsertedCount += res.upsertedCount || res.nUpserted || 0;
    bulkOps = [];
  }

  const finalCountInDB = await MarketPrice.countDocuments();

  console.log('\n\n==================================================');
  console.log('🎉 AGMARKNET DATASET IMPORT COMPLETED');
  console.log('==================================================');
  console.log('Total CSV Data Rows :', totalRows - 1);
  console.log('Valid Records       :', validRowsCount);
  console.log('Invalid/Skipped Rows:', invalidRowsCount);
  console.log('Upserted / Processed:', upsertedCount || validRowsCount);
  console.log('Total MongoDB Count :', finalCountInDB);
  console.log('==================================================\n');

  await mongoose.connection.close();
  process.exit(0);
};

if (require.main === module) {
  importDataset().catch((err) => {
    console.error('Import error:', err.message);
    process.exit(1);
  });
}

module.exports = importDataset;
