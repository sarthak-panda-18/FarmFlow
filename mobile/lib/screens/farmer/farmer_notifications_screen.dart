import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class FarmerNotificationsScreen extends StatefulWidget {
  const FarmerNotificationsScreen({super.key});

  @override
  State<FarmerNotificationsScreen> createState() =>
      _FarmerNotificationsScreenState();
}

class _FarmerNotificationsScreenState extends State<FarmerNotificationsScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _errorMessage;
  List<NotificationModel> _notifications = [];
  bool _isMarkingAll = false;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.getNotifications(page: 1, limit: 50);
      if (mounted && res.data != null && res.data['success'] == true) {
        final List list = res.data['data'] ?? [];
        setState(() {
          _notifications =
              list.map((item) => NotificationModel.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              res.data?['message'] ?? 'Unable to load notifications.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to load notifications.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      _isMarkingAll = true;
    });

    try {
      await _apiService.markAllNotificationsAsRead();
      await _fetchNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark all as read.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingAll = false;
        });
      }
    }
  }

  Future<void> _onNotificationTap(NotificationModel item) async {
    if (item.isUnread) {
      try {
        await _apiService.markNotificationAsRead(item.id);
      } catch (_) {}
    }

    if (!mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isBuyer = auth.userRole == 'BUYER';

    if (item.type.toUpperCase() == 'MARKET_PRICE_ALERT') {
      if (mounted) {
        await context.push(AppConstants.routeMarketPrices);
        _fetchNotifications();
      }
    } else if (item.type.toUpperCase() == 'MATCH_FOUND') {
      if (mounted) {
        await context.push(isBuyer
            ? AppConstants.routeBuyerMatches
            : AppConstants.routeFarmerMatches);
        _fetchNotifications();
      }
    } else if (item.dealId != null && item.dealId!.isNotEmpty && mounted) {
      final refreshed = await context.push(
        AppConstants.routeDealDetail,
        extra: item.dealId!,
      );
      if (refreshed == true || mounted) {
        _fetchNotifications();
      }
    } else if (item.opportunityId != null &&
        item.opportunityId!.isNotEmpty &&
        mounted) {
      final refreshed = await context.push(
        AppConstants.routeOpportunityDetail,
        extra: item.opportunityId,
      );
      if (refreshed == true || mounted) {
        _fetchNotifications();
      }
    } else {
      _fetchNotifications();
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'MARKET_PRICE_ALERT':
        return Icons.trending_up;
      case 'MATCH_FOUND':
        return Icons.hub_outlined;
      case 'AGREEMENT_PENDING':
        return Icons.gavel;
      case 'AGREEMENT_ACCEPTED':
        return Icons.how_to_reg;
      case 'DEAL_CREATED':
      case 'DEAL_CONFIRMED':
        return Icons.handshake;
      case 'DEAL_CANCELLED':
        return Icons.cancel_outlined;
      case 'DELIVERY_UPDATED':
      case 'DEAL_DELIVERED':
        return Icons.local_shipping;
      case 'PAYMENT_REPORTED':
        return Icons.payment;
      case 'PAYMENT_CONFIRMED':
        return Icons.check_circle_outline;
      case 'PAYMENT_DISPUTED':
        return Icons.warning_amber_rounded;
      case 'RATING_RECEIVED':
        return Icons.star;
      case 'INTEREST_RECEIVED':
      case 'BUYER_INTEREST':
        return Icons.handshake;
      case 'INTEREST_ACCEPTED':
        return Icons.check_circle_outline;
      case 'INTEREST_REJECTED':
        return Icons.highlight_off;
      case 'INTEREST_CANCELLED':
        return Icons.cancel_outlined;
      case 'OPPORTUNITY_EXPIRED':
        return Icons.hourglass_disabled;
      default:
        return Icons.notifications_none;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'MARKET_PRICE_ALERT':
        return const Color(0xFF0284C7); // Sky blue
      case 'MATCH_FOUND':
        return const Color(0xFF0D9488); // Teal
      case 'AGREEMENT_PENDING':
        return const Color(0xFFEAB308); // Amber/Yellow
      case 'AGREEMENT_ACCEPTED':
      case 'DEAL_CONFIRMED':
      case 'PAYMENT_CONFIRMED':
      case 'INTEREST_ACCEPTED':
        return const Color(0xFF16A34A); // Green
      case 'DEAL_CREATED':
      case 'INTEREST_RECEIVED':
      case 'BUYER_INTEREST':
        return const Color(0xFF2563EB); // Blue
      case 'DEAL_CANCELLED':
      case 'PAYMENT_DISPUTED':
      case 'INTEREST_REJECTED':
        return const Color(0xFFDC2626); // Red
      case 'PAYMENT_REPORTED':
      case 'INTEREST_CANCELLED':
        return const Color(0xFFD97706); // Amber
      case 'DELIVERY_UPDATED':
      case 'DEAL_DELIVERED':
        return const Color(0xFF7C3AED); // Purple
      case 'RATING_RECEIVED':
        return const Color(0xFFF59E0B); // Gold
      case 'OPPORTUNITY_EXPIRED':
        return const Color(0xFF64748B); // Slate
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isBuyer = auth.userRole == 'BUYER';
    final themeColor = isBuyer ? AppColors.secondary : AppColors.primary;

    final unreadCount = _notifications.where((n) => n.isUnread).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
            unreadCount > 0 ? 'Notifications ($unreadCount)' : 'Notifications'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: _isMarkingAll ? null : _markAllAsRead,
              icon: _isMarkingAll
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.done_all, color: Colors.white, size: 18),
              label: const Text(
                'Mark All Read',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchNotifications,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: _buildBody(themeColor),
      ),
    );
  }

  Widget _buildBody(Color themeColor) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: themeColor));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchNotifications,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.notifications_none,
                  size: 64, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(
                'No notifications yet.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You will receive notifications here when there are match interests, acceptances, rejections, or opportunity status changes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final item = _notifications[index];
        final typeColor = _getTypeColor(item.type);
        final typeIcon = _getTypeIcon(item.type);

        return Card(
          elevation: item.isUnread ? 2 : 0,
          margin: const EdgeInsets.only(bottom: 10),
          color: item.isUnread ? const Color(0xFFF0FDF4) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            side: BorderSide(
              color: item.isUnread
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : const Color(0xFFE2E8F0),
              width: item.isUnread ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            onTap: () => _onNotificationTap(item),
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon Avatar
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(typeIcon, color: typeColor, size: 22),
                  ),

                  const SizedBox(width: 12),

                  // Title, message, timestamp
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight: item.isUnread
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              item.timeAgo,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.message,
                          style: TextStyle(
                            fontSize: 13,
                            color: item.isUnread
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                        if (item.opportunityId != null &&
                            item.opportunityId!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'View Opportunity',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: typeColor,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.arrow_forward,
                                  size: 12, color: typeColor),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (item.isUnread) ...[
                    const SizedBox(width: 8),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
