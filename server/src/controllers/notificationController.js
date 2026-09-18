const Notification = require('../models/Notification');

/**
 * @desc    Get notifications for authenticated farmer
 * @route   GET /api/notifications
 * @access  Private
 */
const getMyNotifications = async (req, res, next) => {
  try {
    const currentUserId = req.user.userId;
    const { page = 1, limit = 20 } = req.query;

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    const userFilter = {
      $or: [{ userId: currentUserId }, { farmerId: currentUserId }],
    };

    const [total, notifications] = await Promise.all([
      Notification.countDocuments(userFilter),
      Notification.find(userFilter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limitNum)
        .lean(),
    ]);

    const formatted = notifications.map((n) => ({
      id: n._id.toString(),
      title: n.title || 'Notification',
      type: n.type || 'NOTIFICATION',
      message: n.message,
      crop: n.crop,
      opportunityId: n.opportunityId ? n.opportunityId.toString() : null,
      status: n.status,
      createdAt: n.createdAt,
    }));

    res.status(200).json({
      success: true,
      page: pageNum,
      limit: limitNum,
      total,
      pages: Math.ceil(total / limitNum) || 1,
      data: formatted,
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

module.exports = {
  getMyNotifications,
  markAsRead,
};
