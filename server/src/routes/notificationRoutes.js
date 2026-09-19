const express = require('express');
const router = express.Router();
const {
  getMyNotifications,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
} = require('../controllers/notificationController');
const { requireAuth } = require('../middleware/authMiddleware');

router.use(requireAuth);

router.get('/', getMyNotifications);
router.get('/unread-count', getUnreadCount);
router.patch('/read-all', markAllAsRead);
router.post('/read-all', markAllAsRead);
router.patch('/:id/read', markAsRead);
router.post('/:id/read', markAsRead);

module.exports = router;

