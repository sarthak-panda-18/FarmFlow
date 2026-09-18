const mongoose = require('mongoose');

const buyerFeedbackSchema = new mongoose.Schema(
  {
    buyerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Buyer ID is required'],
    },
    farmerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Farmer ID is required'],
    },
    rating: {
      type: Number,
      required: [true, 'Rating is required'],
      min: [1, 'Rating must be at least 1'],
      max: [5, 'Rating cannot exceed 5'],
    },
    comment: {
      type: String,
      trim: true,
      default: '',
    },
    categoryRatings: {
      communication: { type: Number, min: 1, max: 5, default: 5 },
      pickupReliability: { type: Number, min: 1, max: 5, default: 5 },
      paymentReliability: { type: Number, min: 1, max: 5, default: 5 },
    },
    status: {
      type: String,
      enum: ['ACTIVE', 'HIDDEN'],
      default: 'ACTIVE',
    },
  },
  {
    timestamps: true,
  }
);

buyerFeedbackSchema.index({ buyerId: 1 });
buyerFeedbackSchema.index({ farmerId: 1 });

module.exports = mongoose.model('BuyerFeedback', buyerFeedbackSchema);
