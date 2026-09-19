const Notification = require('../models/Notification');

/**
 * @desc    Get notifications for authenticated user (Farmer or Buyer)
 * @route   GET /api/notifications
 * @access  Private
 */
const getMyNotifications = async (req, res, next) => {
  try {
    const currentUserId = req.user.userId;
    const { page = 1, limit = 20, status } = req.query;

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    const userFilter = {
      $or: [{ userId: currentUserId }, { farmerId: currentUserId }],
    };

    if (status) {
      if (status.toUpperCase() === 'UNREAD') {
        userFilter.$and = [{ $or: [{ isRead: false }, { status: 'UNREAD' }] }];
      } else if (status.toUpperCase() === 'READ') {
        userFilter.$and = [{ $or: [{ isRead: true }, { status: 'READ' }] }];
      }
    }

    const [total, notifications, unreadCount] = await Promise.all([
      Notification.countDocuments(userFilter),
      Notification.find(userFilter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limitNum)
        .lean(),
      Notification.countDocuments({
        $or: [{ userId: currentUserId }, { farmerId: currentUserId }],
        $or: [{ isRead: false }, { status: 'UNREAD' }],
      }),
    ]);

    const formatted = notifications.map((n) => ({
      id: n._id.toString(),
      title: n.title || 'Notification',
      type: n.type || 'INTEREST_RECEIVED',
      message: n.message,
      crop: n.crop,
      opportunityId: n.opportunityId ? n.opportunityId.toString() : null,
      dealId: n.dealId ? n.dealId.toString() : null,
      isRead: n.isRead === true || n.status === 'READ',
      status: n.status || (n.isRead ? 'READ' : 'UNREAD'),
      createdAt: n.createdAt,
    }));

    res.status(200).json({
      success: true,
      page: pageNum,
      limit: limitNum,
      total,
      unreadCount,
      pages: Math.ceil(total / limitNum) || 1,
      data: formatted,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get unread notification count for authenticated user
 * @route   GET /api/notifications/unread-count
 * @access  Private
 */
const getUnreadCount = async (req, res, next) => {
  try {
    const currentUserId = req.user.userId;
    const count = await Notification.countDocuments({
      $or: [{ userId: currentUserId }, { farmerId: currentUserId }],
      $or: [{ isRead: false }, { status: 'UNREAD' }],
    });

    res.status(200).json({
      success: true,
      count,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Mark a notification as read
 * @route   PATCH /api/notifications/:id/read
 * @access  Private
 */
const markAsRead = async (req, res, next) => {
  try {
    const currentUserId = req.user.userId;
    const notification = await Notification.findOne({
      _id: req.params.id,
      $or: [{ userId: currentUserId }, { farmerId: currentUserId }],
    });

    if (!notification) {
      return res.status(404).json({
        success: false,
        message: 'Notification not found',
      });
    }

    notification.isRead = true;
    notification.status = 'READ';
    await notification.save();

    res.status(200).json({
      success: true,
      message: 'Notification marked as read',
      data: { notification },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Mark all notifications as read for authenticated user
 * @route   PATCH /api/notifications/read-all
 * @access  Private
 */
const markAllAsRead = async (req, res, next) => {
  try {
    const currentUserId = req.user.userId;
    await Notification.updateMany(
      {
        $or: [{ userId: currentUserId }, { farmerId: currentUserId }],
        $or: [{ isRead: false }, { status: 'UNREAD' }],
      },
      {
        $set: {
          isRead: true,
          status: 'READ',
        },
      }
    );

    res.status(200).json({
      success: true,
      message: 'All notifications marked as read',
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getMyNotifications,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
};

