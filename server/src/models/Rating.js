const mongoose = require('mongoose');

const ratingSchema = new mongoose.Schema(
  {
    fromUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'From User ID is required'],
      index: true,
    },
    toUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'To User ID is required'],
      index: true,
    },
    fromRole: {
      type: String,
      enum: ['FARMER', 'BUYER'],
      required: [true, 'From role is required'],
    },
    cropId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Crop',
      default: null,
    },
    opportunityId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Opportunity',
      default: null,
      index: true,
    },
    rating: {
      type: Number,
      required: [true, 'Rating is required'],
      min: [1, 'Rating must be at least 1 star'],
      max: [5, 'Rating cannot exceed 5 stars'],
    },
    categoryRatings: {
      // Buyer -> Farmer categories
      productQuality: { type: Number, min: 1, max: 5 },
      freshness: { type: Number, min: 1, max: 5 },
      spoilage: { type: Number, min: 1, max: 5 },
      quantityAccuracy: { type: Number, min: 1, max: 5 },
      farmerInteraction: { type: Number, min: 1, max: 5 },

      // Farmer -> Buyer categories
      customerInteraction: { type: Number, min: 1, max: 5 },
      buyerInteraction: { type: Number, min: 1, max: 5 },
      paymentExperience: { type: Number, min: 1, max: 5 },
      communication: { type: Number, min: 1, max: 5 },

      // Shared
      transactionExperience: { type: Number, min: 1, max: 5, default: 5 },
    },
    comment: {
      type: String,
      trim: true,
      default: '',
      maxlength: [500, 'Comment cannot exceed 500 characters'],
    },
  },
  {
    timestamps: true,
  }
);

// Prevent duplicate rating from same user for the same opportunity/transaction
ratingSchema.index({ fromUserId: 1, opportunityId: 1 }, { unique: true, sparse: true });

module.exports = mongoose.model('Rating', ratingSchema);
