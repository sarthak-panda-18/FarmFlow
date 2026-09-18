import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_strings.dart';
import '../../providers/auth_provider.dart';

class BuyerProfileScreen extends StatelessWidget {
  const BuyerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final name = authProvider.userName ?? 'Buyer';
    final phone = authProvider.userPhone ?? 'Not Provided';
    final gstin = authProvider.userGstin ?? authProvider.user?['gstin'] ?? 'Not Provided';
    final role = authProvider.userRole ?? 'Buyer';
    final isPhoneVerified = authProvider.isPhoneVerified;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.buyerProfile),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.secondary,
              child: Icon(Icons.storefront, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Role: $role',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: AppConstants.cardElevation,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(AppConstants.borderRadius)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                child: Column(
                  children: [
                    _ProfileItemRow(
                      icon: Icons.person_outline,
                      label: 'Name',
                      value: name,
                    ),
                    const Divider(),
                    _ProfileItemRow(
                      icon: Icons.phone_outlined,
                      label: 'Mobile Number',
                      value: phone,
                    ),
                    const Divider(),
                    _ProfileItemRow(
                      icon: Icons.receipt_long_outlined,
                      label: 'GSTIN',
                      value: gstin,
                      valueColor: gstin != 'Not Provided' ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                    const Divider(),
                    _ProfileItemRow(
                      icon: Icons.badge_outlined,
                      label: 'Role',
                      value: role,
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.verified_user_outlined, color: AppColors.secondary),
                      title: const Text('Mobile Verification Status', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      trailing: Chip(
                        avatar: Icon(
                          isPhoneVerified ? Icons.check_circle : Icons.error_outline,
                          size: 16,
                          color: isPhoneVerified ? AppColors.success : AppColors.error,
                        ),
                        label: Text(
                          isPhoneVerified ? '✓ Verified' : '✗ Unverified',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isPhoneVerified ? AppColors.success : AppColors.error,
                          ),
                        ),
                        backgroundColor: isPhoneVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileItemRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _ProfileItemRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondary, size: 22),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
