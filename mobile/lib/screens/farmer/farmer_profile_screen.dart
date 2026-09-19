import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/farm_badge.dart';
import '../../widgets/farm_bottom_nav.dart';
import '../../widgets/farm_card.dart';

class FarmerProfileScreen extends StatelessWidget {
  const FarmerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final name = authProvider.userName ?? 'Farmer';
    final phone = authProvider.userPhone ?? 'Not Provided';
    final email = authProvider.userEmail;
    final isPhoneVerified = authProvider.isPhoneVerified;
    final verificationStatus = authProvider.verificationStatus;
    final verificationId = authProvider.verificationId;
    final address = authProvider.userAddress ?? authProvider.userDistrict ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Farmer Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: const FarmBottomNav(currentIndex: 4, role: 'FARMER'),
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
                      child: Icon(Icons.agriculture,
                          size: 40, color: AppColors.primary),
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
                  if (email != null && email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Email: $email',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Verification & Security Card (White Card)
            FarmCard(
              variant: FarmCardVariant.white,
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2EFE0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.phone_android,
                          color: AppColors.primary, size: 20),
                    ),
                    title: const Text('Mobile OTP Verification',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
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
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2EFE0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.verified_user_outlined,
                          color: AppColors.primary, size: 20),
                    ),
                    title: const Text('Farmer Identity Verification',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle:
                        verificationId != null && verificationId.isNotEmpty
                            ? Text('ID: $verificationId',
                                style: const TextStyle(fontSize: 12))
                            : null,
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
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2EFE0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.security,
                          color: AppColors.primary, size: 20),
                    ),
                    title: const Text('Account Security',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text('JWT Token & OTP Protected',
                        style: TextStyle(fontSize: 12)),
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
}
