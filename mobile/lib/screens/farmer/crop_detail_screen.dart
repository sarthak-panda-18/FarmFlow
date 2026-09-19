import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/crop_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/farm_badge.dart';
import '../../widgets/farm_card.dart';

class CropDetailScreen extends StatefulWidget {
  final CropModel crop;

  const CropDetailScreen({super.key, required this.crop});

  @override
  State<CropDetailScreen> createState() => _CropDetailScreenState();
}

class _CropDetailScreenState extends State<CropDetailScreen> {
  late CropModel _crop;
  bool _isDeleting = false;

  static const List<String> _months = [
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

  @override
  void initState() {
    super.initState();
    _crop = widget.crop;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = _months[date.month - 1];
    final year = date.year;
    return '$day $month $year';
  }

  FarmBadgeType _getBadgeType(String status) {
    switch (status.toUpperCase()) {
      case 'AVAILABLE':
        return FarmBadgeType.success;
      case 'RESERVED':
        return FarmBadgeType.warning;
      case 'SOLD':
        return FarmBadgeType.info;
      case 'CANCELLED':
        return FarmBadgeType.error;
      default:
        return FarmBadgeType.neutral;
    }
  }

  Future<void> _confirmDelete() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Crop?'),
          content: const Text(
            'Are you sure you want to delete this crop? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      _deleteCrop();
    }
  }

  Future<void> _deleteCrop() async {
    setState(() {
      _isDeleting = true;
    });

    try {
      final response = await ApiService().deleteCrop(_crop.id);

      if (!mounted) return;

      final body = response.data as Map<String, dynamic>?;
      if (response.statusCode == 200 &&
          (body == null || body['success'] == true)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body?['message'] ?? 'Crop deleted successfully.'),
            backgroundColor: AppColors.primary,
          ),
        );
        context.pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body?['message'] ?? 'Failed to delete crop.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Error deleting crop: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.userId;
    final isFarmer = authProvider.userRole == 'FARMER';
    final isOwner = _crop.farmerId == null ||
        _crop.farmerId!.isEmpty ||
        _crop.farmerId == currentUserId;

    final formattedHarvestDate = _formatDate(_crop.harvestDate);
    final formattedCreatedDate =
        _crop.createdAt != null ? _formatDate(_crop.createdAt!) : 'N/A';

    final canEdit =
        (isFarmer || isOwner) && _crop.status.toUpperCase() == 'AVAILABLE';
    final canDelete = (isFarmer || isOwner) &&
        _crop.status.toUpperCase() != 'RESERVED' &&
        _crop.status.toUpperCase() != 'SOLD';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Crop Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              tooltip: 'Edit Crop',
              onPressed: () async {
                final updated = await context.push<CropModel>(
                  AppConstants.routeEditCrop,
                  extra: _crop,
                );
                if (updated != null && mounted) {
                  setState(() {
                    _crop = updated;
                  });
                }
              },
            ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Delete Crop',
              onPressed: _isDeleting ? null : _confirmDelete,
            ),
        ],
      ),
      body: _isDeleting
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Summary Card (Pale Green)
                  FarmCard(
                    variant: FarmCardVariant.paleGreen,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _crop.cropName.isNotEmpty
                                    ? _crop.cropName
                                    : _crop.commodity,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            FarmBadge(
                              label: _crop.status.toUpperCase(),
                              type: _getBadgeType(_crop.status),
                            ),
                          ],
                        ),
                        if (_crop.cropName != _crop.commodity &&
                            _crop.cropName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Commodity: ${_crop.commodity}',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                        const Divider(height: 20, color: AppColors.border),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Listed Quantity',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted)),
                                const SizedBox(height: 2),
                                Text(
                                  '${_crop.quantity} ${_crop.quantityUnit}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            if (_crop.expectedPrice != null &&
                                _crop.expectedPrice! > 0)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Expected Price',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${_crop.expectedPrice!.toStringAsFixed(0)} / ${_crop.quantityUnit}',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Crop Specifications Card (White)
                  FarmCard(
                    variant: FarmCardVariant.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.category_outlined,
                                color: AppColors.primary, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Crop Specifications',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        _buildDetailRow(
                          icon: Icons.grass,
                          label: 'Variety',
                          value: (_crop.variety != null &&
                                  _crop.variety!.isNotEmpty)
                              ? _crop.variety!
                              : 'Standard / Desi',
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Harvest / Availability Date',
                          value: formattedHarvestDate,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.access_time,
                          label: 'Listed On',
                          value: formattedCreatedDate,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Location Details Card (White)
                  FarmCard(
                    variant: FarmCardVariant.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                color: AppColors.primary, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Farm & Market Location',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        _buildDetailRow(
                          icon: Icons.map_outlined,
                          label: 'State',
                          value: _crop.state,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.location_city_outlined,
                          label: 'District',
                          value: _crop.district,
                        ),
                        if (_crop.market != null &&
                            _crop.market!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            icon: Icons.storefront_outlined,
                            label: 'Market / APMC Yard',
                            value: _crop.market!,
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (_crop.description != null &&
                      _crop.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    FarmCard(
                      variant: FarmCardVariant.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Additional Notes',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                          ),
                          const Divider(height: 18),
                          Text(
                            _crop.description!,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Primary Action: Where Can I Sell / Buyer Recommendations
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.psychology_outlined, size: 20),
                      label:
                          const Text('Where Can I Sell? (AI Recommendations)'),
                      onPressed: () {
                        context.push(AppConstants.routeFarmerRecommendations,
                            extra: _crop.id);
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Secondary Action: Matched Buyers
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.compare_arrows, size: 18),
                      label: const Text('View Matched Buyers'),
                      onPressed: () {
                        context.push(AppConstants.routeFarmerMatches,
                            extra: _crop.id);
                      },
                    ),
                  ),

                  if (canDelete) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppConstants.borderRadius),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: AppColors.error),
                        label: const Text(
                          'Delete Crop',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: _isDeleting ? null : _confirmDelete,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
