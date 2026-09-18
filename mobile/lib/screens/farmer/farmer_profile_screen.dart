import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../providers/auth_provider.dart';

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Farmer Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.agriculture, size: 40, color: Colors.white),
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
              'Mobile: $phone',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (email != null && email.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Email: $email',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
            ],
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
                    ListTile(
                      leading: const Icon(Icons.verified_user_outlined, color: AppColors.primary),
                      title: const Text('Mobile Verification'),
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
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.badge_outlined, color: AppColors.primary),
                      title: const Text('Farmer Identity Verification'),
                      subtitle: verificationId != null && verificationId.isNotEmpty
                          ? Text('ID: $verificationId')
                          : null,
                      trailing: Chip(
                        label: Text(
                          verificationStatus,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: verificationStatus == 'VERIFIED'
                                ? AppColors.success
                                : verificationStatus == 'REJECTED'
                                    ? AppColors.error
                                    : const Color(0xFFD97706),
                          ),
                        ),
                        backgroundColor: verificationStatus == 'VERIFIED'
                            ? const Color(0xFFDCFCE7)
                            : verificationStatus == 'REJECTED'
                                ? const Color(0xFFFEF2F2)
                                : const Color(0xFFFEF3C7),
                      ),
                    ),
                    const Divider(),
                    const ListTile(
                      leading: Icon(Icons.security, color: AppColors.primary),
                      title: Text('Account Security'),
                      subtitle: Text('Password protected with JWT authentication'),
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
