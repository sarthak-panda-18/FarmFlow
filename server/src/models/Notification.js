const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      index: true,
    },
    farmerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      index: true,
    },
    title: {
      type: String,
      default: 'Notification',
      trim: true,
    },
    type: {
      type: String,
      default: 'BUYER_INTEREST',
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
    },
    threshold: {
      type: Number,
      default: 0,
    },
    status: {
      type: String,
      enum: ['UNREAD', 'READ'],
      default: 'UNREAD',
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
  next();
});

notificationSchema.index({ userId: 1, createdAt: -1 });
notificationSchema.index({ farmerId: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', notificationSchema);
