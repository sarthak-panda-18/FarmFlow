import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';

class FarmFinancialBreakdown extends StatelessWidget {
  final num sellingPrice;
  final num? quantity;
  final String quantityUnit;
  final num? unitPrice;
  final num? transportationCost;
  final bool isTransportAvailable;
  final num otherCosts;
  final num netValue;
  final bool compact;

  const FarmFinancialBreakdown({
    super.key,
    required this.sellingPrice,
    this.quantity,
    this.quantityUnit = 'Quintal',
    this.unitPrice,
    this.transportationCost,
    this.isTransportAvailable = true,
    this.otherCosts = 0,
    required this.netValue,
    this.compact = false,
  });

  String _formatCurrency(num value) {
    final formatter = NumberFormat('#,##,###', 'en_IN');
    return '₹${formatter.format(value)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2EFE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Gross Value / Selling Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                (quantity != null && unitPrice != null)
                    ? 'Gross Value ($quantity $quantityUnit @ ${_formatCurrency(unitPrice!)}/$quantityUnit)'
                    : 'Gross Selling Value',
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                _formatCurrency(sellingPrice),
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Row 2: Transport Cost
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transport Cost',
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                isTransportAvailable && transportationCost != null
                    ? (transportationCost! > 0
                        ? '- ${_formatCurrency(transportationCost!)}'
                        : '₹0 (Free/Direct)')
                    : 'Unavailable',
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w500,
                  color: isTransportAvailable && (transportationCost ?? 0) > 0
                      ? AppColors.error
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Row 3: Other Costs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Other Costs (Handling/Mandi)',
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                otherCosts > 0 ? '- ${_formatCurrency(otherCosts)}' : '₹0',
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w500,
                  color: otherCosts > 0
                      ? AppColors.error
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const Divider(height: 16, thickness: 1, color: Color(0xFFE2EFE0)),

          // Result Row: Expected Net Return
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EXPECTED NET RETURN',
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                  color: AppColors.primaryDark,
                ),
              ),
              Text(
                _formatCurrency(netValue),
                style: TextStyle(
                  fontSize: compact ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
