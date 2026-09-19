import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/farm_badge.dart';
import '../../widgets/farm_bottom_nav.dart';
import '../../widgets/farm_card.dart';

class BuyerProfileScreen extends StatelessWidget {
  const BuyerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final name = authProvider.userName ?? 'Buyer';
    final phone = authProvider.userPhone ?? 'Not Provided';
    final gstin =
        authProvider.userGstin ?? authProvider.user?['gstin'] ?? 'Not Provided';
    final role = authProvider.userRole ?? 'Buyer';
    final isPhoneVerified = authProvider.isPhoneVerified;
    final verificationStatus = authProvider.verificationStatus;
    final address = authProvider.userAddress ?? authProvider.userDistrict ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.buyerProfile),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: const FarmBottomNav(currentIndex: 4, role: 'BUYER'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Profile Header Card (Pale Green)
            FarmCard(
              variant: FarmCardVariant.paleGreen,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: const Center(
                      child: Icon(Icons.storefront,
                          size: 38, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mobile: $phone',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(address,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      FarmBadge(
                        label: 'Role: $role',
                        type: FarmBadgeType.primary,
                      ),
                      FarmBadge(
                        label: 'Business: $verificationStatus',
                        type: verificationStatus == 'VERIFIED'
                            ? FarmBadgeType.success
                            : FarmBadgeType.warning,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Identity & Details Card (White Card)
            FarmCard(
              variant: FarmCardVariant.white,
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  _buildProfileRow(
                    icon: Icons.phone_android,
                    label: 'Mobile OTP Verification',
                    trailing: FarmBadge(
                      label: isPhoneVerified ? 'Verified' : 'Unverified',
                      icon: isPhoneVerified
                          ? Icons.check_circle
                          : Icons.error_outline,
                      type: isPhoneVerified
                          ? FarmBadgeType.success
                          : FarmBadgeType.error,
                    ),
                  ),
                  const Divider(height: 1),
                  _buildProfileRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'GSTIN / Business Registration',
                    value: gstin,
                  ),
                  const Divider(height: 1),
                  _buildProfileRow(
                    icon: Icons.verified_user_outlined,
                    label: 'Buyer Verification Status',
                    trailing: FarmBadge(
                      label: verificationStatus,
                      type: verificationStatus == 'VERIFIED'
                          ? FarmBadgeType.success
                          : verificationStatus == 'REJECTED'
                              ? FarmBadgeType.error
                              : FarmBadgeType.warning,
                    ),
                  ),
                  const Divider(height: 1),
                  _buildProfileRow(
                    icon: Icons.security,
                    label: 'Security & Access',
                    value: 'JWT Token & OTP Protected',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await authProvider.logout();
                  if (context.mounted) {
                    context.go(AppConstants.routeLogin);
                  }
                },
                icon:
                    const Icon(Icons.logout, size: 18, color: AppColors.error),
                label: const Text('Logout from Account',
                    style: TextStyle(
                        color: AppColors.error, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow({
    required IconData icon,
    required String label,
    String? value,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFE2EFE0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary)),
      subtitle: value != null
          ? Text(value,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary))
          : null,
      trailing: trailing,
    );
  }
}
