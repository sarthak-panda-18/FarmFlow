const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Recipient User ID is required'],
      index: true,
    },
    farmerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      index: true,
    },
    recipientRole: {
      type: String,
      enum: ['FARMER', 'BUYER'],
      default: 'FARMER',
    },
    title: {
      type: String,
      default: 'Notification',
      trim: true,
    },
    type: {
      type: String,
      enum: [
        'INTEREST_RECEIVED',
        'INTEREST_ACCEPTED',
        'INTEREST_REJECTED',
        'INTEREST_CANCELLED',
        'OPPORTUNITY_EXPIRED',
        'AGREEMENT_PENDING',
        'AGREEMENT_ACCEPTED',
        'DEAL_CREATED',
        'DEAL_CONFIRMED',
        'DEAL_CANCELLED',
        'DELIVERY_UPDATED',
        'DEAL_DELIVERED',
        'PAYMENT_REPORTED',
        'PAYMENT_CONFIRMED',
        'PAYMENT_DISPUTED',
        'RATING_RECEIVED',
        'BUYER_INTEREST',
        'FARMER_INTEREST',
        'MATCH_FOUND',
        'MARKET_PRICE_ALERT',
        'BUYER_RECOMMENDATION',
        'NOTIFICATION',
      ],
      default: 'INTEREST_RECEIVED',
      trim: true,
    },
    message: {
      type: String,
      required: [true, 'Notification message is required'],
      trim: true,
    },
    crop: {
      type: String,
      trim: true,
      default: '',
    },
    opportunityId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Opportunity',
      default: null,
      index: true,
    },
    dealId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Deal',
      default: null,
      index: true,
    },
    alertKey: {
      type: String,
      default: null,
      index: true,
      trim: true,
    },
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
    },
    threshold: {
      type: Number,
      default: 0,
    },
    isRead: {
      type: Boolean,
      default: false,
      index: true,
    },
    status: {
      type: String,
      enum: ['UNREAD', 'READ'],
      default: 'UNREAD',
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

notificationSchema.pre('save', function (next) {
  if (!this.userId && this.farmerId) {
    this.userId = this.farmerId;
  }
  if (!this.farmerId && this.userId) {
    this.farmerId = this.userId;
  }
  if (this.isModified('status')) {
    this.isRead = this.status === 'READ';
  } else if (this.isModified('isRead')) {
    this.status = this.isRead ? 'READ' : 'UNREAD';
  }
  next();
});

notificationSchema.index({ userId: 1, isRead: 1 });
notificationSchema.index({ userId: 1, status: 1 });
notificationSchema.index({ userId: 1, createdAt: -1 });
notificationSchema.index({ farmerId: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', notificationSchema);

