const mongoose = require('mongoose');

const marketPriceSchema = new mongoose.Schema(
  {
    state: {
      type: String,
      required: [true, 'State is required'],
      trim: true,
      index: true,
    },
    district: {
      type: String,
      required: [true, 'District is required'],
      trim: true,
      index: true,
    },
    market: {
      type: String,
      required: [true, 'Market is required'],
      trim: true,
      index: true,
    },
    commodity: {
      type: String,
      required: [true, 'Commodity is required'],
      trim: true,
      index: true,
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
    minPrice: {
      type: Number,
      required: [true, 'Minimum price is required'],
      min: [0, 'Minimum price cannot be negative'],
    },
    maxPrice: {
      type: Number,
      required: [true, 'Maximum price is required'],
      min: [0, 'Maximum price cannot be negative'],
    },
    modalPrice: {
      type: Number,
      required: [true, 'Modal price is required'],
      min: [0, 'Modal price cannot be negative'],
    },
    date: {
      type: Date,
      required: [true, 'Price date is required'],
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

// Compound unique index to prevent duplicate record insertion
marketPriceSchema.index(
  {
    state: 1,
    district: 1,
    market: 1,
    commodity: 1,
    variety: 1,
    grade: 1,
    date: 1,
  },
  { unique: true }
);

// Performance indexes for frequent queries
marketPriceSchema.index({ commodity: 1, date: -1 });
marketPriceSchema.index({ state: 1, commodity: 1, date: -1 });
marketPriceSchema.index({ market: 1, commodity: 1, date: -1 });

module.exports = mongoose.model('MarketPrice', marketPriceSchema);
