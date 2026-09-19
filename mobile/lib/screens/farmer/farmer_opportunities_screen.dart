import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/opportunity_model.dart';
import '../../services/api_service.dart';

class FarmerOpportunitiesScreen extends StatefulWidget {
  const FarmerOpportunitiesScreen({super.key});

  @override
  State<FarmerOpportunitiesScreen> createState() =>
      _FarmerOpportunitiesScreenState();
}

class _FarmerOpportunitiesScreenState extends State<FarmerOpportunitiesScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _errorMessage;
  List<OpportunityModel> _opportunities = [];
  String _selectedFilter = 'ALL';

  final List<String> _filters = [
    'ALL',
    'PENDING',
    'ACCEPTED',
    'COMPLETED',
    'REJECTED',
    'CANCELLED'
  ];

  @override
  void initState() {
    super.initState();
    _fetchOpportunities();
  }

  Future<void> _fetchOpportunities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.getFarmerOpportunities(
        page: 1,
        limit: 100,
        status: _selectedFilter == 'ALL' ? null : _selectedFilter,
      );

      if (mounted && res.data != null && res.data['success'] == true) {
        final List list = res.data['data'] ?? [];
        setState(() {
          _opportunities =
              list.map((item) => OpportunityModel.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              res.data?['message'] ?? 'Unable to load opportunities.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to load opportunities.';
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
      case 'INTERESTED':
        return const Color(0xFFFEF3C7);
      case 'ACCEPTED':
        return const Color(0xFFDCFCE7);
      case 'COMPLETED':
      case 'CLOSED':
        return const Color(0xFFDBEAFE);
      case 'REJECTED':
      case 'CANCELLED':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
      case 'INTERESTED':
        return const Color(0xFF92400E);
      case 'ACCEPTED':
        return const Color(0xFF166534);
      case 'COMPLETED':
      case 'CLOSED':
        return const Color(0xFF1E40AF);
      case 'REJECTED':
      case 'CANCELLED':
        return const Color(0xFF991B1B);
      default:
        return const Color(0xFF374151);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Opportunities'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.star_outline),
            tooltip: 'Buyer Recommendations',
            onPressed: () =>
                context.push(AppConstants.routeFarmerRecommendations),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchOpportunities,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        filter == 'ALL' ? 'All Opportunities' : filter,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      backgroundColor: const Color(0xFFF1F5F9),
                      onSelected: (selected) {
                        if (selected && _selectedFilter != filter) {
                          setState(() {
                            _selectedFilter = filter;
                          });
                          _fetchOpportunities();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Body List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchOpportunities,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text('Loading opportunities...'),
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
              Text(_errorMessage!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchOpportunities,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (_opportunities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.handshake_outlined,
                  size: 64, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(
                _selectedFilter == 'ALL'
                    ? 'No opportunities yet.'
                    : 'No $_selectedFilter opportunities.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'When you or buyers express interest in matched crops/requirements, actionable opportunities will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final hasRecommendations = _opportunities.length >= 3;

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: _opportunities.length + (hasRecommendations ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasRecommendations && index == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Color(0xFF16A34A), size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '3+ Buyer Opportunities Available',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF166534)),
                      ),
                      Text(
                        'Automated Net Value recommendation ready',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () =>
                      context.push(AppConstants.routeFarmerRecommendations),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  child:
                      const Text('View Best', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          );
        }

        final item = _opportunities[hasRecommendations ? index - 1 : index];
        final isInitiator = item.initiatedBy == 'FARMER';

        return Card(
          elevation: AppConstants.cardElevation,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          child: InkWell(
            onTap: () async {
              final refreshed = await context.push(
                AppConstants.routeOpportunityDetail,
                extra: item.id,
              );
              if (refreshed == true) _fetchOpportunities();
            },
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Buyer name & Status Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.storefront,
                                color: AppColors.secondary, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                item.buyerName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusBgColor(item.normalizedStatus),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.normalizedStatus,
                          style: TextStyle(
                            color: _getStatusTextColor(item.normalizedStatus),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Row 2: Initiator Tag & Business Name
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isInitiator
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isInitiator
                                ? const Color(0xFFBFDBFE)
                                : const Color(0xFFBBF7D0),
                          ),
                        ),
                        child: Text(
                          isInitiator
                              ? 'Initiated by You'
                              : 'Initiated by Buyer',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isInitiator
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                      if (item.buyerBusinessName.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '• ${item.buyerBusinessName}',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const Divider(height: 20),

                  // Row 3: Commodity, Quantity & Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Crop: ${item.commodity}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Quantity: ${item.quantity} ${item.quantityUnit}',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Offered Price',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                          Text(
                            '₹${item.offeredPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Row 4: Distance & View Details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (item.distanceKm != null)
                        Row(
                          children: [
                            const Icon(Icons.near_me,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${item.distanceKm!.toStringAsFixed(1)} km away',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        )
                      else
                        const SizedBox.shrink(),
                      const Row(
                        children: [
                          Text(
                            'View Details',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary),
                          ),
                          SizedBox(width: 2),
                          Icon(Icons.chevron_right,
                              size: 16, color: AppColors.primary),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
