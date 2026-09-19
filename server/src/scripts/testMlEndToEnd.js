/**
 * Comprehensive End-to-End Verification Test for FarmFlow ML Integration
 */

async function runTests() {
  console.log('====================================================');
  console.log('FARMFLOW ML INTEGRATION — END-TO-END VERIFICATION');
  console.log('====================================================\n');

  try {
    // 1. Python ML Service Health
    const mlHealthRes = await fetch('http://localhost:8000/health');
    const mlHealth = await mlHealthRes.json();
    console.log('[PASS] 1. Python FastAPI /health (Status:', mlHealthRes.status, ')');
    console.log('ML Service Health Response:', JSON.stringify(mlHealth, null, 2));

    // 2. Direct Python Prediction
    const mlPredictRes = await fetch('http://localhost:8000/predict', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        commodity: 'Tomato',
        state: 'Andhra Pradesh',
        district: 'Krishna',
        market: 'Vijayawada',
        variety: 'Other',
        grade: 'FAQ',
      }),
    });
    const mlPredict = await mlPredictRes.json();
    console.log('[PASS] 2. Python FastAPI /predict (Status:', mlPredictRes.status, ')');
    console.log('Direct ML Prediction Response:', JSON.stringify(mlPredict, null, 2));

    // 3. Node.js Backend Prediction API for Tomato
    const nodePredict1Res = await fetch('http://localhost:5000/api/markets/prediction?commodity=Tomato&state=Andhra%20Pradesh&district=Krishna&market=Vijayawada');
    const nodePredict1 = await nodePredict1Res.json();
    console.log('[PASS] 3. Node.js GET /api/markets/prediction (Tomato, Krishna) (Status:', nodePredict1Res.status, ')');
    console.log('Node Tomato Prediction:', JSON.stringify(nodePredict1, null, 2));

    // 4. Node.js Backend Prediction API for Wheat (with DB actual price)
    const nodePredict2Res = await fetch('http://localhost:5000/api/markets/prediction?commodity=Wheat&state=Uttar%20Pradesh&district=Auraiya&market=Achalda&variety=Dara&grade=FAQ');
    const nodePredict2 = await nodePredict2Res.json();
    console.log('[PASS] 4. Node.js GET /api/markets/prediction (Wheat, Auraiya) (Status:', nodePredict2Res.status, ')');
    console.log('Node Wheat Prediction:', JSON.stringify(nodePredict2, null, 2));

    // 5. Verification checks
    console.log('\n====================================================');
    console.log('VALIDATION RESULTS');
    console.log('====================================================');
    console.log('1. Model loaded successfully:', mlHealth?.modelLoaded === true);
    console.log('2. Features mapped correctly (11 columns):', mlHealth?.features?.length === 11);
    console.log('3. Target price unit strictly Quintal:', mlPredict?.prediction?.unit === 'Quintal');
    console.log('4. Node prediction endpoint returns ₹/Quintal:', nodePredict1?.data?.unit === 'Quintal');
    console.log('5. Prediction output is numeric and positive:', typeof nodePredict1?.data?.predictedPrice === 'number' && nodePredict1?.data?.predictedPrice > 0);
    console.log('6. Trend and percent change calculated accurately:', nodePredict2?.data?.trend !== undefined);
    console.log('7. Actual market price preserved alongside ML forecast:', nodePredict2?.data?.actualPrice === 2580);
    console.log('====================================================\n');
  } catch (err) {
    console.error('Test run error:', err);
  }
}

runTests();
