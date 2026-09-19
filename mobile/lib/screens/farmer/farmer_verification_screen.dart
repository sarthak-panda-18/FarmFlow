import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../providers/auth_provider.dart';

class FarmerVerificationScreen extends StatefulWidget {
  const FarmerVerificationScreen({super.key});

  @override
  State<FarmerVerificationScreen> createState() =>
      _FarmerVerificationScreenState();
}

class _FarmerVerificationScreenState extends State<FarmerVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _farmerIdController = TextEditingController();
  final _docController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.verificationId != null) {
      _farmerIdController.text = authProvider.verificationId!;
    }
  }

  @override
  void dispose() {
    _farmerIdController.dispose();
    _docController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitVerification() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _isLoading = true;
    });

    try {
      await authProvider.submitFarmerVerification(
        _farmerIdController.text.trim(),
        supportingDocument: _docController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Farmer verification information submitted successfully! Status: PENDING'),
          backgroundColor: AppColors.success,
        ),
      );

      context.go(AppConstants.routeFarmerDashboard);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final status = authProvider.verificationStatus;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Verify Farmer Account'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: Color(0xFFDCFCE7),
                    child: Icon(Icons.agriculture,
                        size: 40, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Verify Farmer Account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Verify your farmer identity to access marketplace features.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 20),

                // Current Status Card
                Card(
                  elevation: 0,
                  color: status == 'VERIFIED'
                      ? const Color(0xFFF0FDF4)
                      : status == 'REJECTED'
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFFEF3C7),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.borderRadius),
                    side: BorderSide(
                      color: status == 'VERIFIED'
                          ? AppColors.success
                          : status == 'REJECTED'
                              ? AppColors.error
                              : AppColors.warning,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          status == 'VERIFIED'
                              ? Icons.check_circle
                              : status == 'REJECTED'
                                  ? Icons.cancel
                                  : Icons.hourglass_top,
                          color: status == 'VERIFIED'
                              ? AppColors.success
                              : status == 'REJECTED'
                                  ? AppColors.error
                                  : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Status: $status',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                status == 'VERIFIED'
                                    ? 'Your farmer identity is fully verified.'
                                    : status == 'REJECTED'
                                        ? 'Verification was rejected. Please re-check your details and resubmit.'
                                        : 'Your submission is pending review by marketplace administrators.',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppConstants.borderRadius),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: AppColors.error, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _farmerIdController,
                  decoration: const InputDecoration(
                    labelText: 'Farmer ID / Agricultural Registration ID *',
                    hintText: 'e.g. FARM-12345678',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Farmer ID / Registration ID is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _docController,
                  decoration: const InputDecoration(
                    labelText: 'Supporting Document URL (Optional)',
                    hintText: 'https://example.com/farmer-cert.pdf',
                    prefixIcon: Icon(Icons.attach_file),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmitVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.borderRadius),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          status == 'PENDING'
                              ? 'Update Verification Info'
                              : 'Submit Farmer Verification',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    context.go(AppConstants.routeFarmerDashboard);
                  },
                  child: const Text('Return to Farmer Dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
