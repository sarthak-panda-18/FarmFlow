import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../providers/auth_provider.dart';

class BuyerVerificationScreen extends StatefulWidget {
  const BuyerVerificationScreen({super.key});

  @override
  State<BuyerVerificationScreen> createState() =>
      _BuyerVerificationScreenState();
}

class _BuyerVerificationScreenState extends State<BuyerVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _regIdController = TextEditingController();
  final _docController = TextEditingController();

  String _selectedBusinessType = 'WHOLESALER';
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _businessTypes = [
    'WHOLESALER',
    'EXPORTER',
    'PROCESSOR',
    'RETAILER',
    'DISTRIBUTOR',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.businessName != null &&
        authProvider.businessName!.isNotEmpty) {
      _businessNameController.text = authProvider.businessName!;
    }
    if (authProvider.businessType != null &&
        authProvider.businessType!.isNotEmpty) {
      if (_businessTypes.contains(authProvider.businessType!.toUpperCase())) {
        _selectedBusinessType = authProvider.businessType!.toUpperCase();
      }
    }
    if (authProvider.verificationId != null) {
      _regIdController.text = authProvider.verificationId!;
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _regIdController.dispose();
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
      await authProvider.submitBuyerVerification(
        businessName: _businessNameController.text.trim(),
        businessType: _selectedBusinessType,
        registrationIdentifier: _regIdController.text.trim(),
        supportingDocument: _docController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Buyer business verification submitted successfully! Status: PENDING'),
          backgroundColor: AppColors.success,
        ),
      );

      context.go(AppConstants.routeBuyerDashboard);
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
        title: const Text('Verify Buyer Account'),
        backgroundColor: AppColors.secondary,
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
                    backgroundColor: Color(0xFFFEF3C7),
                    child: Icon(Icons.storefront,
                        size: 40, color: AppColors.secondary),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Verify Buyer Account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Collect business details to verify your commercial buyer identity.',
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
                                    ? 'Your business verification is complete.'
                                    : status == 'REJECTED'
                                        ? 'Verification rejected. Please update details and resubmit.'
                                        : 'Your business verification submission is pending review.',
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
                  controller: _businessNameController,
                  decoration: const InputDecoration(
                    labelText: 'Business Name *',
                    hintText: 'e.g. Apex Agri Traders Pvt Ltd',
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Business Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _selectedBusinessType,
                  decoration: const InputDecoration(
                    labelText: 'Business Type *',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _businessTypes
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedBusinessType = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _regIdController,
                  decoration: const InputDecoration(
                    labelText: 'GSTIN / Business Registration Identifier *',
                    hintText: 'e.g. GSTIN29ABCDE1234F1Z5',
                    prefixIcon: Icon(Icons.receipt_long),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Registration Identifier / GSTIN is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _docController,
                  decoration: const InputDecoration(
                    labelText: 'Supporting Business Document URL (Optional)',
                    hintText: 'https://example.com/gst-certificate.pdf',
                    prefixIcon: Icon(Icons.attach_file),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmitVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
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
                              ? 'Update Business Info'
                              : 'Submit Buyer Verification',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    context.go(AppConstants.routeBuyerDashboard);
                  },
                  child: const Text('Return to Buyer Dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
