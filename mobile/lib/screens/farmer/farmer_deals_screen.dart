import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/deal_model.dart';
import '../../services/deal_service.dart';

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

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return const Color(0xFF2563EB);
      case 'PREPARING':
      case 'READY_FOR_PICKUP':
        return const Color(0xFFD97706);
      case 'IN_TRANSIT':
        return const Color(0xFF7C3AED);
      case 'DELIVERED':
        return const Color(0xFF059669);
      case 'COMPLETED':
        return const Color(0xFF16A34A);
      case 'CANCELLED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF4B5563);
    }
  }

  Color _getPaymentStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAYMENT_PENDING':
        return const Color(0xFFD97706);
      case 'PAYMENT_REPORTED':
        return const Color(0xFF2563EB);
      case 'PAYMENT_CONFIRMED_BY_BOTH':
        return const Color(0xFF16A34A);
      case 'PAYMENT_DISPUTED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF4B5563);
    }
  }

  String _formatCurrency(double val) {
    final format = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
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
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
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
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
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
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(onPressed: _fetchDeals, child: const Text('Try Again')),
                            ],
                          ),
                        ),
                      )
                    : _deals.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.handshake_outlined, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    _selectedStatus == 'ALL'
                                        ? 'No deals yet.'
                                        : 'No ${_selectedStatus.replaceAll('_', ' ')} deals.',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'When an opportunity is accepted, an agreed deal will be created here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchDeals,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(AppConstants.paddingMedium),
                              itemCount: _deals.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
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
    final statusColor = _getStatusColor(deal.status);
    final pColor = _getPaymentStatusColor(deal.paymentStatus);

    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        onTap: () async {
          await context.push(AppConstants.routeDealDetail, extra: deal.id);
          _fetchDeals();
        },
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
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
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  Text(
                    DateFormat('dd MMM yyyy').format(deal.agreedDate),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Buyer info
              Row(
                children: [
                  const Icon(Icons.store, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Buyer: ${deal.buyerName}${deal.buyerBusinessName.isNotEmpty ? ' (${deal.buyerBusinessName})' : ''}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),

              // Quantity, Unit Price & Gross
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetric('Quantity', '${deal.quantity.toStringAsFixed(0)} ${deal.quantityUnit}'),
                  _buildMetric('Agreed Price', '${_formatCurrency(deal.agreedPrice)}/${deal.agreedPriceUnit}'),
                  _buildMetric('Total Amount', _formatCurrency(deal.totalAmount), isBold: true),
                ],
              ),
              const SizedBox(height: 10),

              // Net Return highlight
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Estimated Net Return:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                    ),
                    Text(
                      _formatCurrency(deal.estimatedNetReturn),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          deal.status.replaceAll('_', ' '),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: pColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: pColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          deal.paymentStatus.replaceAll('_', ' '),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: pColor),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('View Deal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () async {
                      await context.push(AppConstants.routeDealDetail, extra: deal.id);
                      _fetchDeals();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
