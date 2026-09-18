const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { getDBStatus } = require('./config/database');
const { notFoundHandler, errorHandler } = require('./middleware/errorMiddleware');

// Import routes
const authRoutes = require('./routes/authRoutes');
const verificationRoutes = require('./routes/verificationRoutes');
const farmerRoutes = require('./routes/farmerRoutes');
const buyerRoutes = require('./routes/buyerRoutes');
const commodityRoutes = require('./routes/commodityRoutes');
const marketRoutes = require('./routes/marketRoutes');
const recommendationRoutes = require('./routes/recommendationRoutes');
const allocationRoutes = require('./routes/allocationRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const cropRoutes = require('./routes/cropRoutes');
const requirementRoutes = require('./routes/requirementRoutes');
const opportunityRoutes = require('./routes/opportunityRoutes');
const ratingRoutes = require('./routes/ratingRoutes');
const locationRoutes = require('./routes/locationRoutes');
const matchRoutes = require('./routes/matchRoutes');

const app = express();

// Security and middleware setup
app.use(helmet());
app.use(cors());
app.use(morgan('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health Check API
app.get('/api/health', (req, res) => {
  const dbStatus = getDBStatus();
  res.status(200).json({
    success: true,
    message: 'Farm-to-Market API is running',
    database: dbStatus,
  });
});

// Route registration
app.use('/api/auth', authRoutes);
app.use('/api/verification', verificationRoutes);
app.use('/api/farmers', farmerRoutes);
app.use('/api/buyers', buyerRoutes);
app.use('/api/crops', cropRoutes);
app.use('/api/requirements', requirementRoutes);
app.use('/api/commodities', commodityRoutes);
app.use('/api/markets', marketRoutes);
app.use('/api/market-prices', marketRoutes);
app.use('/api/recommendations', recommendationRoutes);
app.use('/api/allocations', allocationRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/opportunities', opportunityRoutes);
app.use('/api/ratings', ratingRoutes);
app.use('/api/location', locationRoutes);
app.use('/api/matches', matchRoutes);

// Error Handling Middleware
app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
