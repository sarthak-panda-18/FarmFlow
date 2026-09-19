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
      enum: ['quintal'],
      default: 'quintal',
      trim: true,
      lowercase: true,
    },
    agreedPrice: {
      type: Number,
      required: [true, 'Agreed unit price is required'],
      min: [0, 'Agreed price cannot be negative'],
    },
    agreedPriceUnit: {
      type: String,
      enum: ['quintal'],
      default: 'quintal',
      trim: true,
      lowercase: true,
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

    // Official Deal Agreement Layer
    agreementStatus: {
      type: String,
      enum: [
        'AGREEMENT_PENDING',
        'WAITING_FOR_BUYER',
        'WAITING_FOR_FARMER',
        'DEAL_CONFIRMED',
        'CANCELLED',
      ],
      default: 'AGREEMENT_PENDING',
      index: true,
    },
    farmerAccepted: {
      type: Boolean,
      default: false,
    },
    buyerAccepted: {
      type: Boolean,
      default: false,
    },
    farmerAcceptedAt: {
      type: Date,
      default: null,
    },
    buyerAcceptedAt: {
      type: Date,
      default: null,
    },
    agreementCreatedAt: {
      type: Date,
      default: Date.now,
    },
    agreementVersion: {
      type: Number,
      default: 1,
    },
    termsAcceptedVersion: {
      type: Number,
      default: 1,
    },

    // Deal Lifecycle Status
    status: {
      type: String,
      enum: [
        'AGREEMENT_PENDING',
        'WAITING_FOR_BUYER',
        'WAITING_FOR_FARMER',
        'DEAL_CONFIRMED',
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
      default: 'AGREEMENT_PENDING',
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
 * Calculates Gross Value with Quintal agricultural unit standard.
 * Both quantity (Quintal) and agreed price (₹ / Quintal) use Quintals.
 * Gross Value = Quantity * Agreed Price
 */
dealSchema.methods.calculateFinancials = function () {
  const qty = Number(this.quantity) || 0;
  const price = Number(this.agreedPrice) || 0;

  // Exact Quintal multiplication
  const gross = Math.round(qty * price * 100) / 100;

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
