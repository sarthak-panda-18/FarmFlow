import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/recommendation_model.dart';
import '../../services/api_service.dart';
import '../../widgets/farm_badge.dart';
import '../../widgets/farm_card.dart';
import '../../widgets/farm_empty_state.dart';
import '../../widgets/farm_financial_breakdown.dart';
import '../../widgets/farm_section_header.dart';

class FarmerRecommendationsScreen extends StatefulWidget {
  final String? initialCropId;

  const FarmerRecommendationsScreen({super.key, this.initialCropId});

  @override
  State<FarmerRecommendationsScreen> createState() =>
      _FarmerRecommendationsScreenState();
}

class _FarmerRecommendationsScreenState
    extends State<FarmerRecommendationsScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _currencyFormatter = NumberFormat('#,##,###', 'en_IN');

  bool _isLoading = true;
  String? _errorMessage;
  List<CropRecommendationData> _cropRecommendations = [];
  int _selectedCropIndex = 0;
  bool _showComparisonTable = false;

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.initialCropId != null && widget.initialCropId!.isNotEmpty) {
        final res =
            await _apiService.getCropRecommendations(widget.initialCropId!);
        if (mounted && res.data != null && res.data['success'] == true) {
          final data = CropRecommendationData.fromJson(res.data['data']);
          setState(() {
            _cropRecommendations = [data];
            _selectedCropIndex = 0;
            _isLoading = false;
          });
          return;
        }
      }

      final res = await _apiService.getFarmerRecommendations();
      if (mounted && res.data != null && res.data['success'] == true) {
        final List rawList = res.data['data'] ?? [];
        final list = rawList
            .map((item) => CropRecommendationData.fromJson(item))
            .toList();
        setState(() {
          _cropRecommendations = list;
          _selectedCropIndex = 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              res.data?['message'] ?? 'Unable to load buyer recommendations.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Unable to load recommendations. Please check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  String _formatCurrency(num value) {
    return '₹${_currencyFormatter.format(value)}';
  }

  Future<void> _openMaps(String? url) async {
    if (url == null ||
        url.isEmpty ||
        url.contains('query=,') ||
        url.contains('query=%2C')) {
      return;
    }
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open map URL.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error launching map application.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Where Can I Sell?'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh Recommendations',
            onPressed: _fetchRecommendations,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Analyzing Selling Opportunities...',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary),
              ),
              SizedBox(height: 6),
              Text(
                'Calculating Net Value = Selling Price - Transport - Other Costs',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchRecommendations,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_cropRecommendations.isEmpty) {
      return FarmEmptyState(
        icon: Icons.grass_outlined,
        title: 'No active crops listed',
        message:
            'Add your crop listings to receive buyer offers and automated Net Value selling recommendations.',
        actionLabel: 'Add Crop Now',
        actionIcon: Icons.add_circle_outline,
        onAction: () => context.push(AppConstants.routeAddCrop),
      );
    }

    final currentCropData = _cropRecommendations[_selectedCropIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Crop Selector Dropdown if multiple crops
          if (_cropRecommendations.length > 1) ...[
            _buildCropSelectorBar(),
            const SizedBox(height: 14),
          ],

          // Active Crop Summary Card (Pale Green)
          _buildCropHeaderCard(currentCropData),
          const SizedBox(height: 18),

          // Main Content Section
          if (currentCropData.interestedBuyersCount == 0)
            _buildNoBuyerFoundState(currentCropData)
          else if (!currentCropData.isRecommendationActive)
            _buildFewerThanThreeBuyersState(currentCropData)
          else
            _buildActiveRecommendationSection(currentCropData),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCropSelectorBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.grass, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          const Text('Select Crop:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textPrimary)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedCropIndex,
                isExpanded: true,
                items: List.generate(_cropRecommendations.length, (idx) {
                  final c = _cropRecommendations[idx];
                  return DropdownMenuItem<int>(
                    value: idx,
                    child: Text(
                      '${c.cropName} (${c.quantity} Q) — ${c.interestedBuyersCount} Buyers',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
                onChanged: (newIdx) {
                  if (newIdx != null) {
                    setState(() {
                      _selectedCropIndex = newIdx;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropHeaderCard(CropRecommendationData data) {
    return FarmCard(
      variant: FarmCardVariant.paleGreen,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: const Center(
                  child: Icon(Icons.agriculture,
                      color: AppColors.primary, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.cropName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary),
                    ),
                    Text(
                      '${data.commodity}${data.variety.isNotEmpty ? " • ${data.variety}" : ""}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              FarmBadge(
                label: data.isRecommendationActive
                    ? '⭐ AI Recommended'
                    : '${data.interestedBuyersCount} / 3 Buyers',
                type: data.isRecommendationActive
                    ? FarmBadgeType.success
                    : FarmBadgeType.warning,
              ),
            ],
          ),
          const Divider(height: 22, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniCropStat('Listed Quantity', '${data.quantity} Quintal'),
              _buildMiniCropStat('Expected Price',
                  '${_formatCurrency(data.expectedPrice)} / Q'),
              _buildMiniCropStat(
                  'Offers Received', '${data.interestedBuyersCount} Buyers'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCropStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
      ],
    );
  }

  // 0 Buyers State
  Widget _buildNoBuyerFoundState(CropRecommendationData data) {
    return FarmCard(
      variant: FarmCardVariant.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F3E5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_search_outlined,
                size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Buyers Yet',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'We couldn\'t find active buyer interest for this crop listing yet. We\'ll notify you as soon as buyers place offers or express interest.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push(AppConstants.routeMyCrops),
                icon: const Icon(Icons.grass, size: 16),
                label: const Text('View Crop Details'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => context.go(AppConstants.routeFarmerDashboard),
                icon: const Icon(Icons.dashboard, size: 16),
                label: const Text('Dashboard'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 1-2 Buyers State (Recommendation not yet active)
  Widget _buildFewerThanThreeBuyersState(CropRecommendationData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${data.interestedBuyersCount} ${data.interestedBuyersCount == 1 ? "Buyer has" : "Buyers have"} expressed interest. The AI Recommendation Engine ranks options once 3 or more buyers are available.',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF1E40AF), height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FarmSectionHeader(
          title: 'Interested Buyers (${data.allBuyers.length})',
          subtitle: 'Review incoming buyer offers and proceed to connect',
          icon: Icons.people_outline,
        ),
        ...data.allBuyers.map((buyer) => _buildStandardBuyerCard(buyer, data)),
      ],
    );
  }

  // 3+ Buyers State (Recommendation Active)
  Widget _buildActiveRecommendationSection(CropRecommendationData data) {
    final recommended = data.recommendedBuyer;
    final otherBuyers = data.allBuyers
        .where((b) => b.opportunityId != recommended?.opportunityId)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Best Selling Option',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Ranked by highest expected Net Value',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _showComparisonTable = !_showComparisonTable;
                });
              },
              icon: Icon(
                  _showComparisonTable
                      ? Icons.view_agenda_outlined
                      : Icons.table_chart_outlined,
                  size: 15),
              label: Text(_showComparisonTable ? 'Card View' : 'Compare Table'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_showComparisonTable) ...[
          _buildComparisonMatrixTable(data),
          const SizedBox(height: 18),
        ],

        // TOP RECOMMENDED BUYER CARD (Rank #1)
        if (recommended != null) ...[
          _buildTopRecommendedBuyerCard(recommended, data),
          const SizedBox(height: 22),
        ],

        // OTHER BUYERS
        if (otherBuyers.isNotEmpty) ...[
          FarmSectionHeader(
            title: 'Other Interested Buyers (${otherBuyers.length})',
            subtitle: 'Compare alternative buyer offers',
            icon: Icons.groups_outlined,
          ),
          ...otherBuyers
              .map((buyer) => _buildOtherBuyerCard(buyer, data, recommended)),
        ],
      ],
    );
  }

  // Rank #1 Recommended Buyer Card
  Widget _buildTopRecommendedBuyerCard(
      BuyerRecommendation buyer, CropRecommendationData data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryLight, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.star, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  '⭐ RECOMMENDED BUYER (RANK #1)',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.4),
                ),
                Spacer(),
                Text(
                  'HIGHEST NET VALUE',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 10),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Buyer Header
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2EFE0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.storefront,
                            color: AppColors.primary, size: 26),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            buyer.buyerName,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                          ),
                          if (buyer.businessName.isNotEmpty &&
                              buyer.businessName != buyer.buyerName)
                            Text(buyer.businessName,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 12, color: AppColors.textMuted),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  buyer.location,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (buyer.distanceKm != null)
                                FarmBadge(
                                  label:
                                      '${buyer.distanceKm!.toStringAsFixed(1)} km',
                                  type: FarmBadgeType.neutral,
                                  fontSize: 10,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Financial Breakdown Component
                FarmFinancialBreakdown(
                  sellingPrice: buyer.sellingPrice,
                  quantity: buyer.quantity,
                  quantityUnit: 'Quintal',
                  unitPrice: buyer.unitPrice,
                  transportationCost: buyer.transportationCost,
                  isTransportAvailable: buyer.isTransportAvailable,
                  otherCosts: buyer.otherCosts,
                  netValue: buyer.netValue,
                ),

                const SizedBox(height: 14),

                // Why this buyer is recommended section (Pale green box)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F8F0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD4E8CF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified,
                              color: AppColors.primary, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Why this buyer is recommended:',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data.explanation,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryDark,
                            height: 1.35),
                      ),
                      if (data.reasons.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        ...data.reasons.map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('✓ ',
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(
                                      r,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primaryDark),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Action Buttons Row
                Row(
                  children: [
                    if (buyer.googleMapsUrl.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _openMaps(buyer.googleMapsUrl),
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: const Text('View Location'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push(AppConstants.routeOpportunityDetail,
                              extra: buyer.opportunityId);
                        },
                        icon: const Icon(Icons.handshake, size: 18),
                        label: const Text('Proceed with Buyer'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Other Buyer Card (#2, #3)
  Widget _buildOtherBuyerCard(
    BuyerRecommendation buyer,
    CropRecommendationData data,
    BuyerRecommendation? recommended,
  ) {
    final netDiff =
        (recommended != null) ? recommended.netValue - buyer.netValue : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '#${buyer.rank}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        buyer.buyerName,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary),
                      ),
                      Text(
                        buyer.location,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(buyer.netValue),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                    if (netDiff > 0)
                      Text(
                        '- ${_formatCurrency(netDiff)} vs #1',
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.error,
                            fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ],
            ),
            const Divider(height: 18, color: AppColors.border),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMiniStat(
                    'Gross Selling', _formatCurrency(buyer.sellingPrice)),
                _buildMiniStat(
                  'Transport',
                  buyer.isTransportAvailable && buyer.transportationCost != null
                      ? _formatCurrency(buyer.transportationCost!)
                      : 'N/A',
                ),
                _buildMiniStat(
                    'Other Costs', _formatCurrency(buyer.otherCosts)),
                _buildMiniStat(
                    'Distance',
                    buyer.distanceKm != null
                        ? '${buyer.distanceKm!.toStringAsFixed(0)} km'
                        : 'N/A'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (buyer.googleMapsUrl.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _openMaps(buyer.googleMapsUrl),
                    icon: const Icon(Icons.map_outlined, size: 14),
                    label: const Text('Map', style: TextStyle(fontSize: 12)),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    context.push(AppConstants.routeOpportunityDetail,
                        extra: buyer.opportunityId);
                  },
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child:
                      const Text('View Offer', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardBuyerCard(
      BuyerRecommendation buyer, CropRecommendationData data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2EFE0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child:
                        Icon(Icons.person, color: AppColors.primary, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        buyer.buyerName,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary),
                      ),
                      Text(buyer.location,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Net Value',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                    Text(
                      _formatCurrency(buyer.netValue),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 18, color: AppColors.border),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMiniStat(
                    'Gross Selling', _formatCurrency(buyer.sellingPrice)),
                _buildMiniStat(
                  'Transport',
                  buyer.isTransportAvailable && buyer.transportationCost != null
                      ? _formatCurrency(buyer.transportationCost!)
                      : 'Unavailable',
                ),
                _buildMiniStat(
                    'Other Costs', _formatCurrency(buyer.otherCosts)),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push(AppConstants.routeOpportunityDetail,
                      extra: buyer.opportunityId);
                },
                icon: const Icon(Icons.handshake, size: 16),
                label: const Text('View Offer'),
                style: ElevatedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildComparisonMatrixTable(CropRecommendationData data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Buyer Comparison Matrix',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF2F8F0)),
              columnSpacing: 16,
              columns: const [
                DataColumn(
                    label: Text('Rank',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(
                    label: Text('Buyer',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(
                    label: Text('Selling Price',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(
                    label: Text('Transport',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(
                    label: Text('Net Value',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11))),
              ],
              rows: data.allBuyers.map((b) {
                final isTop = b.rank == 1;
                return DataRow(
                  color: isTop
                      ? WidgetStateProperty.all(const Color(0xFFF0FDF4))
                      : null,
                  cells: [
                    DataCell(Text('#${b.rank}',
                        style: TextStyle(
                            fontWeight:
                                isTop ? FontWeight.bold : FontWeight.normal))),
                    DataCell(Text(b.buyerName,
                        style: TextStyle(
                            fontWeight:
                                isTop ? FontWeight.bold : FontWeight.normal))),
                    DataCell(Text(_formatCurrency(b.sellingPrice))),
                    DataCell(Text(b.transportationCost != null
                        ? _formatCurrency(b.transportationCost!)
                        : 'N/A')),
                    DataCell(Text(_formatCurrency(b.netValue),
                        style: TextStyle(
                            color: isTop
                                ? AppColors.primary
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.bold))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
