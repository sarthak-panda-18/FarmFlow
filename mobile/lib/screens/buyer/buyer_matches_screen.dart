import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/match_model.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class BuyerMatchesScreen extends StatefulWidget {
  final String? requirementId;

  const BuyerMatchesScreen({super.key, this.requirementId});

  @override
  State<BuyerMatchesScreen> createState() => _BuyerMatchesScreenState();
}

class _BuyerMatchesScreenState extends State<BuyerMatchesScreen> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();

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
      final res = await _apiService.getBuyerMatches(
        requirementId: widget.requirementId,
        maxDistance: _maxDistance,
      );

      if (res.data != null && res.data['success'] == true) {
        final List list = res.data['data'] ?? [];
        setState(() {
          _matches = list.map((m) => MatchModel.fromJson(m)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res.data?['message'] ?? 'Failed to load matching farmer crops';
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

  void _openGoogleMaps(MatchModel match) {
    if (match.latitude != null && match.longitude != null) {
      _locationService.openGoogleMaps(
        latitude: match.latitude!,
        longitude: match.longitude!,
        label: '${match.farmerName} (Farmer Crop)',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Farmer coordinates are not specified.')),
      );
    }
  }

  void _showExpressInterestDialog(MatchModel match) {
    final priceController = TextEditingController(text: match.buyerExpectedPrice.toStringAsFixed(0));
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
              Text('Farmer: ${match.farmerName}'),
              Text('Available Qty: ${match.farmerAvailableQty} ${match.farmerUnit}'),
              Text('Farmer Expected: ₹${match.farmerExpectedPrice.toStringAsFixed(0)} / Quintal'),
              const Divider(height: 20),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Your Offered Purchase Price (₹ / Quintal)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Message for Farmer (Optional)',
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
                if (match.cropId != null) {
                  await _apiService.expressInterest(
                    cropId: match.cropId!,
                    requirementId: match.requirementId,
                    offeredPrice: double.tryParse(priceController.text.trim()),
                    notes: notesController.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Purchase interest sent directly to Farmer!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  final msg = e.toString().replaceAll('Exception: ', '');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Send Offer'),
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
        title: const Text('Matched Farmer Crops'),
        backgroundColor: AppColors.secondary,
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
                const Text('Max Distance: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                            selectedColor: AppColors.secondary.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppColors.secondary : AppColors.textSecondary,
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
                    '${_matches.length} Compatible Crops Found',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const Text('Ranked by Score & Distance', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
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
      return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
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
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search_off_outlined, size: 50, color: AppColors.secondary),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Farmer Found',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                "We couldn't find a Farmer matching your crop, quantity, location and requirements right now.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_active_outlined, size: 16, color: Color(0xFF2563EB)),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        "We'll notify you when a suitable Farmer becomes available.",
                        style: TextStyle(color: Color(0xFF1D4ED8), fontSize: 12, fontWeight: FontWeight.w600),
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
                    onPressed: () => context.push(AppConstants.routeBuyerRequirements),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('View My Requirements'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => context.go(AppConstants.routeBuyerDashboard),
                    icon: const Icon(Icons.dashboard_outlined),
                    label: const Text('Go to Dashboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _matches.length,
      itemBuilder: (context, index) {
        final match = _matches[index];
        final scoreColor = _getScoreColor(match.matchScore);

        return Card(
          elevation: AppConstants.cardElevation,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Crop Title & Compatibility Score Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            match.commodity,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondary),
                          ),
                          Text(
                            'Farmer: ${match.farmerName}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scoreColor.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${match.matchScore}% Match',
                            style: TextStyle(fontWeight: FontWeight.bold, color: scoreColor, fontSize: 13),
                          ),
                          Text(
                            match.compatibility,
                            style: TextStyle(color: scoreColor, fontSize: 10, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Divider(height: 16),

                // Row 2: Quantities & Distance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _InfoColumn(
                      label: 'Farmer Available',
                      value: '${match.farmerAvailableQty.toStringAsFixed(0)} ${match.farmerUnit}',
                      subtext: match.farmerAvailableQty >= match.buyerRequiredQty ? '✓ Full Coverage' : '⚠ Partial',
                      subtextColor: match.farmerAvailableQty >= match.buyerRequiredQty ? AppColors.success : AppColors.warning,
                    ),
                    _InfoColumn(
                      label: 'Your Needed',
                      value: '${match.buyerRequiredQty.toStringAsFixed(0)} ${match.buyerUnit}',
                    ),
                    _InfoColumn(
                      label: 'Distance',
                      value: match.distanceKm != null ? '${match.distanceKm!.toStringAsFixed(1)} km' : 'Nearby',
                      icon: Icons.near_me,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Row 3: Price Matrix Comparison
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _PriceBox(
                        label: 'Farmer Price',
                        price: '₹${match.farmerExpectedPrice.toStringAsFixed(0)}/Q',
                        color: AppColors.primary,
                      ),
                      _PriceBox(
                        label: 'Market Ref',
                        price: '₹${match.marketReferencePrice.toStringAsFixed(0)}/Q',
                        color: AppColors.textSecondary,
                      ),
                      _PriceBox(
                        label: 'Your Offer',
                        price: '₹${match.buyerExpectedPrice.toStringAsFixed(0)}/Q',
                        color: AppColors.secondary,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Actions: Open in Google Maps & Express Interest
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openGoogleMaps(match),
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: const Text('Open Map', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showExpressInterestDialog(match),
                        icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                        label: const Text('Buy / Connect', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;
  final String? subtext;
  final Color? subtextColor;
  final IconData? icon;

  const _InfoColumn({
    required this.label,
    required this.value,
    this.subtext,
    this.subtextColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: AppColors.secondary), const SizedBox(width: 2)],
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        if (subtext != null)
          Text(subtext!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: subtextColor ?? AppColors.textSecondary)),
      ],
    );
  }
}

class _PriceBox extends StatelessWidget {
  final String label;
  final String price;
  final Color color;

  const _PriceBox({required this.label, required this.price, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(price, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      ],
    );
  }
}
