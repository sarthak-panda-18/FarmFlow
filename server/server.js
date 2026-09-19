require('dotenv').config();
const app = require('./src/app');
const { connectDB, getDBStatus } = require('./src/config/database');

const os = require('os');
const { exec } = require('child_process');

const PORT = process.env.PORT || 5000;

function getNetworkIPv4Addresses() {
  const interfaces = os.networkInterfaces();
  const addresses = [];
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        addresses.push({ interface: name, address: iface.address });
      }
    }
  }
  return addresses;
}

function autoConfigureAdbReverse(port) {
  exec(`adb reverse tcp:${port} tcp:${port}`, (err, stdout, stderr) => {
    if (!err) {
      console.log(`[ADB AUTO-ROUTING] Successfully routed physical Android device over USB: adb reverse tcp:${port} tcp:${port}`);
    }
  });
}

const startServer = async () => {
  // Connect to MongoDB
  const isConnected = await connectDB();

  if (!isConnected) {
    console.warn('[SERVER WARNING] Server is starting, but MongoDB connection is currently DISCONNECTED. Database queries will return 500 error.');
  }

  // Bind to 0.0.0.0 so Express receives requests from physical devices, emulators, and localhost
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`\n======================================================`);
    console.log(`Farm-to-Market Server listening on http://0.0.0.0:${PORT} [ENV: ${process.env.NODE_ENV || 'development'}]`);
    console.log(`Localhost API:      http://127.0.0.1:${PORT}/api`);
    console.log(`Android Emulator:   http://10.0.2.2:${PORT}/api`);
    
    const ips = getNetworkIPv4Addresses();
    if (ips.length > 0) {
      console.log(`Mobile Physical Device (Wi-Fi/LAN):`);
      ips.forEach(ip => {
        console.log(`  - [${ip.interface}]: http://${ip.address}:${PORT}/api`);
      });
    }
    console.log(`Health check:       http://localhost:${PORT}/api/health`);
    console.log(`Database status:    ${getDBStatus()}`);
    console.log(`======================================================\n`);

    // Auto-configure ADB reverse for USB-connected physical Android devices
    autoConfigureAdbReverse(PORT);
  });
};

startServer();
