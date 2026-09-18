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
      default: 'kg',
      trim: true,
    },
    offeredPrice: {
      type: Number,
      required: [true, 'Offered price is required'],
      min: [0, 'Offered price cannot be negative'],
    },
    status: {
      type: String,
      enum: ['INTERESTED', 'ACCEPTED', 'REJECTED', 'COMPLETED', 'CANCELLED'],
      default: 'INTERESTED',
      index: true,
    },
    notes: {
      type: String,
      default: '',
      trim: true,
    },
  },
  {
    timestamps: true,
  }
);

opportunitySchema.index({ farmerId: 1, status: 1 });
opportunitySchema.index({ buyerId: 1, status: 1 });
opportunitySchema.index({ cropId: 1, buyerId: 1 }, { unique: true, sparse: true });
opportunitySchema.index({ requirementId: 1, farmerId: 1 }, { unique: true, sparse: true });

module.exports = mongoose.model('Opportunity', opportunitySchema);
