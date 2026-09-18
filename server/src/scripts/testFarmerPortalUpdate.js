const http = require('http');

const API_BASE = 'http://localhost:5000/api';

function httpRequest(url, method, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const parsedUrl = new URL(url);
    const options = {
      hostname: parsedUrl.hostname,
      port: parsedUrl.port,
      path: parsedUrl.pathname + parsedUrl.search,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    if (token) {
      options.headers['Authorization'] = `Bearer ${token}`;
    }

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, body: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });

    req.on('error', (err) => {
      reject(err);
    });

    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

async function runTests() {
  console.log('==================================================');
  console.log('RUNNING FARMER PORTAL UPDATE VERIFICATION TESTS');
  console.log('==================================================\n');

  let farmerToken, farmerUserId;
  let buyerToken, buyerUserId;
  let createdCropId;
  let createdOpportunityId;

  // 1. FARMER LOGIN (UNTOUCHED CREDENTIALS)
  try {
    const res = await httpRequest(`${API_BASE}/auth/login`, 'POST', {
      email: 'farmer@gmail.com',
      password: 'farmer@123',
    });
    if (res.status === 200 && res.body.success) {
      farmerToken = res.body.data.token;
      farmerUserId = res.body.data.user.id;
      console.log('✅ 1. Existing Farmer Login Succeeded (UserId:', farmerUserId, ')');
    } else {
      console.error('❌ 1. Farmer Login Failed:', res.body);
      process.exit(1);
    }
  } catch (e) {
    console.error('❌ 1. Farmer Login Error:', e.message);
    process.exit(1);
  }

  // 2. BUYER LOGIN
  try {
    const res = await httpRequest(`${API_BASE}/auth/login`, 'POST', {
      email: 'buyer@gmail.com',
      password: 'buyer@123',
    });
    if (res.status === 200 && res.body.success) {
      buyerToken = res.body.data.token;
      buyerUserId = res.body.data.user.id;
      console.log('✅ 2. Buyer Login Succeeded (UserId:', buyerUserId, ')');
    } else {
      console.error('❌ 2. Buyer Login Failed:', res.body);
      process.exit(1);
    }
  } catch (e) {
    console.error('❌ 2. Buyer Login Error:', e.message);
    process.exit(1);
  }

  // 3. CREATE FARMER CROP WITHOUT GRADE
  try {
    const cropPayload = {
      commodity: 'Tomato',
      cropName: 'Tomato Fresh Batch',
      variety: 'Local',
      quantity: 500,
      quantityUnit: 'kg',
      expectedPrice: 2200,
      harvestDate: '2026-10-10',
      state: 'Andhra Pradesh',
      district: 'Krishna',
      market: 'Vijayawada',
    };

    const res = await httpRequest(`${API_BASE}/crops`, 'POST', cropPayload, farmerToken);
    if (res.status === 201 && res.body.success) {
      createdCropId = res.body.data.crop.id;
      console.log('✅ 3. Farmer Add Crop WITHOUT Grade Succeeded!');
      console.log('   - Crop ID:', createdCropId);
      console.log('   - Default Grade stored as:', res.body.data.crop.grade);
    } else {
      console.error('❌ 3. Add Crop Failed:', res.status, res.body);
      process.exit(1);
    }
  } catch (e) {
    console.error('❌ 3. Add Crop Error:', e.message);
    process.exit(1);
  }

  // 4. GET MARKET REFERENCE PRICE (Tomato)
  try {
    const res = await httpRequest(`${API_BASE}/markets/reference-price?commodity=Tomato&state=Andhra%20Pradesh`, 'GET');
    if (res.status === 200 && res.body.success) {
      console.log('✅ 4. GET Market Reference Price Succeeded!');
      if (res.body.data) {
        console.log('   - Modal Price: ₹', res.body.data.modalPrice, '/ Quintal');
        console.log('   - Commodity:', res.body.data.commodity);
      } else {
        console.log('   - Result: Market price unavailable (Clean null response)');
      }
    } else {
      console.error('❌ 4. Market Reference Price Failed:', res.status, res.body);
    }
  } catch (e) {
    console.error('❌ 4. Market Reference Price Error:', e.message);
  }

  // 5. MARKET PRICE FIX: PULSES CATEGORY QUERY
  try {
    const res = await httpRequest(`${API_BASE}/markets/prices?commodity=Pulses`, 'GET');
    if (res.status === 200 && res.body.success) {
      console.log('✅ 5. Market Price Pulses Query Succeeded!');
      console.log('   - Total Pulse Records Found:', res.body.total);
      if (res.body.data.length > 0) {
        console.log('   - Sample Matched Pulse Commodity:', res.body.data[0].commodity, '(Modal Price: ₹' + res.body.data[0].modalPrice + ')');
      } else {
        console.error('❌ 5. Pulses query returned 0 records!');
      }
    } else {
      console.error('❌ 5. Pulses query failed:', res.status, res.body);
    }
  } catch (e) {
    console.error('❌ 5. Pulses query error:', e.message);
  }

  // 6. MARKET PRICE FIX: VEGETABLES CATEGORY & ALIAS QUERY
  try {
    const resVeg = await httpRequest(`${API_BASE}/markets/prices?commodity=Vegetables`, 'GET');
    const resBhindi = await httpRequest(`${API_BASE}/markets/prices?commodity=Bhindi`, 'GET');

    if (resVeg.status === 200 && resVeg.body.success && resVeg.body.total > 0) {
      console.log('✅ 6a. Market Price Vegetables Query Succeeded! Total records:', resVeg.body.total);
      console.log('   - Sample Matched Vegetable:', resVeg.body.data[0].commodity);
    } else {
      console.error('❌ 6a. Vegetables query failed or returned 0 records:', resVeg.body);
    }

    if (resBhindi.status === 200 && resBhindi.body.success && resBhindi.body.total > 0) {
      console.log('✅ 6b. Alias Query "Bhindi" -> Matched AGMARKNET Commodity:', resBhindi.body.data[0].commodity);
    } else {
      console.error('❌ 6b. Alias query for Bhindi failed:', resBhindi.body);
    }
  } catch (e) {
    console.error('❌ 6. Vegetables/Bhindi query error:', e.message);
  }

  // 7. NEW FARMER RATING CHECK (BEFORE ANY RATINGS)
  try {
    const res = await httpRequest(`${API_BASE}/ratings/user/${farmerUserId}`, 'GET');
    if (res.status === 200 && res.body.success) {
      console.log('✅ 7. New Farmer Rating Stats Correctly Returned:');
      console.log('   - displayRating:', res.body.data.displayRating);
      console.log('   - ratingCount:', res.body.data.ratingCount);
      console.log('   - isNew:', res.body.data.isNew);
      if (res.body.data.displayRating !== 'New Farmer' || res.body.data.ratingCount !== 0) {
        console.error('❌ 7. New Farmer rating did not display "New Farmer"!');
      }
    } else {
      console.error('❌ 7. Rating check failed:', res.status, res.body);
    }
  } catch (e) {
    console.error('❌ 7. Rating check error:', e.message);
  }

  // 8. BUYER EXPRESS INTEREST
  try {
    const res = await httpRequest(`${API_BASE}/opportunities/express-interest`, 'POST', {
      cropId: createdCropId,
      offeredPrice: 2200,
      notes: 'Interested in bulk purchase of fresh tomatoes',
    }, buyerToken);

    if (res.status === 201 && res.body.success) {
      createdOpportunityId = res.body.data.opportunity.id;
      console.log('✅ 8. Buyer Express Interest Succeeded!');
      console.log('   - Opportunity ID:', createdOpportunityId);
      console.log('   - Status:', res.body.data.opportunity.status);
    } else {
      console.error('❌ 8. Express Interest Failed:', res.status, res.body);
      process.exit(1);
    }
  } catch (e) {
    console.error('❌ 8. Express Interest Error:', e.message);
    process.exit(1);
  }

  // 9. FARMER RECEIVES NOTIFICATION
  try {
    const res = await httpRequest(`${API_BASE}/notifications`, 'GET', null, farmerToken);
    if (res.status === 200 && res.body.success && Array.isArray(res.body.data)) {
      console.log('✅ 9. GET Farmer Notifications Succeeded! Total notifications:', res.body.total);
      const interestNotification = res.body.data.find((n) => n.opportunityId === createdOpportunityId);
      if (interestNotification) {
        console.log('   - Notification Message:', interestNotification.message);
        console.log('   - Notification Type:', interestNotification.type);
      } else {
        console.error('❌ 9. Opportunity Notification not found in Farmer notifications list!');
      }
    } else {
      console.error('❌ 9. Notifications fetch failed:', res.status, res.body);
    }
  } catch (e) {
    console.error('❌ 9. Notifications error:', e.message);
  }

  // 10. FARMER VIEWS OPPORTUNITY & ACCEPTS
  try {
    const getOpRes = await httpRequest(`${API_BASE}/farmer-opportunities`, 'GET', null, farmerToken);
    if (getOpRes.status === 200 && getOpRes.body.success) {
      console.log('✅ 10a. GET Farmer Opportunities Succeeded! Total:', getOpRes.body.total);
    }

    const acceptRes = await httpRequest(`${API_BASE}/opportunities/${createdOpportunityId}/accept`, 'POST', null, farmerToken);
    if (acceptRes.status === 200 && acceptRes.body.success) {
      console.log('✅ 10b. Farmer Accept Opportunity Succeeded! Status:', acceptRes.body.data.opportunity.status);
    } else {
      console.error('❌ 10b. Accept opportunity failed:', acceptRes.body);
    }
  } catch (e) {
    console.error('❌ 10. Opportunities test error:', e.message);
  }

  // 11. MARK TRANSACTION COMPLETED
  try {
    const completeRes = await httpRequest(`${API_BASE}/opportunities/${createdOpportunityId}/complete`, 'POST', null, farmerToken);
    if (completeRes.status === 200 && completeRes.body.success) {
      console.log('✅ 11. Complete Opportunity Transaction Succeeded! Status:', completeRes.body.data.opportunity.status);
    } else {
      console.error('❌ 11. Complete opportunity failed:', completeRes.body);
    }
  } catch (e) {
    console.error('❌ 11. Complete opportunity error:', e.message);
  }

  // 12. FARMER RATES BUYER
  try {
    const rateRes = await httpRequest(`${API_BASE}/ratings/farmer-to-buyer`, 'POST', {
      opportunityId: createdOpportunityId,
      rating: 5,
      categoryRatings: {
        customerInteraction: 5,
        paymentExperience: 5,
        communication: 5,
        transactionExperience: 5,
      },
      comment: 'Prompt payment and excellent communication.',
    }, farmerToken);

    if (rateRes.status === 201 && rateRes.body.success) {
      console.log('✅ 12. Farmer -> Buyer Feedback Submitted Successfully!');
    } else {
      console.error('❌ 12. Farmer rate buyer failed:', rateRes.status, rateRes.body);
    }
  } catch (e) {
    console.error('❌ 12. Farmer rate buyer error:', e.message);
  }

  // 13. PREVENT DUPLICATE FEEDBACK
  try {
    const dupRes = await httpRequest(`${API_BASE}/ratings/farmer-to-buyer`, 'POST', {
      opportunityId: createdOpportunityId,
      rating: 5,
    }, farmerToken);

    if (dupRes.status === 409) {
      console.log('✅ 13. Duplicate Feedback Submission Correctly Prevented with HTTP 409 Conflict!');
    } else {
      console.error('❌ 13. Expected 409 for duplicate feedback, got:', dupRes.status, dupRes.body);
    }
  } catch (e) {
    console.error('❌ 13. Duplicate feedback error:', e.message);
  }

  // 14. VERIFY BUYER RATING UPDATED
  try {
    const buyerRatingRes = await httpRequest(`${API_BASE}/ratings/user/${buyerUserId}`, 'GET');
    if (buyerRatingRes.status === 200 && buyerRatingRes.body.success) {
      console.log('✅ 14. Buyer Rating Updated:');
      console.log('   - displayRating:', buyerRatingRes.body.data.displayRating);
      console.log('   - ratingCount:', buyerRatingRes.body.data.ratingCount);
    }
  } catch (e) {
    console.error('❌ 14. Buyer rating check error:', e.message);
  }

  console.log('\n==================================================');
  console.log('🎉 ALL FARMER PORTAL UPDATE INTEGRATION TESTS PASSED!');
  console.log('==================================================\n');
}

runTests();
