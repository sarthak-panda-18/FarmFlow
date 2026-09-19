import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_strings.dart';
import '../../models/buyer_requirement_model.dart';
import '../../providers/buyer_provider.dart';
import '../../widgets/farm_badge.dart';
import '../../widgets/farm_bottom_nav.dart';
import '../../widgets/farm_empty_state.dart';

class BuyerRequirementsScreen extends StatefulWidget {
  const BuyerRequirementsScreen({super.key});

  @override
  State<BuyerRequirementsScreen> createState() =>
      _BuyerRequirementsScreenState();
}

class _BuyerRequirementsScreenState extends State<BuyerRequirementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BuyerProvider>(context, listen: false)
          .fetchRequirements(refresh: true);
    });
  }

  FarmBadgeType _getStatusBadgeType(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return FarmBadgeType.success;
      case 'FULFILLED':
        return FarmBadgeType.primary;
      case 'CANCELLED':
        return FarmBadgeType.error;
      case 'EXPIRED':
        return FarmBadgeType.warning;
      default:
        return FarmBadgeType.neutral;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[(date.month - 1) % 12]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final buyerProvider = Provider.of<BuyerProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.buyerRequirements),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: const FarmBottomNav(currentIndex: 1, role: 'BUYER'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result =
              await context.push<bool>(AppConstants.routeCreateRequirement);
          if (result == true && context.mounted) {
            buyerProvider.fetchRequirements(refresh: true);
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Post Requirement',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: buyerProvider.isLoading && buyerProvider.requirements.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : buyerProvider.requirements.isEmpty
              ? FarmEmptyState(
                  icon: Icons.list_alt_outlined,
                  title: 'No requirements posted yet',
                  message:
                      'Publish your crop procurement demand to communicate your volume and target rates to farmers.',
                  actionLabel: 'Post Requirement',
                  actionIcon: Icons.add,
                  onAction: () async {
                    final result = await context
                        .push<bool>(AppConstants.routeCreateRequirement);
                    if (result == true) {
                      buyerProvider.fetchRequirements(refresh: true);
                    }
                  },
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () =>
                      buyerProvider.fetchRequirements(refresh: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppConstants.paddingMedium),
                    itemCount: buyerProvider.requirements.length,
                    itemBuilder: (context, index) {
                      final req = buyerProvider.requirements[index];
                      return _buildRequirementCard(req, buyerProvider);
                    },
                  ),
                ),
    );
  }

  Widget _buildRequirementCard(
      BuyerRequirementModel requirement, BuyerProvider provider) {
    final formattedDate = _formatDate(requirement.requiredByDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () async {
            await context.push(
              AppConstants.routeRequirementDetail,
              extra: requirement,
            );
            provider.fetchRequirements(refresh: true);
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        requirement.commodity,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    FarmBadge(
                      label: requirement.status.toUpperCase(),
                      type: _getStatusBadgeType(requirement.status),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  requirement.variety != null &&
                          requirement.variety!.isNotEmpty &&
                          requirement.variety != 'Not specified'
                      ? 'Variety: ${requirement.variety}'
                      : 'Standard Requirement',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const Divider(height: 20, color: AppColors.border),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Procurement Quantity',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          '${requirement.quantity} ${requirement.quantityUnit}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Offered Rate',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          '₹${requirement.offeredPrice.toStringAsFixed(0)} / ${requirement.quantityUnit}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          requirement.market != null &&
                                  requirement.market!.isNotEmpty
                              ? '${requirement.market}, ${requirement.district}'
                              : requirement.district,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          'Required: $formattedDate',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
