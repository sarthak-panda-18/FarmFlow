require('dotenv').config({ path: __dirname + '/../../.env' });

const BASE_URL = process.env.API_BASE_URL || 'http://localhost:5000/api';

const post = async (url, data, token) => {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(url, {
    method: 'POST',
    headers,
    body: JSON.stringify(data),
  });
  const body = await res.json();
  return { status: res.status, data: body };
};

const patch = async (url, data, token) => {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers,
    body: JSON.stringify(data),
  });
  const body = await res.json();
  return { status: res.status, data: body };
};

const runTests = async () => {
  console.log('==================================================');
  console.log('STARTING BACKEND AUTH & VERIFICATION SYSTEM TESTS');
  console.log('==================================================\n');

  try {
    // Test 1: Farmer Registration without Email
    console.log('[TEST 1] Registering new Farmer without email...');
    const farmerPhone = `98700${Math.floor(10000 + Math.random() * 90000)}`;
    const farmerReg = await post(`${BASE_URL}/auth/register`, {
      name: 'Test Farmer Verification',
      phone: farmerPhone,
      password: 'password123',
      role: 'FARMER',
    });

    console.log('✓ Registration response status:', farmerReg.status);
    console.log('✓ User payload:', farmerReg.data.data.user);
    if (farmerReg.data.data.user.email) {
      throw new Error('FAIL: Email field was returned for Farmer registration!');
    }
    if (farmerReg.data.data.user.phoneVerified !== false) {
      throw new Error('FAIL: Farmer phoneVerified should be false initially!');
    }
    if (farmerReg.data.data.user.verificationStatus !== 'PENDING') {
      throw new Error('FAIL: Farmer verificationStatus should be PENDING initially!');
    }
    console.log('✓ Test 1 Passed: Farmer registered without email, phoneVerified=false, verificationStatus=PENDING\n');

    const farmerToken = farmerReg.data.data.token;
    const farmerUserId = farmerReg.data.data.user.id;
    const normalizedFarmerPhone = farmerReg.data.data.user.phone;

    // Test 2: Unverified Farmer attempts crop creation (Expect 403)
    console.log('[TEST 2] Testing unverified Farmer crop creation (Expecting 403)...');
    const unverifiedCropRes = await post(
      `${BASE_URL}/crops`,
      {
        commodity: 'Wheat',
        cropName: 'Unverified Test Wheat',
        quantity: 100,
        quantityUnit: 'quintal',
        expectedPrice: 2200,
        harvestDate: '2026-10-01',
        state: 'Punjab',
        district: 'Ludhiana',
      },
      farmerToken
    );

    if (unverifiedCropRes.status === 403) {
      console.log('✓ Test 2 Passed: 403 Forbidden correctly returned for unverified crop creation.\n');
    } else {
      throw new Error(`FAIL: Expected status 403 for unverified crop creation, got ${unverifiedCropRes.status}`);
    }

    // Test 3: Send & Verify Mobile OTP
    console.log('[TEST 3] Sending and Verifying OTP for Farmer...');
    const sendOtpRes = await post(`${BASE_URL}/auth/send-otp`, { phone: normalizedFarmerPhone });
    console.log('✓ Send OTP response:', sendOtpRes.data.message);
    const devOtp = sendOtpRes.data.data.devOtp;
    if (!devOtp) {
      throw new Error('FAIL: devOtp not provided in response for mock OTP testing!');
    }

    const verifyOtpRes = await post(`${BASE_URL}/auth/verify-otp`, {
      phone: normalizedFarmerPhone,
      otp: devOtp,
    });
    console.log('✓ Verify OTP response:', verifyOtpRes.data.message);
    if (verifyOtpRes.data.data.phoneVerified !== true) {
      throw new Error('FAIL: phoneVerified was not updated to true after OTP verification!');
    }
    console.log('✓ Test 3 Passed: Phone OTP verified successfully (phoneVerified=true)\n');

    // Test 4: Submit Farmer Verification ID
    console.log('[TEST 4] Submitting Farmer Verification ID...');
    const farmerVerRes = await post(
      `${BASE_URL}/verification/farmer`,
      { farmerId: 'FARM-AG-998877' },
      farmerToken
    );
    console.log('✓ Farmer verification submission response:', farmerVerRes.data.message);
    if (farmerVerRes.data.data.verificationStatus !== 'PENDING') {
      throw new Error('FAIL: Submission should maintain verificationStatus as PENDING until reviewed!');
    }
    console.log('✓ Test 4 Passed: Farmer verification submitted with status PENDING\n');

    // Test 5: Admin Approves Farmer Verification
    console.log('[TEST 5] Admin approving Farmer verification status...');
    const adminApproveRes = await patch(
      `${BASE_URL}/verification/admin/user/${farmerUserId}/status`,
      { status: 'VERIFIED' },
      farmerToken
    );
    console.log('✓ Admin approve response:', adminApproveRes.data.message);
    if (adminApproveRes.data.data.verificationStatus !== 'VERIFIED') {
      throw new Error('FAIL: Verification status was not updated to VERIFIED!');
    }
    console.log('✓ Test 5 Passed: Account verification approved (verificationStatus=VERIFIED)\n');

    // Test 6: Verified Farmer creates crop (Expect 201)
    console.log('[TEST 6] Testing verified Farmer crop creation (Expecting 201)...');
    const cropRes = await post(
      `${BASE_URL}/crops`,
      {
        commodity: 'Wheat',
        cropName: 'Verified Organic Wheat',
        quantity: 50,
        quantityUnit: 'quintal',
        expectedPrice: 2400,
        harvestDate: '2026-10-15',
        state: 'Punjab',
        district: 'Ludhiana',
      },
      farmerToken
    );
    if (cropRes.status !== 201) {
      throw new Error(`FAIL: Expected status 201 for verified crop creation, got ${cropRes.status}`);
    }
    console.log('✓ Crop created successfully:', cropRes.data.data.crop.id);
    console.log('✓ Test 6 Passed: Verified Farmer successfully created crop listing!\n');

    // Test 7: Buyer Registration, OTP, Business Verification, Role Enforcement
    console.log('[TEST 7] Testing Buyer Registration, OTP, Business Verification & Role Enforcement...');
    const buyerPhone = `98600${Math.floor(10000 + Math.random() * 90000)}`;
    const buyerReg = await post(`${BASE_URL}/auth/register`, {
      name: 'Test Buyer Wholesaler',
      phone: buyerPhone,
      password: 'buyerpassword123',
      role: 'BUYER',
    });

    const buyerToken = buyerReg.data.data.token;
    const buyerUserId = buyerReg.data.data.user.id;
    const normalizedBuyerPhone = buyerReg.data.data.user.phone;

    // Buyer attempts Farmer endpoint (Expect 403)
    const buyerFarmerVerRes = await post(
      `${BASE_URL}/verification/farmer`,
      { farmerId: 'FAKE-ID' },
      buyerToken
    );
    if (buyerFarmerVerRes.status === 403) {
      console.log('✓ Role authorization check passed: Buyer blocked from Farmer verification endpoint.');
    } else {
      throw new Error(`FAIL: Expected status 403 for Buyer accessing Farmer verification, got ${buyerFarmerVerRes.status}`);
    }

    // Buyer verifies OTP
    const buyerOtpRes = await post(`${BASE_URL}/auth/send-otp`, { phone: normalizedBuyerPhone });
    await post(`${BASE_URL}/auth/verify-otp`, {
      phone: normalizedBuyerPhone,
      otp: buyerOtpRes.data.data.devOtp,
    });

    // Buyer submits business verification
    const buyerVerRes = await post(
      `${BASE_URL}/verification/buyer`,
      {
        businessName: 'Global Agri Exports',
        businessType: 'EXPORTER',
        registrationIdentifier: 'GSTIN33XYZ1234F9Z9',
      },
      buyerToken
    );
    console.log('✓ Buyer business verification submitted:', buyerVerRes.data.message);

    // Approve Buyer
    await patch(
      `${BASE_URL}/verification/admin/user/${buyerUserId}/status`,
      { status: 'VERIFIED' },
      buyerToken
    );

    // Verified Buyer creates requirement
    const reqRes = await post(
      `${BASE_URL}/requirements`,
      {
        commodity: 'Wheat',
        cropName: 'Verified Organic Wheat',
        quantity: 100,
        quantityUnit: 'quintal',
        offeredPrice: 2450,
        requiredByDate: '2026-11-01',
        state: 'Punjab',
        district: 'Ludhiana',
      },
      buyerToken
    );
    if (reqRes.status !== 201) {
      throw new Error(`FAIL: Expected status 201 for verified requirement creation, got ${reqRes.status} (msg: ${reqRes.data.message})`);
    }
    console.log('✓ Requirement created successfully by verified buyer:', reqRes.data.data.requirement ? reqRes.data.data.requirement.id : 'created');
    console.log('✓ Test 7 Passed: Buyer workflow & role separation verified.\n');

    console.log('==================================================');
    console.log('ALL BACKEND AUTH & VERIFICATION TESTS PASSED 100%!');
    console.log('==================================================');
  } catch (error) {
    console.error('\n❌ BACKEND TEST ERROR:', error.message);
    process.exit(1);
  }
};

runTests();
