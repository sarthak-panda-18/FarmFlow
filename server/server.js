require('dotenv').config();
const app = require('./src/app');
const { connectDB, getDBStatus } = require('./src/config/database');

const PORT = process.env.PORT || 5000;

const startServer = async () => {
  // Connect to MongoDB
  const isConnected = await connectDB();

  if (!isConnected) {
    console.warn('[SERVER WARNING] Server is starting, but MongoDB connection is currently DISCONNECTED. Database queries will return 500 error.');
  }

  // Bind to 0.0.0.0 so Express receives requests from physical devices, emulators, and localhost
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Farm-to-Market Server listening on http://0.0.0.0:${PORT} [ENV: ${process.env.NODE_ENV || 'development'}]`);
    console.log(`Health check: http://localhost:${PORT}/api/health`);
    console.log(`Database status: ${getDBStatus()}`);
  });
};

startServer();
