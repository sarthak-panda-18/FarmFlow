/**
 * Dedicated Mathematical Threshold Test for Market Price ±5% Alerts
 * Verifies exact formula and trigger conditions:
 * +4.9% -> No Alert
 * +5.0% -> Alert
 * +6.0% -> Alert
 * -4.9% -> No Alert
 * -5.0% -> Alert
 * -6.0% -> Alert
 */

const assert = require('assert');

function calculatePercentageChange(currentPrice, previousPrice) {
  if (!previousPrice || previousPrice <= 0) return 0;
  return ((currentPrice - previousPrice) / previousPrice) * 100;
}

function shouldTriggerMarketAlert(currentPrice, previousPrice) {
  const pct = calculatePercentageChange(currentPrice, previousPrice);
  return Math.abs(pct) >= 5.0;
}

function testThresholds() {
  console.log('===============================================================');
  console.log('  TESTING MARKET PRICE ±5% MATHEMATICAL THRESHOLD RULES');
  console.log('===============================================================\n');

  const basePrice = 8000; // ₹8,000 / Quintal

  // Test 1: +4.9% (₹8,392)
  const p_plus_4_9 = 8000 * 1.049; // 8392
  const pct_4_9 = calculatePercentageChange(p_plus_4_9, basePrice);
  const trigger_4_9 = shouldTriggerMarketAlert(p_plus_4_9, basePrice);
  assert(Math.abs(pct_4_9 - 4.9) < 0.001, '+4.9% calculated correctly');
  assert(trigger_4_9 === false, '+4.9% does NOT trigger alert');
  console.log(`  ✓ +4.9% Change (₹${basePrice} -> ₹${p_plus_4_9}): Pct = +${pct_4_9.toFixed(2)}%, Trigger = ${trigger_4_9} [NO ALERT]`);

  // Test 2: +5.0% (₹8,400)
  const p_plus_5_0 = 8000 * 1.050; // 8400
  const pct_5_0 = calculatePercentageChange(p_plus_5_0, basePrice);
  const trigger_5_0 = shouldTriggerMarketAlert(p_plus_5_0, basePrice);
  assert(Math.abs(pct_5_0 - 5.0) < 0.001, '+5.0% calculated correctly');
  assert(trigger_5_0 === true, '+5.0% DOES trigger alert');
  console.log(`  ✓ +5.0% Change (₹${basePrice} -> ₹${p_plus_5_0}): Pct = +${pct_5_0.toFixed(2)}%, Trigger = ${trigger_5_0} [ALERT TRIGGERED]`);

  // Test 3: +6.0% (₹8,480)
  const p_plus_6_0 = 8000 * 1.060; // 8480
  const pct_6_0 = calculatePercentageChange(p_plus_6_0, basePrice);
  const trigger_6_0 = shouldTriggerMarketAlert(p_plus_6_0, basePrice);
  assert(Math.abs(pct_6_0 - 6.0) < 0.001, '+6.0% calculated correctly');
  assert(trigger_6_0 === true, '+6.0% DOES trigger alert');
  console.log(`  ✓ +6.0% Change (₹${basePrice} -> ₹${p_plus_6_0}): Pct = +${pct_6_0.toFixed(2)}%, Trigger = ${trigger_6_0} [ALERT TRIGGERED]`);

  // Test 4: -4.9% (₹7,608)
  const p_minus_4_9 = 8000 * (1 - 0.049); // 7608
  const pct_minus_4_9 = calculatePercentageChange(p_minus_4_9, basePrice);
  const trigger_minus_4_9 = shouldTriggerMarketAlert(p_minus_4_9, basePrice);
  assert(Math.abs(pct_minus_4_9 - (-4.9)) < 0.001, '-4.9% calculated correctly');
  assert(trigger_minus_4_9 === false, '-4.9% does NOT trigger alert');
  console.log(`  ✓ -4.9% Change (₹${basePrice} -> ₹${p_minus_4_9}): Pct = ${pct_minus_4_9.toFixed(2)}%, Trigger = ${trigger_minus_4_9} [NO ALERT]`);

  // Test 5: -5.0% (₹7,600)
  const p_minus_5_0 = 8000 * (1 - 0.050); // 7600
  const pct_minus_5_0 = calculatePercentageChange(p_minus_5_0, basePrice);
  const trigger_minus_5_0 = shouldTriggerMarketAlert(p_minus_5_0, basePrice);
  assert(Math.abs(pct_minus_5_0 - (-5.0)) < 0.001, '-5.0% calculated correctly');
  assert(trigger_minus_5_0 === true, '-5.0% DOES trigger alert');
  console.log(`  ✓ -5.0% Change (₹${basePrice} -> ₹${p_minus_5_0}): Pct = ${pct_minus_5_0.toFixed(2)}%, Trigger = ${trigger_minus_5_0} [ALERT TRIGGERED]`);

  // Test 6: -6.0% (₹7,520)
  const p_minus_6_0 = 8000 * (1 - 0.060); // 7520
  const pct_minus_6_0 = calculatePercentageChange(p_minus_6_0, basePrice);
  const trigger_minus_6_0 = shouldTriggerMarketAlert(p_minus_6_0, basePrice);
  assert(Math.abs(pct_minus_6_0 - (-6.0)) < 0.001, '-6.0% calculated correctly');
  assert(trigger_minus_6_0 === true, '-6.0% DOES trigger alert');
  console.log(`  ✓ -6.0% Change (₹${basePrice} -> ₹${p_minus_6_0}): Pct = ${pct_minus_6_0.toFixed(2)}%, Trigger = ${trigger_minus_6_0} [ALERT TRIGGERED]`);

  console.log('\n===============================================================');
  console.log('  ALL ±5% MATHEMATICAL THRESHOLD RULES VERIFIED (100%)');
  console.log('===============================================================\n');
}

testThresholds();
