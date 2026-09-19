const mongoose = require('mongoose');

const buyerRequirementSchema = new mongoose.Schema(
  {
    buyerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Buyer ID is required'],
    },
    commodity: {
      type: String,
      required: [true, 'Commodity name is required'],
      trim: true,
    },
    cropName: {
      type: String,
      trim: true,
      default: function () {
        return this.commodity;
      },
    },
    variety: {
      type: String,
      trim: true,
      default: 'Not specified',
    },
    grade: {
      type: String,
      trim: true,
      default: 'Not specified',
    },
    quantity: {
      type: Number,
      required: [true, 'Required quantity is required'],
      min: [0.01, 'Quantity must be greater than zero'],
    },
    quantityUnit: {
      type: String,
      enum: {
        values: ['quintal'],
        message: 'Only quintal is supported as quantity unit',
      },
      default: 'quintal',
      lowercase: true,
      trim: true,
    },
    offeredPrice: {
      type: Number,
      required: [true, 'Offered price is required'],
      min: [0, 'Offered price cannot be negative'],
    },
    requiredByDate: {
      type: Date,
      required: [true, 'Required-by date is required'],
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
      trim: true,
      default: '',
    },
    location: {
      type: String,
      trim: true,
      default: '',
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
    notes: {
      type: String,
      trim: true,
      maxlength: [500, 'Notes cannot exceed 500 characters'],
      default: '',
    },
    status: {
      type: String,
      enum: {
        values: ['ACTIVE', 'FULFILLED', 'CANCELLED', 'EXPIRED'],
        message: 'Status must be ACTIVE, FULFILLED, CANCELLED, or EXPIRED',
      },
      default: 'ACTIVE',
    },
  },
  {
    timestamps: true,
  }
);

buyerRequirementSchema.index({ buyerId: 1 });
buyerRequirementSchema.index({ buyerId: 1, status: 1 });
buyerRequirementSchema.index({ buyerId: 1, createdAt: -1 });
buyerRequirementSchema.index({ commodity: 1, status: 1 });
buyerRequirementSchema.index({ commodity: 1, requiredByDate: 1 });
buyerRequirementSchema.index({ locationCoordinates: '2dsphere' }, { sparse: true });

module.exports = mongoose.model('BuyerRequirement', buyerRequirementSchema);
