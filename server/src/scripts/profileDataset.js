const fs = require('fs');
const readline = require('readline');
const path = require('path');

const csvFilePath = path.join(__dirname, '../../../dataset/agmarknet_india_historical_prices_2024_2025.csv');

// Helper to parse date strings like "05-Apr-25" or ISO strings
const parseDate = (dateStr) => {
  if (!dateStr || dateStr.trim() === '') return null;
  const str = dateStr.trim();

  // Try standard parse
  let d = new Date(str);
  if (!isNaN(d.getTime())) return d;

  // Handle DD-MMM-YY (e.g. 05-Apr-25)
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

// Basic CSV row splitter handling quotes
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

const profileDataset = async () => {
  console.log('--- AGMARKNET DATASET PROFILING STARTED ---');
  console.log('File:', csvFilePath);

  if (!fs.existsSync(csvFilePath)) {
    console.error('File not found:', csvFilePath);
    process.exit(1);
  }

  const rl = readline.createInterface({
    input: fs.createReadStream(csvFilePath),
    crlfDelay: Infinity,
  });

  let totalRows = 0;
  let headers = [];
  const states = new Set();
  const districts = new Set();
  const markets = new Set();
  const commodities = new Set();
  const varieties = new Set();
  const grades = new Set();

  let minDate = null;
  let maxDate = null;
  let overallMinPrice = Infinity;
  let overallMaxPrice = -Infinity;
  let overallModalMin = Infinity;
  let overallModalMax = -Infinity;

  let validRowsCount = 0;
  let invalidRowsCount = 0;
  let duplicateCount = 0;
  const nullOrEmptyFieldCounts = {};
  const uniqueKeys = new Set();

  for await (const line of rl) {
    if (!line || line.trim().length === 0) continue;

    if (totalRows === 0) {
      headers = parseCSVLine(line);
      console.log('Headers found:', headers);
      headers.forEach((h) => (nullOrEmptyFieldCounts[h] = 0));
      totalRows++;
      continue;
    }

    totalRows++;

    const values = parseCSVLine(line);
    const rowObj = {};
    headers.forEach((h, i) => {
      rowObj[h] = values[i] !== undefined ? values[i] : '';
      if (!rowObj[h] || rowObj[h].length === 0) {
        nullOrEmptyFieldCounts[h]++;
      }
    });

    const state = rowObj['State'] || '';
    const district = rowObj['District Name'] || rowObj['District'] || '';
    const market = rowObj['Market Name'] || rowObj['Market'] || '';
    const commodity = rowObj['Commodity'] || '';
    const variety = rowObj['Variety'] || '';
    const grade = rowObj['Grade'] || '';

    const minPrice = parseFloat(rowObj['Min Price (Rs./Quintal)'] || '0');
    const maxPrice = parseFloat(rowObj['Max Price (Rs./Quintal)'] || '0');
    const modalPrice = parseFloat(rowObj['Modal Price (Rs./Quintal)'] || '0');
    const dateStr = rowObj['Price Date'] || '';

    if (state) states.add(state);
    if (district) districts.add(district);
    if (market) markets.add(market);
    if (commodity) commodities.add(commodity);
    if (variety) varieties.add(variety);
    if (grade) grades.add(grade);

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

    const isValidDate = parsedDate !== null;

    if (isValidPrice && isValidDate && state && commodity && market) {
      validRowsCount++;

      const uniqueKey = `${parsedDate.toISOString().split('T')[0]}|${state}|${district}|${market}|${commodity}|${variety}|${grade}`;
      if (uniqueKeys.has(uniqueKey)) {
        duplicateCount++;
      } else {
        uniqueKeys.add(uniqueKey);
      }

      if (!minDate || parsedDate < minDate) minDate = parsedDate;
      if (!maxDate || parsedDate > maxDate) maxDate = parsedDate;

      if (minPrice < overallMinPrice) overallMinPrice = minPrice;
      if (maxPrice > overallMaxPrice) overallMaxPrice = maxPrice;
      if (modalPrice < overallModalMin) overallModalMin = modalPrice;
      if (modalPrice > overallModalMax) overallModalMax = modalPrice;
    } else {
      invalidRowsCount++;
    }
  }

  const dataRowsCount = totalRows - 1;

  console.log('\n--- DATASET PROFILING REPORT ---');
  console.log('Total Data Rows:', dataRowsCount);
  console.log('Total Columns:', headers.length);
  console.log('Headers:', headers.join(', '));
  console.log('Valid Records:', validRowsCount);
  console.log('Invalid/Out-of-range Records:', invalidRowsCount);
  console.log('Unique Valid Compound Records:', uniqueKeys.size);
  console.log('Duplicate Records Skipped:', duplicateCount);
  console.log('\nCategorical Statistics:');
  console.log('- Unique States:', states.size);
  console.log('- Unique Districts:', districts.size);
  console.log('- Unique Markets:', markets.size);
  console.log('- Unique Commodities:', commodities.size);
  console.log('- Unique Varieties:', varieties.size);
  console.log('- Unique Grades:', grades.size);
  console.log('\nDate Range:');
  console.log('- Earliest Date:', minDate ? minDate.toISOString().split('T')[0] : 'N/A');
  console.log('- Latest Date:', maxDate ? maxDate.toISOString().split('T')[0] : 'N/A');
  console.log('\nPrice Ranges (Valid Records):');
  console.log('- Min Price Range: ₹', overallMinPrice, 'to ₹', overallMaxPrice);
  console.log('- Modal Price Range: ₹', overallModalMin, 'to ₹', overallModalMax);
  console.log('\nNull/Empty Counts per Field:');
  console.log(JSON.stringify(nullOrEmptyFieldCounts, null, 2));

  return {
    dataRowsCount,
    headers,
    validRowsCount,
    invalidRowsCount,
    duplicateCount,
    statesCount: states.size,
    districtsCount: districts.size,
    marketsCount: markets.size,
    commoditiesCount: commodities.size,
    varietiesCount: varieties.size,
    gradesCount: grades.size,
    minDate: minDate ? minDate.toISOString().split('T')[0] : null,
    maxDate: maxDate ? maxDate.toISOString().split('T')[0] : null,
    overallMinPrice,
    overallMaxPrice,
    overallModalMin,
    overallModalMax,
    nullOrEmptyFieldCounts,
  };
};

if (require.main === module) {
  profileDataset();
}

module.exports = profileDataset;
