import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../services/api_service.dart';

class RateBuyerScreen extends StatefulWidget {
  final String opportunityId;

  const RateBuyerScreen({super.key, required this.opportunityId});

  @override
  State<RateBuyerScreen> createState() => _RateBuyerScreenState();
}

class _RateBuyerScreenState extends State<RateBuyerScreen> {
  final ApiService _apiService = ApiService();

  double _overallRating = 5.0;
  double _customerInteraction = 5.0;
  double _paymentExperience = 5.0;
  double _communication = 5.0;
  double _transactionExperience = 5.0;

  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.rateBuyer(
        opportunityId: widget.opportunityId,
        rating: _overallRating,
        categoryRatings: {
          'customerInteraction': _customerInteraction.toInt(),
          'paymentExperience': _paymentExperience.toInt(),
          'communication': _communication.toInt(),
          'transactionExperience': _transactionExperience.toInt(),
        },
        comment: _commentController.text.trim(),
      );

      if (!mounted) return;

      if (res.data != null && res.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your feedback has been submitted successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true);
      } else {
        setState(() {
          _errorMessage = res.data?['message'] ?? 'Unable to submit feedback.';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Widget _buildStarSelector(double value, ValueChanged<double> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1.0;
        return IconButton(
          icon: Icon(
            starValue <= value ? Icons.star : Icons.star_border,
            color: const Color(0xFFD97706),
            size: 30,
          ),
          onPressed: _isSubmitting ? null : () => onChanged(starValue),
        );
      }),
    );
  }

  Widget _buildCategorySlider(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          _buildStarSelector(value, onChanged),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rate Buyer'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  border: Border.all(color: AppColors.error),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Overall Rating Card
            Card(
              elevation: AppConstants.cardElevation,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                child: Column(
                  children: [
                    const Text(
                      'Overall Rating',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    _buildStarSelector(_overallRating, (val) {
                      setState(() => _overallRating = val);
                    }),
                    Text(
                      '${_overallRating.toInt()} / 5 Stars',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Detailed Category Ratings Card
            Card(
              elevation: AppConstants.cardElevation,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Feedback Categories',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const Divider(height: 20),
                    _buildCategorySlider('Customer Interaction', _customerInteraction, (val) {
                      setState(() => _customerInteraction = val);
                    }),
                    _buildCategorySlider('Payment Experience', _paymentExperience, (val) {
                      setState(() => _paymentExperience = val);
                    }),
                    _buildCategorySlider('Communication', _communication, (val) {
                      setState(() => _communication = val);
                    }),
                    _buildCategorySlider('Transaction Experience', _transactionExperience, (val) {
                      setState(() => _transactionExperience = val);
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Comments
            TextField(
              controller: _commentController,
              enabled: !_isSubmitting,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Comments (Optional)',
                hintText: 'e.g. Good communication and smooth transaction.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
              ),
              onPressed: _isSubmitting ? null : _handleSubmit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Submit Feedback',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
