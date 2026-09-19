import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/deal_model.dart';
import '../../services/deal_service.dart';
import '../../widgets/farm_badge.dart';
import '../../widgets/farm_bottom_nav.dart';
import '../../widgets/farm_empty_state.dart';

class FarmerDealsScreen extends StatefulWidget {
  const FarmerDealsScreen({super.key});

  @override
  State<FarmerDealsScreen> createState() => _FarmerDealsScreenState();
}

class _FarmerDealsScreenState extends State<FarmerDealsScreen> {
  final DealService _dealService = DealService();

  bool _isLoading = true;
  String? _errorMessage;
  List<DealModel> _deals = [];
  String _selectedStatus = 'ALL';

  final List<String> _statusFilters = [
    'ALL',
    'AGREEMENT_PENDING',
    'DEAL_CONFIRMED',
    'CONFIRMED',
    'PREPARING',
    'IN_TRANSIT',
    'DELIVERED',
    'COMPLETED',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    _fetchDeals();
  }

  Future<void> _fetchDeals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _dealService.getFarmerDeals(status: _selectedStatus);
      if (mounted) {
        setState(() {
          _deals = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  FarmBadgeType _getStatusBadgeType(String status) {
    switch (status.toUpperCase()) {
      case 'AGREEMENT_PENDING':
      case 'WAITING_FOR_BUYER':
      case 'WAITING_FOR_FARMER':
      case 'PREPARING':
      case 'READY_FOR_PICKUP':
        return FarmBadgeType.warning;
      case 'DEAL_CONFIRMED':
      case 'CONFIRMED':
      case 'IN_TRANSIT':
        return FarmBadgeType.info;
      case 'DELIVERED':
      case 'COMPLETED':
        return FarmBadgeType.success;
      case 'CANCELLED':
        return FarmBadgeType.error;
      default:
        return FarmBadgeType.neutral;
    }
  }

  String _formatCurrency(double val) {
    final format =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return format.format(val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Deals'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh Deals',
            onPressed: _fetchDeals,
          ),
        ],
      ),
      bottomNavigationBar: const FarmBottomNav(currentIndex: 3, role: 'FARMER'),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingMedium),
              itemCount: _statusFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _statusFilters[index];
                final isSelected = _selectedStatus == filter;
                return ChoiceChip(
                  label: Text(
                    filter.replaceAll('_', ' '),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color:
                            isSelected ? AppColors.primary : AppColors.border),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedStatus = filter);
                      _fetchDeals();
                    }
                  },
                );
              },
            ),
          ),

          // Deals List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 48, color: AppColors.error),
                              const SizedBox(height: 12),
                              Text(_errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                  onPressed: _fetchDeals,
                                  child: const Text('Try Again')),
                            ],
                          ),
                        ),
                      )
                    : _deals.isEmpty
                        ? FarmEmptyState(
                            icon: Icons.handshake_outlined,
                            title: _selectedStatus == 'ALL'
                                ? 'No deals yet'
                                : 'No ${_selectedStatus.replaceAll('_', ' ')} deals',
                            message:
                                'When buyer opportunities are mutually accepted, verified deals will appear here.',
                          )
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _fetchDeals,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(
                                  AppConstants.paddingMedium),
                              itemCount: _deals.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final deal = _deals[index];
                                return _buildDealCard(deal);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildDealCard(DealModel deal) {
    return Container(
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
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            await context.push(AppConstants.routeDealDetail, extra: deal.id);
            _fetchDeals();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Crop & Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        deal.crop,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy').format(deal.agreedDate),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Buyer info
                Row(
                  children: [
                    const Icon(Icons.storefront,
                        size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Buyer: ${deal.buyerName}${deal.buyerBusinessName.isNotEmpty ? ' (${deal.buyerBusinessName})' : ''}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18, color: AppColors.border),

                // Quantity, Unit Price & Gross
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetric('Quantity',
                        '${deal.quantity.toStringAsFixed(0)} ${deal.quantityUnit}'),
                    _buildMetric('Agreed Rate',
                        '${_formatCurrency(deal.agreedPrice)}/${deal.agreedPriceUnit}'),
                    _buildMetric(
                        'Total Value', _formatCurrency(deal.totalAmount),
                        isBold: true),
                  ],
                ),
                const SizedBox(height: 10),

                // Net Return highlight (Pale Green Box)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F8F0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD4E8CF)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estimated Net Return:',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark),
                      ),
                      Text(
                        _formatCurrency(deal.estimatedNetReturn),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Status badges & View button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        FarmBadge(
                          label: deal.status.replaceAll('_', ' '),
                          type: _getStatusBadgeType(deal.status),
                        ),
                        FarmBadge(
                          label: deal.paymentStatus.replaceAll('_', ' '),
                          type:
                              deal.paymentStatus == 'PAYMENT_CONFIRMED_BY_BOTH'
                                  ? FarmBadgeType.success
                                  : FarmBadgeType.neutral,
                        ),
                      ],
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 15),
                      label: const Text('View Deal',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () async {
                        await context.push(AppConstants.routeDealDetail,
                            extra: deal.id);
                        _fetchDeals();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
