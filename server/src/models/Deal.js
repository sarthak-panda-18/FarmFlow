const mongoose = require('mongoose');

const dealSchema = new mongoose.Schema(
  {
    farmerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Farmer ID is required'],
      index: true,
    },
    buyerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Buyer ID is required'],
      index: true,
    },
    opportunityId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Opportunity',
      required: [true, 'Opportunity ID is required'],
      index: true,
    },
    farmerCropId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Crop',
      default: null,
    },
    cropId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Crop',
      default: null,
    },
    buyerRequirementId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'BuyerRequirement',
      default: null,
    },
    requirementId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'BuyerRequirement',
      default: null,
    },

    // Deal & Commodity Details
    commodity: {
      type: String,
      required: [true, 'Commodity/crop name is required'],
      trim: true,
    },
    crop: {
      type: String,
      trim: true,
    },
    variety: {
      type: String,
      default: '',
      trim: true,
    },
    quantity: {
      type: Number,
      required: [true, 'Agreed quantity is required'],
      min: [0.01, 'Quantity must be greater than zero'],
    },
    quantityUnit: {
      type: String,
      default: 'kg',
      trim: true,
    },
    agreedPrice: {
      type: Number,
      required: [true, 'Agreed unit price is required'],
      min: [0, 'Agreed price cannot be negative'],
    },
    agreedPriceUnit: {
      type: String,
      default: 'quintal',
      trim: true,
    },
    totalAmount: {
      type: Number,
      required: true,
      default: 0,
    },
    agreedDate: {
      type: Date,
      default: Date.now,
    },
    deliveryDate: {
      type: Date,
      default: null,
    },

    // Deal Lifecycle Status
    status: {
      type: String,
      enum: [
        'CONFIRMED',
        'PREPARING',
        'READY_FOR_PICKUP',
        'IN_TRANSIT',
        'DELIVERED',
        'PAYMENT_PENDING',
        'COMPLETED',
        'CANCELLED',
        'DISPUTED',
      ],
      default: 'CONFIRMED',
      index: true,
    },
    cancellationReason: {
      type: String,
      trim: true,
      default: null,
    },
    cancelledBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    cancelledAt: {
      type: Date,
      default: null,
    },

    // Phase 11: Logistics Details
    pickupLocation: {
      address: { type: String, default: '' },
      latitude: { type: Number, default: null },
      longitude: { type: Number, default: null },
    },
    deliveryLocation: {
      address: { type: String, default: '' },
      latitude: { type: Number, default: null },
      longitude: { type: Number, default: null },
    },
    distanceKm: {
      type: Number,
      default: null,
    },
    transportRequired: {
      type: Boolean,
      default: true,
    },
    transportType: {
      type: String,
      default: 'Standard Road Transport',
      trim: true,
    },
    transportCost: {
      type: Number,
      default: 0,
      min: 0,
    },
    otherCosts: {
      type: Number,
      default: 0,
      min: 0,
    },
    otherCostsBreakdown: {
      packaging: { type: Number, default: 0 },
      loading: { type: Number, default: 0 },
      unloading: { type: Number, default: 0 },
      handling: { type: Number, default: 0 },
    },
    logisticsStatus: {
      type: String,
      enum: ['NOT_PLANNED', 'PLANNED', 'READY', 'IN_TRANSIT', 'DELIVERED'],
      default: 'NOT_PLANNED',
    },
    deliveredAt: {
      type: Date,
      default: null,
    },
    deliveredConfirmedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },

    // Phase 11: Net Return & Financial Calculations
    estimatedGrossAmount: {
      type: Number,
      default: 0,
    },
    estimatedTransportCost: {
      type: Number,
      default: 0,
    },
    estimatedOtherCosts: {
      type: Number,
      default: 0,
    },
    estimatedNetReturn: {
      type: Number,
      default: 0,
    },
    estimatedTotalBuyerCost: {
      type: Number,
      default: 0,
    },

    // Phase 10: External Payment Workflow
    paymentStatus: {
      type: String,
      enum: [
        'PAYMENT_PENDING',
        'PAYMENT_REPORTED',
        'PAYMENT_CONFIRMED_BY_BOTH',
        'PAYMENT_DISPUTED',
      ],
      default: 'PAYMENT_PENDING',
      index: true,
    },
    paymentMethod: {
      type: String,
      default: 'External / Direct Payment',
    },
    paymentReportedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    paymentReportedByRole: {
      type: String,
      enum: ['FARMER', 'BUYER'],
      default: null,
    },
    paymentReportedAt: {
      type: Date,
      default: null,
    },
    paymentReportedNotes: {
      type: String,
      trim: true,
      default: '',
    },
    paymentConfirmedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    paymentConfirmedAt: {
      type: Date,
      default: null,
    },
    paymentDisputed: {
      type: Boolean,
      default: false,
    },
    paymentDisputeReason: {
      type: String,
      trim: true,
      default: '',
    },
    paymentDisputedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    paymentDisputedAt: {
      type: Date,
      default: null,
    },

    // Phase 12: Ratings & Feedback Tracking
    farmerRated: {
      type: Boolean,
      default: false,
    },
    buyerRated: {
      type: Boolean,
      default: false,
    },
    completedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

/**
 * Calculates Gross Value with proper unit conversion.
 * 1 Quintal = 100 kg
 * 1 Ton = 1000 kg = 10 Quintals
 */
dealSchema.methods.calculateFinancials = function () {
  const qty = Number(this.quantity) || 0;
  const unit = (this.quantityUnit || 'kg').toLowerCase();
  const price = Number(this.agreedPrice) || 0;
  const priceUnit = (this.agreedPriceUnit || 'quintal').toLowerCase();

  let gross = 0;
  if (priceUnit === 'quintal') {
    let qtyInQuintals = qty;
    if (unit === 'kg') {
      qtyInQuintals = qty / 100;
    } else if (unit === 'ton' || unit === 'tonne') {
      qtyInQuintals = qty * 10;
    }
    gross = qtyInQuintals * price;
  } else if (priceUnit === 'kg') {
    let qtyInKg = qty;
    if (unit === 'quintal') {
      qtyInKg = qty * 100;
    } else if (unit === 'ton' || unit === 'tonne') {
      qtyInKg = qty * 1000;
    }
    gross = qtyInKg * price;
  } else {
    gross = qty * price;
  }

  const transport = Number(this.transportCost) || 0;
  const other = Number(this.otherCosts) || 0;

  this.totalAmount = Math.round(gross * 100) / 100;
  this.estimatedGrossAmount = this.totalAmount;
  this.estimatedTransportCost = transport;
  this.estimatedOtherCosts = other;
  this.estimatedNetReturn = Math.round((gross - transport - other) * 100) / 100;
  this.estimatedTotalBuyerCost = Math.round((gross + transport + other) * 100) / 100;

  if (!this.crop && this.commodity) {
    this.crop = this.commodity;
  }
  if (!this.cropId && this.farmerCropId) {
    this.cropId = this.farmerCropId;
  }
  if (!this.requirementId && this.buyerRequirementId) {
    this.requirementId = this.buyerRequirementId;
  }
};

dealSchema.pre('save', function (next) {
  this.calculateFinancials();
  next();
});

// Indexes for fast lookup and sorting
dealSchema.index({ farmerId: 1, status: 1 });
dealSchema.index({ buyerId: 1, status: 1 });
dealSchema.index({ opportunityId: 1 });
dealSchema.index({ createdAt: -1 });

module.exports = mongoose.model('Deal', dealSchema);
