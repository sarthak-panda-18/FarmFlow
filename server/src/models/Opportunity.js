const mongoose = require('mongoose');

const opportunitySchema = new mongoose.Schema(
  {
    buyerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Buyer ID is required'],
      index: true,
    },
    farmerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Farmer ID is required'],
      index: true,
    },
    cropId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Crop',
      default: null,
      index: true,
    },
    requirementId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'BuyerRequirement',
      default: null,
      index: true,
    },
    commodity: {
      type: String,
      required: [true, 'Commodity name is required'],
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
        values: ['quintal'],
        message: 'Only quintal is supported as quantity unit',
      },
      default: 'quintal',
      trim: true,
      lowercase: true,
    },
    offeredPrice: {
      type: Number,
      required: [true, 'Offered price is required'],
      min: [0, 'Offered price cannot be negative'],
    },
    initiatedBy: {
      type: String,
      enum: ['FARMER', 'BUYER'],
      required: [true, 'Opportunity initiator is required'],
      default: 'BUYER',
      index: true,
    },
    status: {
      type: String,
      enum: ['PENDING', 'INTERESTED', 'ACCEPTED', 'REJECTED', 'CANCELLED', 'EXPIRED', 'CLOSED', 'COMPLETED'],
      default: 'PENDING',
      index: true,
    },
    notes: {
      type: String,
      default: '',
      trim: true,
    },
    transportCost: {
      type: Number,
      default: 0,
      min: [0, 'Transportation cost cannot be negative'],
    },
    otherCosts: {
      type: Number,
      default: 0,
      min: [0, 'Other costs cannot be negative'],
    },
    distanceKm: {
      type: Number,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

opportunitySchema.index({ farmerId: 1, status: 1 });
opportunitySchema.index({ buyerId: 1, status: 1 });
opportunitySchema.index({ cropId: 1, requirementId: 1 });
opportunitySchema.index({ farmerId: 1, buyerId: 1, status: 1 });
opportunitySchema.index({ createdAt: -1 });

module.exports = mongoose.model('Opportunity', opportunitySchema);

