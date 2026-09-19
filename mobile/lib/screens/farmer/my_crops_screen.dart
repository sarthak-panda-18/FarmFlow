import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_strings.dart';
import '../../models/crop_model.dart';
import '../../services/api_service.dart';
import '../../widgets/farm_badge.dart';
import '../../widgets/farm_bottom_nav.dart';
import '../../widgets/farm_empty_state.dart';

class MyCropsScreen extends StatefulWidget {
  const MyCropsScreen({super.key});

  @override
  State<MyCropsScreen> createState() => _MyCropsScreenState();
}

class _MyCropsScreenState extends State<MyCropsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  List<CropModel> _crops = [];

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
    _loadCrops();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = _months[date.month - 1];
    final year = date.year;
    return '$day $month $year';
  }

  Future<void> _loadCrops() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getMyCrops();
      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> body = response.data;
        if (body['success'] == true) {
          final List<dynamic> data = body['data'] ?? [];
          final cropsList =
              data.map((item) => CropModel.fromJson(item)).toList();
          if (mounted) {
            setState(() {
              _crops = cropsList;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _errorMessage = body['message'] ?? 'Unable to load your crops.';
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to connect to the server.';
          _isLoading = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.myCrops),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh Crops',
            onPressed: _loadCrops,
          ),
        ],
      ),
      bottomNavigationBar: const FarmBottomNav(currentIndex: 1, role: 'FARMER'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push<bool>(AppConstants.routeAddCrop);
          if (result == true || mounted) {
            _loadCrops();
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Crop',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadCrops,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 52, color: AppColors.error),
              const SizedBox(height: 14),
              Text(
                'Unable to load crops',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _loadCrops,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_crops.isEmpty) {
      return FarmEmptyState(
        icon: Icons.grass_outlined,
        title: 'No crops added yet',
        message:
            'List your harvested and available crops to connect with buyers and mandis.',
        actionLabel: 'Add Crop Listing',
        actionIcon: Icons.add,
        onAction: () async {
          final result = await context.push<bool>(AppConstants.routeAddCrop);
          if (result == true || mounted) {
            _loadCrops();
          }
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: _crops.length,
      itemBuilder: (context, index) {
        final crop = _crops[index];
        final harvestStr = _formatDate(crop.harvestDate);
        final locationParts = [crop.market, crop.district, crop.state];
        final locationStr =
            locationParts.where((e) => e != null && e.isNotEmpty).join(', ');

        final subtitleParts = <String>[];
        if (crop.variety != null && crop.variety!.isNotEmpty) {
          subtitleParts.add(crop.variety!);
        }
        if (crop.grade != null && crop.grade!.isNotEmpty) {
          subtitleParts.add(crop.grade!);
        }
        final varietyGradeStr =
            subtitleParts.isNotEmpty ? subtitleParts.join(' • ') : 'Standard';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () async {
                final result = await context.push<bool>(
                  AppConstants.routeCropDetail,
                  extra: crop,
                );
                if (result == true && mounted) {
                  _loadCrops();
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Commodity & Status Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2EFE0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(Icons.grass,
                                    color: AppColors.primary, size: 20),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  crop.cropName.isNotEmpty
                                      ? crop.cropName
                                      : crop.commodity,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${crop.commodity} • $varietyGradeStr',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                        FarmBadge(
                          label: crop.status.toUpperCase(),
                          type: _getBadgeType(crop.status),
                        ),
                      ],
                    ),

                    const Divider(height: 20, color: AppColors.border),

                    // Metrics Row (Quantity & Expected Price)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined,
                                size: 15, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${crop.quantity} ${crop.quantityUnit}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (crop.expectedPrice != null &&
                            crop.expectedPrice! > 0)
                          Row(
                            children: [
                              const Text('Expected: ',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted)),
                              Text(
                                '₹${crop.expectedPrice!.toStringAsFixed(0)} / Q',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Harvest Date & Location Row
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Harvest: $harvestStr',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                        if (locationStr.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              locationStr,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
