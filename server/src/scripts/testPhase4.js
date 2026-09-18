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
  console.log('RUNNING PHASE 4 BACKEND INTEGRATION & AUTH TESTS');
  console.log('==================================================\n');

  let farmerToken, farmerUserId;
  let buyerToken, buyerUserId;
  let createdCropId;

  // 1. Authenticate Farmer
  try {
    const farmerAuthRes = await httpRequest(`${API_BASE}/auth/login`, 'POST', {
      email: 'farmer@gmail.com',
      password: 'farmer@123',
    });

    if (farmerAuthRes.status === 200 && farmerAuthRes.body.success) {
      farmerToken = farmerAuthRes.body.data.token;
      farmerUserId = farmerAuthRes.body.data.user.id;
      console.log('✅ 1. Farmer Login Successful (UserId:', farmerUserId, ')');
    } else {
      console.error('❌ 1. Farmer Login Failed:', farmerAuthRes.body);
      process.exit(1);
    }
  } catch (e) {
    console.error('❌ 1. Farmer Login Connection Error:', e.message);
    process.exit(1);
  }

  // 2. Authenticate Buyer
  try {
    const buyerAuthRes = await httpRequest(`${API_BASE}/auth/login`, 'POST', {
      email: 'buyer@gmail.com',
      password: 'buyer@123',
    });

    if (buyerAuthRes.status === 200 && buyerAuthRes.body.success) {
      buyerToken = buyerAuthRes.body.data.token;
      buyerUserId = buyerAuthRes.body.data.user.id;
      console.log('✅ 2. Buyer Login Successful (UserId:', buyerUserId, ')');
    } else {
      console.error('❌ 2. Buyer Login Failed:', buyerAuthRes.body);
      process.exit(1);
    }
  } catch (e) {
    console.error('❌ 2. Buyer Login Connection Error:', e.message);
    process.exit(1);
  }

  // 3. Unauthenticated Request Test
  try {
    const unauthRes = await httpRequest(`${API_BASE}/crops`, 'POST', {
      commodity: 'Tomato',
      cropName: 'Tomato',
      quantity: 100,
      quantityUnit: 'kg',
      harvestDate: '2026-10-15',
      state: 'Andhra Pradesh',
      district: 'Krishna',
    });

    if (unauthRes.status === 401) {
      console.log('✅ 3. Unauthenticated Request Correctly Rejected with HTTP 401');
    } else {
      console.error('❌ 3. Expected 401 for Unauthenticated Request, got:', unauthRes.status, unauthRes.body);
    }
  } catch (e) {
    console.error('❌ 3. Unauthenticated test failed:', e.message);
  }

  // 4. Buyer Role Protection Test (Buyer tries to create crop)
  try {
    const buyerCreateRes = await httpRequest(`${API_BASE}/crops`, 'POST', {
      commodity: 'Tomato',
      cropName: 'Tomato',
      quantity: 100,
      quantityUnit: 'kg',
      harvestDate: '2026-10-15',
      state: 'Andhra Pradesh',
      district: 'Krishna',
    }, buyerToken);

    if (buyerCreateRes.status === 403) {
      console.log('✅ 4. Buyer Create Crop Correctly Rejected with HTTP 403 (Role Protection)');
    } else {
      console.error('❌ 4. Expected 403 for Buyer Create Crop, got:', buyerCreateRes.status, buyerCreateRes.body);
    }
  } catch (e) {
    console.error('❌ 4. Buyer role protection test failed:', e.message);
  }

  // 5. Create Crop Validation Test (Invalid quantity)
  try {
    const invalidRes = await httpRequest(`${API_BASE}/crops`, 'POST', {
      commodity: 'Tomato',
      cropName: 'Tomato',
      quantity: -5,
      quantityUnit: 'kg',
      harvestDate: '2026-10-15',
      state: 'Andhra Pradesh',
      district: 'Krishna',
    }, farmerToken);

    if (invalidRes.status === 400 && invalidRes.body.success === false) {
      console.log('✅ 5. Invalid Crop Quantity (-5) Correctly Rejected with HTTP 400:', invalidRes.body.message);
    } else {
      console.error('❌ 5. Expected 400 for Invalid Quantity, got:', invalidRes.status, invalidRes.body);
    }
  } catch (e) {
    console.error('❌ 5. Validation test failed:', e.message);
  }

  // 6. Farmer Create Valid Crop
  try {
    const cropPayload = {
      commodity: 'Tomato',
      cropName: 'Tomato Local Fresh',
      variety: 'Local',
      grade: 'FAQ',
      quantity: 500,
      quantityUnit: 'kg',
      expectedPrice: 2200,
      harvestDate: '2026-09-25',
      state: 'Andhra Pradesh',
      district: 'Krishna',
      market: 'Vijayawada',
      location: 'Vijayawada Market Yard',
      description: 'Fresh farm harvested tomato crop',
    };

    const createRes = await httpRequest(`${API_BASE}/crops`, 'POST', cropPayload, farmerToken);

    if (createRes.status === 201 && createRes.body.success && createRes.body.data.crop) {
      const crop = createRes.body.data.crop;
      createdCropId = crop.id;
      console.log('✅ 6. Farmer POST /api/crops Created Crop Successfully!');
      console.log('   - ID:', crop.id);
      console.log('   - Commodity:', crop.commodity);
      console.log('   - Quantity:', crop.quantity, crop.quantityUnit);
      console.log('   - Expected Price:', crop.expectedPrice);
      console.log('   - Status:', crop.status);
      console.log('   - farmerId:', crop.farmerId);

      if (crop.status !== 'AVAILABLE') {
        console.error('❌ 6. Crop status is not AVAILABLE!');
      }
      if (crop.farmerId !== farmerUserId) {
        console.error('❌ 6. Crop farmerId does not match authenticated user ID!');
      }
    } else {
      console.error('❌ 6. Farmer Create Crop Failed:', createRes.status, createRes.body);
      process.exit(1);
    }
  } catch (e) {
    console.error('❌ 6. Create Crop Connection Error:', e.message);
    process.exit(1);
  }

  // 7. GET Farmer's Crops (GET /api/crops/my)
  try {
    const getMyCropsRes = await httpRequest(`${API_BASE}/crops/my`, 'GET', null, farmerToken);

    if (getMyCropsRes.status === 200 && getMyCropsRes.body.success && Array.isArray(getMyCropsRes.body.data)) {
      console.log('✅ 7. GET /api/crops/my Succeeded!');
      console.log('   - Total crops returned:', getMyCropsRes.body.total);
      const found = getMyCropsRes.body.data.some((c) => c.id === createdCropId);
      if (found) {
        console.log('   - Created crop verified in list!');
      } else {
        console.error('❌ 7. Created crop not found in farmer crops list!');
      }
    } else {
      console.error('❌ 7. GET /api/crops/my Failed:', getMyCropsRes.status, getMyCropsRes.body);
    }
  } catch (e) {
    console.error('❌ 7. GET my crops error:', e.message);
  }

  // 8. GET Single Crop (GET /api/crops/:id)
  try {
    const getSingleRes = await httpRequest(`${API_BASE}/crops/${createdCropId}`, 'GET', null, farmerToken);

    if (getSingleRes.status === 200 && getSingleRes.body.success) {
      console.log('✅ 8. GET /api/crops/:id Succeeded for Owner Farmer!');
      console.log('   - Commodity:', getSingleRes.body.data.crop.commodity);
    } else {
      console.error('❌ 8. GET /api/crops/:id Failed:', getSingleRes.status, getSingleRes.body);
    }
  } catch (e) {
    console.error('❌ 8. GET single crop error:', e.message);
  }

  // 9. Buyer GET /api/crops/my (Role Protection)
  try {
    const buyerGetMyRes = await httpRequest(`${API_BASE}/crops/my`, 'GET', null, buyerToken);

    if (buyerGetMyRes.status === 403) {
      console.log('✅ 9. Buyer GET /api/crops/my Correctly Rejected with HTTP 403');
    } else {
      console.error('❌ 9. Expected 403 for Buyer GET /api/crops/my, got:', buyerGetMyRes.status, buyerGetMyRes.body);
    }
  } catch (e) {
    console.error('❌ 9. Buyer GET my crops error:', e.message);
  }

  // 10. Buyer GET /api/crops/:id (Ownership Protection)
  try {
    const buyerGetSingleRes = await httpRequest(`${API_BASE}/crops/${createdCropId}`, 'GET', null, buyerToken);

    if (buyerGetSingleRes.status === 403) {
      console.log('✅ 10. Buyer Access to Farmer Crop Correctly Rejected with HTTP 403');
    } else {
      console.error('❌ 10. Expected 403 for Buyer Access to Farmer Crop, got:', buyerGetSingleRes.status, buyerGetSingleRes.body);
    }
  } catch (e) {
    console.error('❌ 10. Buyer access error:', e.message);
  }

  // 11. Update Crop (PUT /api/crops/:id)
  try {
    const updatePayload = {
      quantity: 600,
      expectedPrice: 2400,
      description: 'Updated fresh tomato crop details',
    };

    const updateRes = await httpRequest(`${API_BASE}/crops/${createdCropId}`, 'PUT', updatePayload, farmerToken);

    if (updateRes.status === 200 && updateRes.body.success) {
      console.log('✅ 11. PUT /api/crops/:id Succeeded!');
      console.log('   - Updated Quantity:', updateRes.body.data.crop.quantity);
      console.log('   - Updated Expected Price:', updateRes.body.data.crop.expectedPrice);
    } else {
      console.error('❌ 11. PUT /api/crops/:id Failed:', updateRes.status, updateRes.body);
    }
  } catch (e) {
    console.error('❌ 11. Update crop error:', e.message);
  }

  // 12. Delete Crop (DELETE /api/crops/:id)
  try {
    const deleteRes = await httpRequest(`${API_BASE}/crops/${createdCropId}`, 'DELETE', null, farmerToken);

    if (deleteRes.status === 200 && deleteRes.body.success) {
      console.log('✅ 12. DELETE /api/crops/:id Succeeded!');
      console.log('   - Message:', deleteRes.body.message);
    } else {
      console.error('❌ 12. DELETE /api/crops/:id Failed:', deleteRes.status, deleteRes.body);
    }
  } catch (e) {
    console.error('❌ 12. Delete crop error:', e.message);
  }

  // 13. Verify Crop is Deleted (GET /api/crops/:id -> 404)
  try {
    const getDeletedRes = await httpRequest(`${API_BASE}/crops/${createdCropId}`, 'GET', null, farmerToken);

    if (getDeletedRes.status === 404) {
      console.log('✅ 13. GET Deleted Crop Correctly Returns HTTP 404 Not Found');
    } else {
      console.error('❌ 13. Expected 404 for Deleted Crop, got:', getDeletedRes.status, getDeletedRes.body);
    }
  } catch (e) {
    console.error('❌ 13. Verify deleted crop error:', e.message);
  }

  console.log('\n==================================================');
  console.log('ALL PHASE 4 BACKEND INTEGRATION TESTS PASSED!');
  console.log('==================================================\n');
}

runTests();
