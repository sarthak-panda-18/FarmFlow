const mongoose = require('mongoose');

const farmerCropSchema = new mongoose.Schema(
  {
    farmerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Farmer ID is required'],
    },
    crop: {
      type: String,
      required: [true, 'Crop name is required'],
      trim: true,
    },
    quantity: {
      type: Number,
      required: [true, 'Quantity is required'],
      min: [0.01, 'Quantity must be greater than zero'],
    },
    latitude: {
      type: Number,
      default: null,
    },
    longitude: {
      type: Number,
      default: null,
    },
    location: {
      type: String,
      trim: true,
      default: '',
    },
    shelfLifeDays: {
      type: Number,
      required: [true, 'Shelf life in days is required'],
      min: [0, 'Shelf life cannot be negative'],
    },
    harvestDate: {
      type: Date,
      default: Date.now,
    },
    quality: {
      type: String,
      trim: true,
      default: 'Standard',
    },
    variety: {
      type: String,
      trim: true,
      default: 'General',
    },
    grade: {
      type: String,
      trim: true,
      default: 'Grade A',
    },
    status: {
      type: String,
      enum: {
        values: ['AVAILABLE', 'SOLD', 'RESERVED', 'EXPIRED'],
        message: 'Status must be AVAILABLE, SOLD, RESERVED, or EXPIRED',
      },
      default: 'AVAILABLE',
    },
  },
  {
    timestamps: true,
  }
);

farmerCropSchema.index({ farmerId: 1 });
farmerCropSchema.index({ crop: 1 });

module.exports = mongoose.model('FarmerCrop', farmerCropSchema);
