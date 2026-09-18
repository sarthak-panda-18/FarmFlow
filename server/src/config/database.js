const mongoose = require('mongoose');

// Disable Mongoose query buffering so disconnected DB causes immediate error instead of hanging HTTP requests
mongoose.set('bufferCommands', false);

const connectDB = async () => {
  const mongoUri = process.env.MONGODB_URI;

  if (!mongoUri || mongoUri.includes('YOUR_MONGODB_CONNECTION_STRING')) {
    console.error('FATAL: Invalid or missing MONGODB_URI environment variable.');
    return false;
  }

  try {
    const conn = await mongoose.connect(mongoUri, {
      serverSelectionTimeoutMS: 5000, // Fail after 5 seconds if MongoDB server is unreachable
    });
    console.log(`[DB SUCCESS] MongoDB Connected: ${conn.connection.host}`);

    // Ensure 2dsphere and compound indexes are synced
    try {
      const User = require('../models/User');
      const Crop = require('../models/Crop');
      const BuyerRequirement = require('../models/BuyerRequirement');
      const MarketPrice = require('../models/MarketPrice');

      await User.updateMany({ 'location.coordinates': { $exists: false } }, { $unset: { location: 1 } });
      await Crop.updateMany({ 'locationCoordinates.coordinates': { $exists: false } }, { $unset: { locationCoordinates: 1 } });
      await BuyerRequirement.updateMany({ 'locationCoordinates.coordinates': { $exists: false } }, { $unset: { locationCoordinates: 1 } });

      await Promise.allSettled([
        User.syncIndexes(),
        Crop.syncIndexes(),
        BuyerRequirement.syncIndexes(),
        MarketPrice.syncIndexes(),
      ]);
    } catch (_) {}

    return true;
  } catch (error) {
    console.error(`[DB ERROR] MongoDB Connection Failed: ${error.message}`);
    return false;
  }
};

const getDBStatus = () => {
  const readyState = mongoose.connection.readyState;
  switch (readyState) {
    case 1:
      return 'connected';
    case 2:
      return 'connecting';
    case 3:
      return 'disconnecting';
    default:
      return 'disconnected';
  }
};

module.exports = { connectDB, getDBStatus };
