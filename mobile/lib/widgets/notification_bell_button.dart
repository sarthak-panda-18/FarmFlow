import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_constants.dart';
import '../services/api_service.dart';

class NotificationBellButton extends StatefulWidget {
  final Color iconColor;

  const NotificationBellButton({
    super.key,
    this.iconColor = Colors.white,
  });

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUnreadCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchUnreadCount();
    }
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final res = await _apiService.getUnreadNotificationCount();
      if (mounted && res.data != null && res.data['success'] == true) {
        final count = res.data['data']?['unreadCount'] ?? 0;
        setState(() {
          _unreadCount = count is int ? count : int.tryParse(count.toString()) ?? 0;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(
            _unreadCount > 0 ? Icons.notifications_active : Icons.notifications_outlined,
            color: widget.iconColor,
          ),
          tooltip: 'Notifications',
          onPressed: () async {
            await context.push(AppConstants.routeNotifications);
            _fetchUnreadCount();
          },
        ),
        if (_unreadCount > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444), // Crimson Red
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
