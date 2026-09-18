import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/crop_model.dart';
import '../../services/api_service.dart';

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

  Color _getStatusBgColor(String status) {
    switch (status.toUpperCase()) {
      case 'AVAILABLE':
        return const Color(0xFFDCFCE7);
      case 'RESERVED':
        return const Color(0xFFFEF3C7);
      case 'SOLD':
        return const Color(0xFFDBEAFE);
      case 'CANCELLED':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toUpperCase()) {
      case 'AVAILABLE':
        return const Color(0xFF166534);
      case 'RESERVED':
        return const Color(0xFF92400E);
      case 'SOLD':
        return const Color(0xFF1E40AF);
      case 'CANCELLED':
        return const Color(0xFF991B1B);
      default:
        return const Color(0xFF374151);
    }
  }

  Future<void> _confirmDelete() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Crop'),
          content: Text(
            'Are you sure you want to remove "${_crop.commodity}" from your listed crops?',
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
              child: const Text('Remove'),
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

      final body = response.data as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['message'] ?? 'Crop deleted successfully'),
            backgroundColor: AppColors.primary,
          ),
        );
        context.pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['message'] ?? 'Failed to delete crop'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting crop: ${e.toString()}'),
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
    final formattedHarvestDate = _formatDate(_crop.harvestDate);
    final formattedCreatedDate = _crop.createdAt != null
        ? _formatDate(_crop.createdAt!)
        : 'N/A';

    final canEdit = _crop.status.toUpperCase() == 'AVAILABLE';
    final canDelete = _crop.status.toUpperCase() != 'RESERVED' &&
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
              icon: const Icon(Icons.edit),
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
        ],
      ),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Header Card
                  Card(
                    elevation: AppConstants.cardElevation,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.borderRadius),
                    ),
                    child: Padding(
                      padding:
                          const EdgeInsets.all(AppConstants.paddingMedium),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _crop.commodity,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusBgColor(_crop.status),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _crop.status.toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusTextColor(_crop.status),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_crop.cropName != _crop.commodity) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Entered as: ${_crop.cropName}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.inventory_2,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                '${_crop.quantity} ${_crop.quantityUnit}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                              ),
                              const Spacer(),
                              if (_crop.expectedPrice != null) ...[
                                const Icon(Icons.currency_rupee,
                                    size: 18, color: AppColors.secondary),
                                Text(
                                  'Expected: ₹${_crop.expectedPrice!.toStringAsFixed(0)} / ${_crop.quantityUnit}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.secondary,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Crop Specifications Card
                  Card(
                    elevation: AppConstants.cardElevation,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.borderRadius),
                    ),
                    child: Padding(
                      padding:
                          const EdgeInsets.all(AppConstants.paddingMedium),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Crop Specifications',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(
                            context,
                            icon: Icons.category,
                            label: 'Variety',
                            value: (_crop.variety != null && _crop.variety!.isNotEmpty)
                                ? _crop.variety!
                                : 'Standard / Unspecified',
                          ),
                          if (_crop.grade != null && _crop.grade!.isNotEmpty && _crop.grade != 'FAQ') ...[
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              context,
                              icon: Icons.grade,
                              label: 'Grade / Quality',
                              value: _crop.grade!,
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            context,
                            icon: Icons.calendar_today,
                            label: 'Expected Harvest Date',
                            value: formattedHarvestDate,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            context,
                            icon: Icons.access_time,
                            label: 'Listed On',
                            value: formattedCreatedDate,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Location Details Card
                  Card(
                    elevation: AppConstants.cardElevation,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.borderRadius),
                    ),
                    child: Padding(
                      padding:
                          const EdgeInsets.all(AppConstants.paddingMedium),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location Details',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(
                            context,
                            icon: Icons.map,
                            label: 'State',
                            value: _crop.state,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            context,
                            icon: Icons.location_city,
                            label: 'District',
                            value: _crop.district,
                          ),
                          if (_crop.market != null &&
                              _crop.market!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              context,
                              icon: Icons.store,
                              label: 'Market / Mandi',
                              value: _crop.market!,
                            ),
                          ],
                          if (_crop.location != null &&
                              _crop.location!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              context,
                              icon: Icons.pin_drop,
                              label: 'Specific Location',
                              value: _crop.location!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  if (_crop.description != null &&
                      _crop.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: AppConstants.cardElevation,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.borderRadius),
                      ),
                      child: Padding(
                        padding:
                            const EdgeInsets.all(AppConstants.paddingMedium),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Description',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            const Divider(height: 20),
                            Text(
                              _crop.description!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Secondary Action: View Market Prices for this commodity
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.borderRadius),
                        ),
                      ),
                      icon: const Icon(Icons.trending_up),
                      label: Text('View Market Prices for ${_crop.commodity}'),
                      onPressed: () {
                        context.push(AppConstants.routeMarketPrices);
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Edit & Delete Action Buttons
                  Row(
                    children: [
                      if (canEdit) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppConstants.borderRadius),
                              ),
                            ),
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit Crop'),
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
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (canDelete)
                        Expanded(
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
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete Crop'),
                            onPressed: _confirmDelete,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
