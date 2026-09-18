const fs = require('fs');
const readline = require('readline');
const path = require('path');

const csvFilePath = path.join(__dirname, '../../../dataset/agmarknet_india_historical_prices_2024_2025.csv');

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

async function run() {
  const rl = readline.createInterface({
    input: fs.createReadStream(csvFilePath),
    crlfDelay: Infinity,
  });

  const comms = new Map();
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
      comms.set(c, (comms.get(c) || 0) + 1);
    }
  }

  console.log('--- ALL COMMODITIES IN AGMARKNET CSV ---');
  for (const [name, count] of comms.entries()) {
    console.log(`${name}: ${count} records`);
  }
}

run().catch(console.error);
