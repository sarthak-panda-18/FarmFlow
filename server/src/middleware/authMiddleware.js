const { verifyToken } = require('../utils/jwt');

const requireAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      message: 'Authentication token is missing or malformed',
    });
  }

  const token = authHeader.split(' ')[1];
  const decoded = verifyToken(token);

  if (!decoded || !decoded.userId || !decoded.role) {
    return res.status(401).json({
      success: false,
      message: 'Invalid or expired token',
    });
  }

  req.user = {
    id: decoded.userId,
    userId: decoded.userId,
    role: decoded.role,
  };

  next();
};

module.exports = { requireAuth };
