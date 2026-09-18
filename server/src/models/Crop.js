const mongoose = require('mongoose');

const cropSchema = new mongoose.Schema(
  {
    farmerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Farmer ID is required'],
      index: true,
    },
    commodity: {
      type: String,
      required: [true, 'Commodity is required'],
      trim: true,
    },
    cropName: {
      type: String,
      required: [true, 'Crop name is required'],
      trim: true,
    },
    variety: {
      type: String,
      default: 'Other',
      trim: true,
    },
    grade: {
      type: String,
      default: 'FAQ',
      trim: true,
    },
    quantity: {
      type: Number,
      required: [true, 'Quantity is required'],
      min: [0.01, 'Quantity must be greater than zero'],
    },
    quantityUnit: {
      type: String,
      enum: {
        values: ['kg', 'quintal', 'tonne'],
        message: 'Unit must be kg, quintal, or tonne',
      },
      required: [true, 'Quantity unit is required'],
    },
    expectedPrice: {
      type: Number,
      default: 0,
      min: [0, 'Expected price cannot be negative'],
    },
    harvestDate: {
      type: Date,
      required: [true, 'Harvest date is required'],
    },
    state: {
      type: String,
      required: [true, 'State is required'],
      trim: true,
    },
    district: {
      type: String,
      required: [true, 'District is required'],
      trim: true,
    },
    market: {
      type: String,
      default: '',
      trim: true,
    },
    location: {
      type: String,
      default: '',
      trim: true,
    },
    locationCoordinates: {
      type: {
        type: String,
        enum: ['Point'],
      },
      coordinates: {
        type: [Number], // [longitude, latitude]
      },
    },
    description: {
      type: String,
      maxlength: [500, 'Description cannot exceed 500 characters'],
      default: '',
      trim: true,
    },
    status: {
      type: String,
      enum: {
        values: ['AVAILABLE', 'RESERVED', 'SOLD', 'CANCELLED'],
        message: 'Status must be AVAILABLE, RESERVED, SOLD, or CANCELLED',
      },
      default: 'AVAILABLE',
    },
  },
  {
    timestamps: true,
  }
);

cropSchema.index({ farmerId: 1, createdAt: -1 });
cropSchema.index({ farmerId: 1, status: 1 });
cropSchema.index({ locationCoordinates: '2dsphere' }, { sparse: true });

module.exports = mongoose.model('Crop', cropSchema);
