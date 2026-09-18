import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_strings.dart';
import '../../models/buyer_requirement_model.dart';
import '../../providers/buyer_provider.dart';

class BuyerRequirementsScreen extends StatefulWidget {
  const BuyerRequirementsScreen({super.key});

  @override
  State<BuyerRequirementsScreen> createState() => _BuyerRequirementsScreenState();
}

class _BuyerRequirementsScreenState extends State<BuyerRequirementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BuyerProvider>(context, listen: false).fetchRequirements(refresh: true);
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return AppColors.success;
      case 'FULFILLED':
        return AppColors.primary;
      case 'CANCELLED':
        return AppColors.error;
      case 'EXPIRED':
        return AppColors.warning;
      default:
        return AppColors.textMuted;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
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
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push<bool>(AppConstants.routeCreateRequirement);
          if (result == true && context.mounted) {
            buyerProvider.fetchRequirements(refresh: true);
          }
        },
        backgroundColor: AppColors.secondary,
        icon: const Icon(Icons.add),
        label: const Text('Create Requirement'),
      ),
      body: buyerProvider.isLoading && buyerProvider.requirements.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : buyerProvider.requirements.isEmpty
              ? _buildEmptyState(context, buyerProvider)
              : RefreshIndicator(
                  onRefresh: () => buyerProvider.fetchRequirements(refresh: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppConstants.paddingMedium),
                    itemCount: buyerProvider.requirements.length,
                    itemBuilder: (context, index) {
                      final req = buyerProvider.requirements[index];
                      return _RequirementCard(
                        requirement: req,
                        statusColor: _getStatusColor(req.status),
                        formattedDate: _formatDate(req.requiredByDate),
                        onTap: () async {
                          await context.push(
                            AppConstants.routeRequirementDetail,
                            extra: req,
                          );
                          buyerProvider.fetchRequirements(refresh: true);
                        },
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(BuildContext context, BuyerProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.assignment_outlined,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No requirements created yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Publish your crop purchasing requirements to communicate your demand to farmers.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
              ),
              onPressed: () async {
                final result = await context.push<bool>(AppConstants.routeCreateRequirement);
                if (result == true) {
                  provider.fetchRequirements(refresh: true);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('+ Create Requirement'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequirementCard extends StatelessWidget {
  final BuyerRequirementModel requirement;
  final Color statusColor;
  final String formattedDate;
  final VoidCallback onTap;

  const _RequirementCard({
    required this.requirement,
    required this.statusColor,
    required this.formattedDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      requirement.commodity,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      requirement.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    backgroundColor: statusColor,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                requirement.variety != null && requirement.variety!.isNotEmpty && requirement.variety != 'Not specified'
                    ? 'Variety: ${requirement.variety}'
                    : 'Standard Requirement',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quantity',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
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
                      const Text(
                        'Offered Price',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      Text(
                        '₹${requirement.offeredPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        requirement.market != null && requirement.market!.isNotEmpty
                            ? '${requirement.market}, ${requirement.district}'
                            : requirement.district,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Req: $formattedDate',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
