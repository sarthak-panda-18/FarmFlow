import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/recommendation_model.dart';
import '../../services/api_service.dart';

class FarmerRecommendationsScreen extends StatefulWidget {
  final String? initialCropId;

  const FarmerRecommendationsScreen({super.key, this.initialCropId});

  @override
  State<FarmerRecommendationsScreen> createState() => _FarmerRecommendationsScreenState();
}

class _FarmerRecommendationsScreenState extends State<FarmerRecommendationsScreen> {
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
        final res = await _apiService.getCropRecommendations(widget.initialCropId!);
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
        final list = rawList.map((item) => CropRecommendationData.fromJson(item)).toList();
        setState(() {
          _cropRecommendations = list;
          _selectedCropIndex = 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res.data?['message'] ?? 'Unable to load buyer recommendations.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to load recommendations. Please check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  String _formatCurrency(num value) {
    return '₹${_currencyFormatter.format(value)}';
  }

  Future<void> _openMaps(String? url) async {
    if (url == null || url.isEmpty) return;
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
        title: const Text('Buyer Recommendations'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Calculating Buyer Recommendations...',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            SizedBox(height: 6),
            Text(
              'Evaluating Net Value = Selling Price - Transport - Other Costs',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchRecommendations,
                icon: const Icon(Icons.refresh),
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
      return _buildNoCropsFoundState();
    }

    final currentCropData = _cropRecommendations[_selectedCropIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Crop Selector Header if multiple crops exist
          if (_cropRecommendations.length > 1) ...[
            _buildCropSelectorBar(),
            const SizedBox(height: 16),
          ],

          // Active Crop Summary Card
          _buildCropHeaderCard(currentCropData),
          const SizedBox(height: 16),

          // Main Content based on Interested Buyers Count
          if (currentCropData.interestedBuyersCount == 0)
            _buildNoBuyerFoundState(currentCropData)
          else if (!currentCropData.isRecommendationActive)
            _buildFewerThanThreeBuyersState(currentCropData)
          else
            _buildActiveRecommendationSection(currentCropData),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCropSelectorBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.grass, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          const Text('Select Crop:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                      '${c.cropName} (${c.quantity} Quintal) - ${c.interestedBuyersCount} Buyers',
                      style: const TextStyle(fontSize: 13),
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
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.agriculture, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.cropName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${data.commodity}${data.variety.isNotEmpty ? " • ${data.variety}" : ""}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: data.isRecommendationActive
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    data.isRecommendationActive
                        ? '⭐ Recommendation Active'
                        : '${data.interestedBuyersCount} / 3 Buyers',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: data.isRecommendationActive
                          ? const Color(0xFF166534)
                          : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMiniCropStat('Listed Quantity', '${data.quantity} Quintal'),
                _buildMiniCropStat('Expected Price', '${_formatCurrency(data.expectedPrice)} / Q'),
                _buildMiniCropStat('Interested Buyers', '${data.interestedBuyersCount} Buyers'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCropStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }

  // -------------------------------------------------------------
  // 0 BUYERS STATE
  // -------------------------------------------------------------
  Widget _buildNoBuyerFoundState(CropRecommendationData data) {
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_search_outlined, size: 48, color: AppColors.secondary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Buyer Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'We couldn\'t find a Buyer matching your crop, quantity, location and requirements right now.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 6),
            const Text(
              'We\'ll notify you when a suitable Buyer becomes available.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.push(AppConstants.routeMyCrops),
                  icon: const Icon(Icons.grass, size: 16),
                  label: const Text('View My Crop'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => context.go(AppConstants.routeFarmerDashboard),
                  icon: const Icon(Icons.dashboard, size: 16),
                  label: const Text('Dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCropsFoundState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.grass_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'No Active Crops Listed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your crop listings to receive buyer offers and automated Net Value recommendations.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push(AppConstants.routeAddCrop),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add Crop Now'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 1-2 BUYERS STATE
  // -------------------------------------------------------------
  Widget _buildFewerThanThreeBuyersState(CropRecommendationData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${data.interestedBuyersCount} ${data.interestedBuyersCount == 1 ? "Buyer is" : "Buyers are"} interested in this crop. The automated Recommendation Engine activates when 3 or more buyers express interest.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Interested Buyers (${data.allBuyers.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),

        ...data.allBuyers.map((buyer) => _buildStandardBuyerCard(buyer, data)),
      ],
    );
  }

  // -------------------------------------------------------------
  // 3+ BUYERS STATE (RECOMMENDATION ENGINE ACTIVE)
  // -------------------------------------------------------------
  Widget _buildActiveRecommendationSection(CropRecommendationData data) {
    final recommended = data.recommendedBuyer;
    final otherBuyers = data.allBuyers.where((b) => b.opportunityId != recommended?.opportunityId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle Matrix vs Cards
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Best Buyer Option',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                ),
                const Text(
                  'Ranked by expected Net Value',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _showComparisonTable = !_showComparisonTable;
                });
              },
              icon: Icon(_showComparisonTable ? Icons.view_agenda_outlined : Icons.table_chart_outlined, size: 16),
              label: Text(_showComparisonTable ? 'Card View' : 'Compare Table'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_showComparisonTable) ...[
          _buildComparisonMatrixTable(data),
          const SizedBox(height: 20),
        ],

        // TOP RECOMMENDED BUYER CARD
        if (recommended != null) ...[
          _buildTopRecommendedBuyerCard(recommended, data),
          const SizedBox(height: 24),
        ],

        // OTHER INTERESTED BUYERS
        if (otherBuyers.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.people_alt_outlined, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Other Interested Buyers (${otherBuyers.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...otherBuyers.map((buyer) => _buildOtherBuyerCard(buyer, data, recommended)),
        ],
      ],
    );
  }

  // -------------------------------------------------------------
  // TOP RECOMMENDED BUYER CARD WIDGET
  // -------------------------------------------------------------
  Widget _buildTopRecommendedBuyerCard(BuyerRecommendation buyer, CropRecommendationData data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(color: const Color(0xFF16A34A), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.12),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppConstants.borderRadius - 2),
                topRight: Radius.circular(AppConstants.borderRadius - 2),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.star, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  '⭐ RECOMMENDED BUYER (RANK #1)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                ),
                Spacer(),
                Text(
                  'HIGHEST NET VALUE',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Buyer Info Header
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xFFDCFCE7),
                      child: Icon(Icons.store, color: Color(0xFF16A34A), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            buyer.buyerName,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          if (buyer.businessName.isNotEmpty && buyer.businessName != buyer.buyerName)
                            Text(buyer.businessName, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  buyer.location,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (buyer.distanceKm != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${buyer.distanceKm!.toStringAsFixed(1)} km',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // FINANCIAL BREAKDOWN BOX
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildFinancialRow(
                        'Selling Price (${buyer.quantity} Q @ ${_formatCurrency(buyer.unitPrice)}/Q)',
                        _formatCurrency(buyer.sellingPrice),
                        isPositive: true,
                      ),
                      const SizedBox(height: 6),
                      _buildFinancialRow(
                        'Transportation Cost',
                        buyer.isTransportAvailable && buyer.transportationCost != null
                            ? '- ${_formatCurrency(buyer.transportationCost!)}'
                            : 'Unavailable',
                        isNegative: buyer.isTransportAvailable && (buyer.transportationCost ?? 0) > 0,
                      ),
                      const SizedBox(height: 6),
                      _buildFinancialRow(
                        'Other Costs (Handling/Packaging)',
                        buyer.otherCosts > 0 ? '- ${_formatCurrency(buyer.otherCosts)}' : '₹0',
                        isNegative: buyer.otherCosts > 0,
                      ),
                      const Divider(height: 16, thickness: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'EXPECTED NET VALUE',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                          ),
                          Text(
                            _formatCurrency(buyer.netValue),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // WHY THIS BUYER IS RECOMMENDED SECTION
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified, color: Color(0xFF16A34A), size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Why this buyer is recommended:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data.explanation,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.35),
                      ),
                      if (data.reasons.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...data.reasons.map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('✓ ', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(
                                      r,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF166534)),
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

                // Action Buttons
                Row(
                  children: [
                    if (buyer.googleMapsUrl.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _openMaps(buyer.googleMapsUrl),
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: const Text('View Location'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0284C7),
                          side: const BorderSide(color: Color(0xFF0284C7)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push(AppConstants.routeOpportunityDetail, extra: buyer.opportunityId);
                        },
                        icon: const Icon(Icons.handshake, size: 18),
                        label: const Text('Proceed with Buyer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 1,
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

  // -------------------------------------------------------------
  // OTHER BUYER CARD WIDGET
  // -------------------------------------------------------------
  Widget _buildOtherBuyerCard(
    BuyerRecommendation buyer,
    CropRecommendationData data,
    BuyerRecommendation? recommended,
  ) {
    final netDiff = (recommended != null) ? recommended.netValue - buyer.netValue : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFFF1F5F9),
                  child: Text(
                    '#${buyer.rank}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        buyer.buyerName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        buyer.location,
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    if (netDiff > 0)
                      Text(
                        '- ${_formatCurrency(netDiff)} vs #1',
                        style: const TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMiniStat('Selling Price', _formatCurrency(buyer.sellingPrice)),
                _buildMiniStat(
                  'Transport',
                  buyer.isTransportAvailable && buyer.transportationCost != null
                      ? _formatCurrency(buyer.transportationCost!)
                      : 'N/A',
                ),
                _buildMiniStat('Other Costs', _formatCurrency(buyer.otherCosts)),
                _buildMiniStat('Distance', buyer.distanceKm != null ? '${buyer.distanceKm!.toStringAsFixed(0)} km' : 'N/A'),
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
                    context.push(AppConstants.routeOpportunityDetail, extra: buyer.opportunityId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('View Offer', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardBuyerCard(BuyerRecommendation buyer, CropRecommendationData data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.person, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        buyer.buyerName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Text(buyer.location, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Net Value', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    Text(
                      _formatCurrency(buyer.netValue),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMiniStat('Selling Price', _formatCurrency(buyer.sellingPrice)),
                _buildMiniStat(
                  'Transport',
                  buyer.isTransportAvailable && buyer.transportationCost != null
                      ? _formatCurrency(buyer.transportationCost!)
                      : 'Unavailable',
                ),
                _buildMiniStat('Other Costs', _formatCurrency(buyer.otherCosts)),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push(AppConstants.routeOpportunityDetail, extra: buyer.opportunityId);
                },
                icon: const Icon(Icons.handshake, size: 16),
                label: const Text('View Offer'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // COMPARISON MATRIX TABLE
  // -------------------------------------------------------------
  Widget _buildComparisonMatrixTable(CropRecommendationData data) {
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.table_chart_outlined, color: AppColors.primary, size: 18),
                SizedBox(width: 8),
                Text('All Interested Buyers Comparison', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                dataRowMinHeight: 40,
                dataRowMaxHeight: 48,
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('Rank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Buyer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Selling Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Distance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Transport', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Other Costs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Net Value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
                rows: data.allBuyers.map((b) {
                  final isTop = b.rank == 1 && data.isRecommendationActive;
                  return DataRow(
                    color: isTop ? WidgetStateProperty.all(const Color(0xFFDCFCE7).withValues(alpha: 0.5)) : null,
                    cells: [
                      DataCell(
                        Text(
                          isTop ? '⭐ #1' : '#${b.rank}',
                          style: TextStyle(
                            fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                            color: isTop ? const Color(0xFF166534) : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      DataCell(Text(b.buyerName, style: TextStyle(fontWeight: isTop ? FontWeight.bold : FontWeight.normal))),
                      DataCell(Text(_formatCurrency(b.sellingPrice))),
                      DataCell(Text(b.distanceKm != null ? '${b.distanceKm!.toStringAsFixed(0)} km' : 'N/A')),
                      DataCell(Text(b.isTransportAvailable && b.transportationCost != null ? _formatCurrency(b.transportationCost!) : 'N/A')),
                      DataCell(Text(_formatCurrency(b.otherCosts))),
                      DataCell(
                        Text(
                          _formatCurrency(b.netValue),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isTop ? const Color(0xFF166534) : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialRow(String label, String value, {bool isPositive = false, bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isNegative
                ? AppColors.error
                : isPositive
                    ? AppColors.textPrimary
                    : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
