class NotificationModel {
  final String id;
  final String title;
  final String type;
  final String message;
  final String crop;
  final String? opportunityId;
  final String status;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.type,
    required this.message,
    required this.crop,
    this.opportunityId,
    required this.status,
    required this.createdAt,
  });

  bool get isUnread => status.toUpperCase() == 'UNREAD';

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? json['_id'] ?? '',
      title: json['title'] ?? 'Notification',
      type: json['type'] ?? 'BUYER_INTEREST',
      message: json['message'] ?? '',
      crop: json['crop'] ?? '',
      opportunityId: json['opportunityId'],
      status: json['status'] ?? 'UNREAD',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }
}
