class NotificationModel {
  final String id;
  final String title;
  final String type;
  final String message;
  final String crop;
  final String? opportunityId;
  final String? dealId;
  final String status;
  final bool isRead;
  final String? recipientRole;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.type,
    required this.message,
    required this.crop,
    this.opportunityId,
    this.dealId,
    required this.status,
    required this.isRead,
    this.recipientRole,
    required this.createdAt,
  });

  bool get isUnread => !isRead && status.toUpperCase() == 'UNREAD';

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawIsRead = json['isRead'];
    final rawStatus = json['status']?.toString().toUpperCase() ?? 'UNREAD';
    final isReadBool = rawIsRead == true || rawStatus == 'READ';

    return NotificationModel(
      id: json['id'] ?? json['_id'] ?? '',
      title: json['title'] ?? 'Notification',
      type: json['type'] ?? 'INTEREST_RECEIVED',
      message: json['message'] ?? '',
      crop: json['crop'] ?? '',
      opportunityId: json['opportunityId'],
      dealId: json['dealId'],
      status: isReadBool ? 'READ' : 'UNREAD',
      isRead: isReadBool,
      recipientRole: json['recipientRole'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}
