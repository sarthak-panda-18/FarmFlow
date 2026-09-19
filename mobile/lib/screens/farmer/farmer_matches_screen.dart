import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/match_model.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class FarmerMatchesScreen extends StatefulWidget {
  final String? cropId;

  const FarmerMatchesScreen({super.key, this.cropId});

  @override
  State<FarmerMatchesScreen> createState() => _FarmerMatchesScreenState();
}

class _FarmerMatchesScreenState extends State<FarmerMatchesScreen> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final NumberFormat _currencyFormatter = NumberFormat('#,##,###', 'en_IN');

  bool _isLoading = true;
  String? _errorMessage;
  List<MatchModel> _matches = [];

  double _maxDistance = 100.0;
  final List<double> _distanceOptions = [25.0, 50.0, 100.0, 200.0, 500.0];

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.getFarmerMatches(
        cropId: widget.cropId,
        maxDistance: _maxDistance,
      );

      if (res.data != null && res.data['success'] == true) {
        final rawList = res.data['data'];
        final List list = rawList is List ? rawList : [];
        setState(() {
          _matches = list
              .whereType<Map<String, dynamic>>()
              .map((m) => MatchModel.fromJson(m))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res.data?['message']?.toString() ??
              'Failed to load matching buyer requirements';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _openGoogleMaps(MatchModel match) async {
    final success = await _locationService.openGoogleMaps(
      latitude: match.latitude,
      longitude: match.longitude,
      address: match.location,
      label: (match.buyerName != null && match.buyerName!.isNotEmpty)
          ? '${match.buyerName} (Delivery Location)'
          : null,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to launch Google Maps location.')),
      );
    }
  }

  void _showExpressInterestDialog(MatchModel match) {
    final priceController = TextEditingController(
        text: match.farmerExpectedPrice.toStringAsFixed(0));
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Express Interest: ${match.commodity}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Buyer: ${match.buyerBusinessName?.isNotEmpty == true ? match.buyerBusinessName : match.buyerName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                  'Required Qty: ${match.buyerRequiredQty.toStringAsFixed(0)} ${match.buyerUnit}'),
              Text(
                  'Buyer Offered: ₹${_currencyFormatter.format(match.buyerExpectedPrice)} / Quintal'),
              if (match.isTransportAvailable && match.transportationCost != null)
                Text(
                    'Est. Transport: ₹${_currencyFormatter.format(match.transportationCost)} (${match.distanceKm?.toStringAsFixed(1) ?? "Nearby"} km)'),
              Text(
                'Expected Net Value: ₹${_currencyFormatter.format(match.netValue)} (₹${_currencyFormatter.format(match.netValuePerQ)}/Q)',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 20),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Your Offered Price (₹ / Quintal)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Message for Buyer (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                if (match.requirementId != null) {
                  await _apiService.farmerExpressInterest(
                    requirementId: match.requirementId!,
                    cropId: match.cropId,
                    offeredPrice: double.tryParse(priceController.text.trim()),
                    notes: notesController.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Interest submitted successfully to Buyer!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  final msg = e.toString().replaceAll('Exception: ', '');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(msg), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Send Interest'),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 75) return const Color(0xFF16A34A);
    if (score >= 50) return const Color(0xFFD97706);
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Matched Buyer Requirements'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMatches,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                const Text('Max Distance: ',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _distanceOptions.map((d) {
                        final isSelected = _maxDistance == d;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('${d.toInt()} km'),
                            selected: isSelected,
                            selectedColor:
                                AppColors.primary.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            onSelected: (val) {
                              if (val) {
                                setState(() => _maxDistance = d);
                                _fetchMatches();
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Total Matches Summary
          if (!_isLoading && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_matches.length} Compatible Buyers Found',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textSecondary),
                  ),
                  const Text('Ranked by Net Value & ML Signals',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),

          // Match List
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
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
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchMatches,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_matches.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_search_outlined,
                    size: 50, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text(
                'No matching buyer requirements found.',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                "We couldn't find a Buyer matching your crop, quantity, location and requirements right now.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_active_outlined,
                        size: 16, color: Color(0xFF16A34A)),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        "We'll notify you when a suitable Buyer becomes available.",
                        style: TextStyle(
                            color: Color(0xFF15803D),
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.push(AppConstants.routeMyCrops),
                    icon: const Icon(Icons.eco_outlined),
                    label: const Text('View My Crops'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.go(AppConstants.routeFarmerDashboard),
                    icon: const Icon(Icons.dashboard_outlined),
                    label: const Text('Go to Dashboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final topMatch = _matches.first;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: _matches.length,
      itemBuilder: (context, index) {
        final match = _matches[index];
        final bool isFirst = index == 0;

        if (isFirst) {
          return _buildRecommendedBuyerCard(match);
        }

        return _buildSecondaryBuyerCard(match, topMatch);
      },
    );
  }

  /// Top-ranked Recommended Buyer Card with full Net Value Breakdown and Why This Buyer Reasons
  Widget _buildRecommendedBuyerCard(MatchModel match) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 1.8),
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
          // Banner: RECOMMENDED BUYER (RANK #1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'RECOMMENDED BUYER (RANK #1)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${match.matchScore}% Match',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Buyer Business & Location Details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            match.buyerBusinessName?.isNotEmpty == true
                                ? match.buyerBusinessName!
                                : match.buyerName ?? 'Verified Buyer',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  match.location,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (match.distanceKm != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.near_me,
                                size: 12, color: Color(0xFF0284C7)),
                            const SizedBox(width: 4),
                            Text(
                              '${match.distanceKm!.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Lot Demand vs Farmer Available Qty
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Demand: ${match.buyerRequiredQty.toStringAsFixed(0)} Quintals',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Available: ${match.farmerAvailableQty.toStringAsFixed(0)} Quintals',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Transparent Economic Breakdown Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _buildFinancialRow(
                        label: 'Gross Selling Price',
                        value:
                            '₹${_currencyFormatter.format(match.sellingPrice)}',
                        subtext:
                            '₹${_currencyFormatter.format(match.unitPrice)} / Quintal',
                        isBold: true,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(height: 6),
                      _buildFinancialRow(
                        label: 'Transportation Cost',
                        value: match.isTransportAvailable &&
                                match.transportationCost != null
                            ? '- ₹${_currencyFormatter.format(match.transportationCost)}'
                            : 'Not required / Direct pickup',
                        subtext: match.distanceKm != null
                            ? '(${match.distanceKm!.toStringAsFixed(1)} km @ ₹25/km)'
                            : null,
                        color: const Color(0xFFDC2626),
                      ),
                      if (match.otherCosts > 0) ...[
                        const SizedBox(height: 6),
                        _buildFinancialRow(
                          label: 'Other Handling Costs',
                          value:
                              '- ₹${_currencyFormatter.format(match.otherCosts)}',
                          color: const Color(0xFFDC2626),
                        ),
                      ],
                      const Divider(height: 14, color: AppColors.border),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EXPECTED NET VALUE',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              Text(
                                'Highest Net Return for Farmer',
                                style: TextStyle(
                                    fontSize: 10, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${_currencyFormatter.format(match.netValue)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                '₹${_currencyFormatter.format(match.netValuePerQ)} / Quintal',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ML Price Benchmark Signal (if available)
                if (match.mlPrediction != null &&
                    match.mlPrediction!['available'] == true) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome,
                            size: 14, color: Color(0xFF16A34A)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'ML Market Forecast: ${match.mlPrediction!['formattedPrice'] ?? "₹${match.mlPrediction!['predictedPrice']} / Q"} (${match.mlPrediction!['comparison'] == 'ABOVE_FORECAST' ? 'Buyer offers above benchmark' : 'Market benchmark'})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // "WHY THIS BUYER?" Section
                if (match.recommendationReasons.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDCFCE7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 14, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text(
                              'WHY THIS BUYER?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: AppColors.primary,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...match.recommendationReasons.map(
                          (reason) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('✓ ',
                                    style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                                Expanded(
                                  child: Text(
                                    reason,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Actions: Google Maps & Express Interest
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openGoogleMaps(match),
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: const Text('Open Map',
                            style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showExpressInterestDialog(match),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Express Interest',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
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

  /// Secondary Matched Buyer Card (Rank #2, #3, etc.)
  Widget _buildSecondaryBuyerCard(MatchModel match, MatchModel? topMatch) {
    final scoreColor = _getScoreColor(match.matchScore);
    final double diffVsTop =
        topMatch != null ? topMatch.netValue - match.netValue : 0.0;

    return Card(
      elevation: AppConstants.cardElevation,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Rank Badge, Buyer Name, Score
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#${match.rank}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              match.buyerBusinessName?.isNotEmpty == true
                                  ? match.buyerBusinessName!
                                  : match.buyerName ?? 'Verified Buyer',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              match.location,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: scoreColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${match.matchScore}% Match',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                        fontSize: 11),
                  ),
                ),
              ],
            ),

            const Divider(height: 14),

            // Row 2: Distance, Demand Qty, Offered Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InfoColumn(
                  label: 'Demand Qty',
                  value:
                      '${match.buyerRequiredQty.toStringAsFixed(0)} ${match.buyerUnit}',
                ),
                _InfoColumn(
                  label: 'Offered Rate',
                  value:
                      '₹${_currencyFormatter.format(match.buyerExpectedPrice)}/Q',
                  color: AppColors.secondary,
                ),
                _InfoColumn(
                  label: 'Distance',
                  value: match.distanceKm != null
                      ? '${match.distanceKm!.toStringAsFixed(1)} km'
                      : 'Nearby',
                  icon: Icons.near_me,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Financial summary box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Expected Net Value',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.textSecondary)),
                      Text(
                        '₹${_currencyFormatter.format(match.netValue)} (₹${_currencyFormatter.format(match.netValuePerQ)}/Q)',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.primary),
                      ),
                    ],
                  ),
                  if (diffVsTop > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '-₹${_currencyFormatter.format(diffVsTop)} vs #1',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E)),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Actions: Open Map & Express Interest
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openGoogleMaps(match),
                    icon: const Icon(Icons.map_outlined, size: 14),
                    label:
                        const Text('Map', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showExpressInterestDialog(match),
                    icon: const Icon(Icons.send_rounded, size: 14),
                    label: const Text('Express Interest',
                        style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialRow({
    required String label,
    required String value,
    String? subtext,
    bool isBold = false,
    Color color = AppColors.textPrimary,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: AppColors.textSecondary,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
            ),
            if (subtext != null)
              Text(
                subtext,
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
          ],
        ),
      ],
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final IconData? icon;

  const _InfoColumn({
    required this.label,
    required this.value,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: AppColors.primary),
              const SizedBox(width: 2)
            ],
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: color ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

