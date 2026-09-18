import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../services/api_service.dart';

class RateFarmerScreen extends StatefulWidget {
  final String opportunityId;

  const RateFarmerScreen({super.key, required this.opportunityId});

  @override
  State<RateFarmerScreen> createState() => _RateFarmerScreenState();
}

class _RateFarmerScreenState extends State<RateFarmerScreen> {
  final ApiService _apiService = ApiService();

  double _overallRating = 5.0;
  double _productQuality = 5.0;
  double _freshness = 5.0;
  double _spoilage = 5.0;
  double _quantityAccuracy = 5.0;
  double _farmerInteraction = 5.0;
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
      final res = await _apiService.rateFarmer(
        opportunityId: widget.opportunityId,
        rating: _overallRating,
        categoryRatings: {
          'productQuality': _productQuality.toInt(),
          'freshness': _freshness.toInt(),
          'spoilage': _spoilage.toInt(),
          'quantityAccuracy': _quantityAccuracy.toInt(),
          'farmerInteraction': _farmerInteraction.toInt(),
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
        Navigator.pop(context, true);
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
            size: 28,
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
        title: const Text('Rate Farmer'),
        backgroundColor: AppColors.secondary,
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
                      'Overall Farmer Rating',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    _buildStarSelector(_overallRating, (val) => setState(() => _overallRating = val)),
                    Text(
                      '${_overallRating.toStringAsFixed(0)} / 5 Stars',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Detailed Feedback Categories Card
            Card(
              elevation: AppConstants.cardElevation,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detailed Feedback Categories',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const Divider(height: 20),
                    _buildCategorySlider('Product Quality', _productQuality, (v) => setState(() => _productQuality = v)),
                    _buildCategorySlider('Freshness', _freshness, (v) => setState(() => _freshness = v)),
                    _buildCategorySlider('Spoilage', _spoilage, (v) => setState(() => _spoilage = v)),
                    _buildCategorySlider('Quantity Accuracy', _quantityAccuracy, (v) => setState(() => _quantityAccuracy = v)),
                    _buildCategorySlider('Farmer Interaction', _farmerInteraction, (v) => setState(() => _farmerInteraction = v)),
                    _buildCategorySlider('Transaction Experience', _transactionExperience, (v) => setState(() => _transactionExperience = v)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Comments
            Card(
              elevation: AppConstants.cardElevation,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Additional Comments (Optional)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _commentController,
                      maxLines: 3,
                      maxLength: 300,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Good quality product and smooth interaction...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
                ),
                onPressed: _isSubmitting ? null : _handleSubmit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Submit Feedback',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
