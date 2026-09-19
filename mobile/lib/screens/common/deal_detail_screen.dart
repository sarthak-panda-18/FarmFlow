import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/deal_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/deal_service.dart';

class DealDetailScreen extends StatefulWidget {
  final String dealId;

  const DealDetailScreen({super.key, required this.dealId});

  @override
  State<DealDetailScreen> createState() => _DealDetailScreenState();
}

class _DealDetailScreenState extends State<DealDetailScreen> {
  final DealService _dealService = DealService();

  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;
  DealModel? _deal;

  // Rating state
  double _userRating = 5.0;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmittingRating = false;

  @override
  void initState() {
    super.initState();
    _fetchDeal();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _fetchDeal() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final deal = await _dealService.getDealById(widget.dealId);
      if (mounted) {
        setState(() {
          _deal = deal;
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

  void _openGoogleMaps(String? url, double? lat, double? lng) async {
    String? targetUrl = url;
    if ((targetUrl == null || targetUrl.isEmpty) && lat != null && lng != null && lat != 0 && lng != 0) {
      targetUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    }

    if (targetUrl != null && targetUrl.isNotEmpty) {
      final uri = Uri.parse(targetUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to launch Google Maps.')),
      );
    }
  }

  void _makePhoneCall(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to make call.')),
        );
      }
    }
  }

  Future<void> _handleReportPayment() async {
    final noteController = TextEditingController();
    String paymentMethod = 'Direct UPI / Bank Transfer';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Report Payment Made'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Record that you have initiated payment externally to the counterparty.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                const Text('Payment Method:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Direct UPI / Bank Transfer', child: Text('Direct UPI / Bank Transfer')),
                    DropdownMenuItem(value: 'Cash on Delivery / Pickup', child: Text('Cash on Delivery / Pickup')),
                    DropdownMenuItem(value: 'NEFT / RTGS / IMPS', child: Text('NEFT / RTGS / IMPS')),
                    DropdownMenuItem(value: 'Cheque / Draft', child: Text('Cheque / Draft')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => paymentMethod = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Optional Reference / Note',
                    hintText: 'e.g. Paid via UPI reference 12345',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Report Payment'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    setState(() => _isProcessing = true);
    try {
      final updated = await _dealService.reportPaymentMade(
        widget.dealId,
        notes: noteController.text.trim(),
        paymentMethod: paymentMethod,
      );
      if (mounted) {
        setState(() {
          _deal = updated;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment reported. Counterparty has been notified to verify and confirm receipt.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _handleConfirmPayment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payment Received?'),
        content: const Text(
          'Please ensure that you have externally verified your bank account or cash receipt. '
          'Once confirmed, the deal will be recorded as paid.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Receipt'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final updated = await _dealService.confirmPaymentReceived(widget.dealId);
      if (mounted) {
        setState(() {
          _deal = updated;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment confirmed! Deal payment status updated.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _handleDisputePayment() async {
    final reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Payment Issue / Dispute'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If you have not received the reported payment or there is a discrepancy, explain below:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Dispute Reason',
                hintText: 'e.g. Payment not credited in bank account.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter a dispute reason.')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Submit Dispute'),
          ),
        ],
      ),
    );

    if (result != true) return;

    setState(() => _isProcessing = true);
    try {
      final updated = await _dealService.disputePayment(
        widget.dealId,
        reason: reasonController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _deal = updated;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment dispute recorded. Both parties are notified to resolve directly.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _handleUpdateStatus(String newStatus) async {
    setState(() => _isProcessing = true);
    try {
      final updated = await _dealService.updateDealStatus(widget.dealId, newStatus);
      if (mounted) {
        setState(() {
          _deal = updated;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deal status updated to $newStatus'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _handleMarkDelivered() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delivery of Goods?'),
        content: const Text(
          'Mark this deal as DELIVERED. This indicates the harvest has safely reached the delivery destination.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Delivered'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final updated = await _dealService.markDealDelivered(widget.dealId);
      if (mounted) {
        setState(() {
          _deal = updated;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deal marked as Delivered! Ratings are now unlocked.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _handleCancelDeal() async {
    final reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Deal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel this deal? This action cannot be undone.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Cancellation Reason',
                hintText: 'e.g. Crop damaged / Unable to transport',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Deal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter a cancellation reason.')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Cancel Deal'),
          ),
        ],
      ),
    );

    if (result != true) return;

    setState(() => _isProcessing = true);
    try {
      final updated = await _dealService.cancelDeal(widget.dealId, reason: reasonController.text.trim());
      if (mounted) {
        setState(() {
          _deal = updated;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deal has been cancelled.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _handleSubmitRating() async {
    setState(() => _isSubmittingRating = true);
    try {
      await _dealService.rateDeal(
        widget.dealId,
        rating: _userRating,
        feedback: _feedbackController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your rating and feedback have been recorded.'),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchDeal();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingRating = false);
    }
  }

  Future<void> _handleEditLogistics() async {
    if (_deal == null) return;
    final transportCostController = TextEditingController(text: _deal!.transportCost > 0 ? _deal!.transportCost.toStringAsFixed(0) : '');
    final otherCostsController = TextEditingController(text: _deal!.otherCosts > 0 ? _deal!.otherCosts.toStringAsFixed(0) : '');
    bool transportReq = _deal!.transportRequired;
    String transportType = _deal!.transportType;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Update Logistics & Costs'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Transport Required', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  value: transportReq,
                  onChanged: (val) => setModalState(() => transportReq = val),
                ),
                if (transportReq) ...[
                  const SizedBox(height: 8),
                  const Text('Transport Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: transportType,
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'Standard Road Transport', child: Text('Standard Road Transport')),
                      DropdownMenuItem(value: 'Mini Truck / Pickup (Bolero)', child: Text('Mini Truck / Pickup (Bolero)')),
                      DropdownMenuItem(value: 'Heavy Commercial Truck', child: Text('Heavy Commercial Truck')),
                      DropdownMenuItem(value: 'Tractor Trolley', child: Text('Tractor Trolley')),
                      DropdownMenuItem(value: 'Self Arrangement / Direct Pickup', child: Text('Self Arrangement / Direct Pickup')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => transportType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: transportCostController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Estimated Transport Cost (₹)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: otherCostsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Other Costs (Loading/Packaging) (₹)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save Logistics'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    setState(() => _isProcessing = true);
    try {
      final double tCost = double.tryParse(transportCostController.text) ?? 0.0;
      final double oCost = double.tryParse(otherCostsController.text) ?? 0.0;

      final updated = await _dealService.updateDealLogistics(
        widget.dealId,
        transportRequired: transportReq,
        transportType: transportType,
        transportCost: tCost,
        otherCosts: oCost,
      );
      if (mounted) {
        setState(() {
          _deal = updated;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logistics and net return updated!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'AGREEMENT_PENDING':
        return const Color(0xFFEAB308);
      case 'WAITING_FOR_BUYER':
      case 'WAITING_FOR_FARMER':
        return const Color(0xFFF97316);
      case 'DEAL_CONFIRMED':
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
      case 'DISPUTED':
        return const Color(0xFFE11D48);
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
    final authProvider = Provider.of<AuthProvider>(context);
    final isFarmer = authProvider.userRole == 'FARMER';
    final currentUserId = authProvider.userId ?? '';

    final deal = _deal;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(deal != null ? '${deal.crop} Deal' : 'Deal Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading || _isProcessing ? null : _fetchDeal,
          ),
        ],
      ),
      body: _isLoading
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
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchDeal,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : deal == null
                  ? const Center(child: Text('Deal not found'))
                  : RefreshIndicator(
                      onRefresh: _fetchDeal,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppConstants.paddingMedium),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Status Banner & Timeline
                            _buildStatusBanner(deal),
                            const SizedBox(height: 16),

                            // 1.5 Official Deal Agreement Card (Change 3)
                            _buildAgreementSummaryCard(deal, isFarmer),
                            const SizedBox(height: 16),

                            // 2. Commodity & Deal Terms
                            _buildCommodityCard(deal),
                            const SizedBox(height: 16),

                            // 3. Counterparty Details
                            _buildCounterpartyCard(deal, isFarmer),
                            const SizedBox(height: 16),

                            // 4. Financials & Net Return (Phase 11)
                            _buildFinancialsCard(deal, isFarmer),
                            const SizedBox(height: 16),

                            // 5. Logistics (Phase 11)
                            _buildLogisticsCard(deal),
                            const SizedBox(height: 16),

                            // 6. External Payment Tracking (Phase 10)
                            _buildPaymentStatusCard(deal, isFarmer, currentUserId),
                            const SizedBox(height: 16),

                            // 7. Ratings & Feedback (Phase 12)
                            if (deal.isEligibleForRating) ...[
                              _buildRatingCard(deal, isFarmer),
                              const SizedBox(height: 16),
                            ],

                            // 8. Lifecycle Actions
                            _buildActionButtons(deal, isFarmer),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
    );
  }

  // STATUS BANNER
  Widget _buildStatusBanner(DealModel deal) {
    final statusColor = _getStatusColor(deal.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.handshake, color: statusColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    deal.status.replaceAll('_', ' '),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                DateFormat('dd MMM yyyy').format(deal.agreedDate),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          if (deal.cancellationReason != null && deal.cancellationReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Cancellation Reason: ${deal.cancellationReason}',
                style: const TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // AGREEMENT SUMMARY CARD
  Widget _buildAgreementSummaryCard(DealModel deal, bool isFarmer) {
    final bool isConfirmed = deal.isAgreementConfirmed;
    final bool currentUserAccepted = isFarmer ? deal.farmerAccepted : deal.buyerAccepted;

    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        side: BorderSide(
          color: isConfirmed ? Colors.green.shade400 : Colors.amber.shade500,
          width: 1.2,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isConfirmed ? Colors.green.shade50.withValues(alpha: 0.35) : Colors.amber.shade50.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConfirmed ? Icons.verified_user : Icons.gavel,
                  color: isConfirmed ? AppColors.success : const Color(0xFFD97706),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'OFFICIAL DEAL AGREEMENT (v${deal.agreementVersion})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isConfirmed ? Colors.green.shade900 : const Color(0xFF92400E),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isConfirmed ? Colors.green.shade100 : Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    deal.agreementStatus.replaceAll('_', ' '),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isConfirmed ? Colors.green.shade800 : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        deal.farmerAccepted ? Icons.check_circle : Icons.hourglass_top,
                        size: 16,
                        color: deal.farmerAccepted ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Farmer: ${deal.farmerAccepted ? 'Accepted' : 'Pending'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: deal.farmerAccepted ? Colors.green.shade900 : Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        deal.buyerAccepted ? Icons.check_circle : Icons.hourglass_top,
                        size: 16,
                        color: deal.buyerAccepted ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Buyer: ${deal.buyerAccepted ? 'Accepted' : 'Pending'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: deal.buyerAccepted ? Colors.green.shade900 : Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isConfirmed ? Colors.green.shade800 : AppColors.primary,
                  side: BorderSide(color: isConfirmed ? Colors.green.shade400 : AppColors.primary),
                ),
                icon: const Icon(Icons.article_outlined, size: 18),
                label: Text(
                  isConfirmed
                      ? 'View Signed Agreement'
                      : (currentUserAccepted
                          ? 'View Agreement (Waiting Counterparty)'
                          : 'Review & Sign Deal Agreement'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () async {
                  await context.push(AppConstants.routeDealAgreement, extra: deal.id);
                  _fetchDeal();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // COMMODITY & TERMS CARD
  Widget _buildCommodityCard(DealModel deal) {
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  deal.crop,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${deal.quantity.toStringAsFixed(0)} ${deal.quantityUnit}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                  ),
                ),
              ],
            ),
            if (deal.variety.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Variety: ${deal.variety}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTermItem('Agreed Price', '${_formatCurrency(deal.agreedPrice)} / ${deal.agreedPriceUnit}'),
                _buildTermItem('Gross Value', _formatCurrency(deal.totalAmount), isBold: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermItem(String label, String value, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // COUNTERPARTY CARD
  Widget _buildCounterpartyCard(DealModel deal, bool isFarmer) {
    final name = isFarmer ? deal.buyerName : deal.farmerName;
    final phone = isFarmer ? deal.buyerPhone : deal.farmerPhone;
    final location = isFarmer ? deal.buyerLocation : deal.farmerLocation;
    final rating = isFarmer ? deal.buyerRating : deal.farmerRating;
    final ratingCount = isFarmer ? deal.buyerRatingCount : deal.farmerRatingCount;
    final business = isFarmer && deal.buyerBusinessName.isNotEmpty ? deal.buyerBusinessName : null;

    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFarmer ? 'Buyer Information' : 'Farmer Information',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isFarmer ? Colors.indigo.shade50 : Colors.green.shade50,
                  foregroundColor: isFarmer ? Colors.indigo : Colors.green,
                  child: Icon(isFarmer ? Icons.store : Icons.agriculture),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      if (business != null) Text(business, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      if (rating != null && rating > 0)
                        Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Color(0xFFD97706)),
                            const SizedBox(width: 2),
                            Text(
                              '${rating.toStringAsFixed(1)} ($ratingCount ${ratingCount == 1 ? 'deal' : 'deals'})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                            ),
                          ],
                        )
                      else
                        Text(
                          isFarmer ? deal.buyerRatingLabel : deal.farmerRatingLabel,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                if (phone.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.call, color: AppColors.primary),
                    onPressed: () => _makePhoneCall(phone),
                  ),
              ],
            ),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(location, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // FINANCIALS & ESTIMATED NET RETURN (PHASE 11)
  Widget _buildFinancialsCard(DealModel deal, bool isFarmer) {
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isFarmer ? 'Estimated Net Return' : 'Estimated Total Cost',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note, size: 20, color: AppColors.primary),
                  tooltip: 'Update Costs',
                  onPressed: _handleEditLogistics,
                ),
              ],
            ),
            const Divider(height: 12),
            _buildCostRow('Gross Deal Value', _formatCurrency(deal.estimatedGrossAmount)),
            _buildCostRow(
              'Estimated Transport',
              deal.estimatedTransportCost > 0 ? (isFarmer ? '- ${_formatCurrency(deal.estimatedTransportCost)}' : '+ ${_formatCurrency(deal.estimatedTransportCost)}') : '₹0',
              color: isFarmer && deal.estimatedTransportCost > 0 ? AppColors.error : null,
            ),
            _buildCostRow(
              'Other Costs (Loading/Packaging)',
              deal.estimatedOtherCosts > 0 ? (isFarmer ? '- ${_formatCurrency(deal.estimatedOtherCosts)}' : '+ ${_formatCurrency(deal.estimatedOtherCosts)}') : '₹0',
              color: isFarmer && deal.estimatedOtherCosts > 0 ? AppColors.error : null,
            ),
            const Divider(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isFarmer ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isFarmer ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isFarmer ? 'ESTIMATED NET RETURN' : 'ESTIMATED TOTAL COST',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isFarmer ? const Color(0xFF065F46) : const Color(0xFF1E40AF),
                    ),
                  ),
                  Text(
                    _formatCurrency(isFarmer ? deal.estimatedNetReturn : deal.estimatedTotalBuyerCost),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: isFarmer ? const Color(0xFF065F46) : const Color(0xFF1E40AF),
                    ),
                  ),
                ],
              ),
            ),
            if (isFarmer) ...[
              const SizedBox(height: 8),
              const Text(
                'Note: Estimated Net Return = Gross Value - Transport - Other Costs. It represents estimated proceeds, not guaranteed profit.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCostRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // LOGISTICS CARD (PHASE 11)
  Widget _buildLogisticsCard(DealModel deal) {
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Logistics & Locations', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    deal.logisticsStatus.replaceAll('_', ' '),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            if (deal.distanceKm != null && deal.distanceKm! > 0) ...[
              Row(
                children: [
                  const Icon(Icons.straighten, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Direct Distance: ${deal.distanceKm!.toStringAsFixed(1)} km',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Pickup Location
            _buildLocationItem(
              title: 'Pickup Location (Farmer)',
              address: deal.pickupAddress.isNotEmpty ? deal.pickupAddress : 'Farmer farm location',
              lat: deal.pickupLat,
              lng: deal.pickupLng,
              mapsUrl: deal.pickupMapsUrl,
              iconColor: Colors.green,
            ),
            const SizedBox(height: 12),

            // Delivery Location
            _buildLocationItem(
              title: 'Delivery Location (Buyer)',
              address: deal.deliveryAddress.isNotEmpty ? deal.deliveryAddress : 'Buyer warehouse / delivery point',
              lat: deal.deliveryLat,
              lng: deal.deliveryLng,
              mapsUrl: deal.deliveryMapsUrl,
              iconColor: Colors.indigo,
            ),
            const SizedBox(height: 12),

            // Transport info
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deal.transportRequired ? deal.transportType : 'No transport required (Direct handover)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        if (deal.deliveryDate != null)
                          Text(
                            'Target Delivery: ${DateFormat('dd MMM yyyy').format(deal.deliveryDate!)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationItem({
    required String title,
    required String address,
    required double? lat,
    required double? lng,
    required String? mapsUrl,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.location_on, size: 20, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              Text(address, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              if (lat != null && lng != null && lat != 0 && lng != 0) ...[
                const SizedBox(height: 2),
                Text(
                  'GPS: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        TextButton.icon(
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
          icon: const Icon(Icons.map, size: 16),
          label: const Text('Maps', style: TextStyle(fontSize: 12)),
          onPressed: () => _openGoogleMaps(mapsUrl, lat, lng),
        ),
      ],
    );
  }

  // EXTERNAL PAYMENT STATUS CARD (PHASE 10)
  Widget _buildPaymentStatusCard(DealModel deal, bool isFarmer, String currentUserId) {
    final pColor = _getPaymentStatusColor(deal.paymentStatus);
    final bool isReporter = deal.paymentReportedBy == currentUserId;

    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Payment Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: pColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: pColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    deal.paymentStatus.replaceAll('_', ' '),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: pColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Mandatory Safety Disclaimer
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 18, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment Method: Direct / External Settlement. FarmFlow does not collect banking credentials or process funds directly.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Contextual Status Explanations & Action Buttons
            if (deal.isPaymentPending) ...[
              const Text(
                'Direct payment is pending between Farmer and Buyer. When you complete external payment, report it here.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Report Payment Made'),
                  onPressed: _isProcessing ? null : _handleReportPayment,
                ),
              ),
            ] else if (deal.isPaymentReported) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          isReporter
                              ? 'You reported payment.'
                              : '${deal.paymentReportedByRole ?? 'Counterparty'} reported payment was made.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                        ),
                      ],
                    ),
                    if (deal.paymentReportedNotes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Note: ${deal.paymentReportedNotes}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                    if (deal.paymentReportedAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Reported: ${DateFormat('dd MMM, hh:mm a').format(deal.paymentReportedAt!)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Action buttons depending on reporter vs receiver
              if (!isReporter) ...[
                const Text(
                  '⚠️ Please check your bank account / cash externally before confirming receipt.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                        onPressed: _isProcessing ? null : _handleDisputePayment,
                        child: const Text('Report Issue'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Confirm Receipt'),
                        onPressed: _isProcessing ? null : _handleConfirmPayment,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Text(
                  'Waiting for the receiving party to externally verify their account and confirm receipt.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                ),
              ],
            ] else if (deal.isPaymentConfirmed) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Confirmed by Both Parties',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade900),
                          ),
                          if (deal.paymentConfirmedAt != null)
                            Text(
                              'Confirmed on ${DateFormat('dd MMM yyyy, hh:mm a').format(deal.paymentConfirmedAt!)}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (deal.isPaymentDisputed) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Payment Dispute Reported',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red.shade900),
                        ),
                      ],
                    ),
                    if (deal.paymentDisputeReason.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Reason: ${deal.paymentDisputeReason}', style: const TextStyle(fontSize: 12, color: AppColors.error)),
                    ],
                    const SizedBox(height: 6),
                    const Text(
                      'Please communicate directly with the counterparty to settle the payment discrepancy.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // RATINGS & FEEDBACK CARD (PHASE 12)
  Widget _buildRatingCard(DealModel deal, bool isFarmer) {
    final bool alreadyRated = isFarmer ? deal.farmerRated : deal.buyerRated;

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
                const Icon(Icons.star, color: Color(0xFFD97706), size: 20),
                const SizedBox(width: 8),
                Text(
                  isFarmer ? 'Rate Buyer Experience' : 'Rate Farmer Experience',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 16),
            if (alreadyRated) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified, color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You have submitted your rating and feedback for this deal. Thank you!',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text(
                'Please share your experience to help improve trust in the marketplace.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (index) {
                    final starVal = index + 1.0;
                    return IconButton(
                      icon: Icon(
                        starVal <= _userRating ? Icons.star : Icons.star_border,
                        color: const Color(0xFFD97706),
                        size: 32,
                      ),
                      onPressed: _isSubmittingRating ? null : () => setState(() => _userRating = starVal),
                    );
                  }),
                ),
              ),
              Center(
                child: Text(
                  '${_userRating.toInt()} / 5 Stars',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _feedbackController,
                maxLines: 2,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Feedback / Comment (Optional)',
                  hintText: 'e.g. Prompt payment, polite communication and seamless handover.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
                  onPressed: _isSubmittingRating ? null : _handleSubmitRating,
                  child: _isSubmittingRating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Rating & Feedback', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ACTION BUTTONS (STATUS & CANCELLATION)
  Widget _buildActionButtons(DealModel deal, bool isFarmer) {
    if (deal.isCompleted || deal.isCancelled) {
      return const SizedBox.shrink();
    }

    final isAgreementStage = deal.isAgreementPending || deal.isWaitingForBuyer || deal.isWaitingForFarmer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isAgreementStage) ...[
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
            ),
            icon: const Icon(Icons.gavel),
            label: Text(
              ((isFarmer && deal.farmerAccepted) || (!isFarmer && deal.buyerAccepted))
                  ? 'View Agreement (Waiting Counterparty)'
                  : 'Review & Accept Official Agreement',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: () async {
              await context.push(AppConstants.routeDealAgreement, extra: deal.id);
              _fetchDeal();
            },
          ),
          const SizedBox(height: 10),
        ] else if (!deal.isDelivered) ...[
          // Intermediate status progress buttons
          if (deal.status == 'CONFIRMED' || deal.status == 'DEAL_CONFIRMED') ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
              ),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Update Status: PREPARING HARVEST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              onPressed: _isProcessing ? null : () => _handleUpdateStatus('PREPARING'),
            ),
            const SizedBox(height: 10),
          ] else if (deal.status == 'PREPARING') ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
              ),
              icon: const Icon(Icons.check_box_outlined),
              label: const Text('Update Status: READY FOR PICKUP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              onPressed: _isProcessing ? null : () => _handleUpdateStatus('READY_FOR_PICKUP'),
            ),
            const SizedBox(height: 10),
          ] else if (deal.status == 'READY_FOR_PICKUP') ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
              ),
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('Update Status: IN TRANSIT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              onPressed: _isProcessing ? null : () => _handleUpdateStatus('IN_TRANSIT'),
            ),
            const SizedBox(height: 10),
          ],
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
            ),
            icon: const Icon(Icons.done_all),
            label: const Text('Mark Goods Delivered', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            onPressed: _isProcessing ? null : _handleMarkDelivered,
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: AppColors.error),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
          ),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Cancel Deal'),
          onPressed: _isProcessing ? null : _handleCancelDeal,
        ),
      ],
    );
  }
}
