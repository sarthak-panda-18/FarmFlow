require('dotenv').config({ path: __dirname + '/../../.env' });
const mongoose = require('mongoose');
const User = require('../models/User');
const { hashPassword } = require('../utils/password');
const { normalizePhone } = require('../utils/otpService');

const seedUsers = async () => {
  const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/farm-to-market';

  try {
    console.log('Connecting to MongoDB for seeding...');
    await mongoose.connect(mongoUri);
    console.log('Connected to MongoDB.');

    // Seed Farmer Account
    const farmerEmail = 'farmer@gmail.com';
    const farmerPhone = normalizePhone('9876543210');
    const farmerPasswordHash = await hashPassword('farmer@123');

    let farmer = await User.findOne({ $or: [{ email: farmerEmail }, { phone: farmerPhone }] });
    if (!farmer) {
      farmer = await User.create({
        name: 'Demo Farmer',
        email: farmerEmail,
        phone: farmerPhone,
        passwordHash: farmerPasswordHash,
        role: 'FARMER',
        phoneVerified: true,
        verificationStatus: 'VERIFIED',
        verificationType: 'FARMER',
        verificationId: 'FARM-ID-SEED-987',
      });
      console.log(`[SEED SUCCESS] Created Test Farmer Account: ${farmerEmail} / ${farmerPhone}`);
    } else {
      farmer.passwordHash = farmerPasswordHash;
      farmer.phone = farmerPhone;
      farmer.phoneVerified = true;
      farmer.verificationStatus = 'VERIFIED';
      farmer.verificationType = 'FARMER';
      if (!farmer.verificationId) farmer.verificationId = 'FARM-ID-SEED-987';
      await farmer.save();
      console.log(`[SEED UPDATED] Test Farmer Account updated: ${farmerEmail} / ${farmerPhone}`);
    }

    // Seed Buyer Account
    const buyerEmail = 'buyer@gmail.com';
    const buyerPhone = normalizePhone('9876543211');
    const buyerPasswordHash = await hashPassword('buyer@123');

    let buyer = await User.findOne({ $or: [{ email: buyerEmail }, { phone: buyerPhone }] });
    if (!buyer) {
      buyer = await User.create({
        name: 'Demo Buyer',
        email: buyerEmail,
        phone: buyerPhone,
        passwordHash: buyerPasswordHash,
        role: 'BUYER',
        phoneVerified: true,
        verificationStatus: 'VERIFIED',
        verificationType: 'BUYER',
        businessName: 'AgroProcure Traders',
        businessType: 'WHOLESALER',
        verificationId: 'GSTIN29ABCDE1234F1Z5',
      });
      console.log(`[SEED SUCCESS] Created Test Buyer Account: ${buyerEmail} / ${buyerPhone}`);
    } else {
      buyer.passwordHash = buyerPasswordHash;
      buyer.phone = buyerPhone;
      buyer.phoneVerified = true;
      buyer.verificationStatus = 'VERIFIED';
      buyer.verificationType = 'BUYER';
      if (!buyer.businessName) buyer.businessName = 'AgroProcure Traders';
      if (!buyer.businessType) buyer.businessType = 'WHOLESALER';
      if (!buyer.verificationId) buyer.verificationId = 'GSTIN29ABCDE1234F1Z5';
      await buyer.save();
      console.log(`[SEED UPDATED] Test Buyer Account updated: ${buyerEmail} / ${buyerPhone}`);
    }

    console.log('Seeding completed successfully.');
    await mongoose.connection.close();
    process.exit(0);
  } catch (error) {
    console.error('Seeding error:', error.message);
    if (mongoose.connection.readyState !== 0) {
      await mongoose.connection.close();
    }
    process.exit(1);
  }
};

seedUsers();
