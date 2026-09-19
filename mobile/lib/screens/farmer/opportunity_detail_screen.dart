import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/opportunity_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class OpportunityDetailScreen extends StatefulWidget {
  final String opportunityId;

  const OpportunityDetailScreen({super.key, required this.opportunityId});

  @override
  State<OpportunityDetailScreen> createState() => _OpportunityDetailScreenState();
}

class _OpportunityDetailScreenState extends State<OpportunityDetailScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;
  OpportunityModel? _opportunity;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.getOpportunityById(widget.opportunityId);
      if (mounted && res.data != null && res.data['success'] == true) {
        final data = res.data['data']['opportunity'];
        setState(() {
          _opportunity = OpportunityModel.fromJson(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res.data?['message'] ?? 'Unable to load opportunity details.';
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

  Future<void> _handleAccept() async {
    setState(() => _isProcessing = true);
    try {
      final res = await _apiService.acceptOpportunity(widget.opportunityId);
      if (!mounted) return;
      if (res.data != null && res.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opportunity accepted successfully! Both parties are now connected.'),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchDetail();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.data?['message'] ?? 'Action failed'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Opportunity?'),
        content: const Text('Are you sure you want to decline this interest? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final res = await _apiService.rejectOpportunity(widget.opportunityId);
      if (!mounted) return;
      if (res.data != null && res.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opportunity declined.')),
        );
        _fetchDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Your Expressed Interest?'),
        content: const Text('Are you sure you want to withdraw this offer/interest?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No, Keep It')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final res = await _apiService.cancelOpportunity(widget.opportunityId);
      if (!mounted) return;
      if (res.data != null && res.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your interest has been cancelled.')),
        );
        _fetchDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleComplete() async {
    setState(() => _isProcessing = true);
    try {
      final res = await _apiService.completeOpportunity(widget.opportunityId);
      if (!mounted) return;
      if (res.data != null && res.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction completed! You can now leave a rating and feedback.'),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _openGoogleMaps(String? url) async {
    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to launch Google Maps location.')),
      );
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
    final authProvider = Provider.of<AuthProvider>(context);
    final isFarmer = authProvider.userRole == 'FARMER';
    final primaryColor = isFarmer ? AppColors.primary : AppColors.secondary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Opportunity Details'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDetail,
          ),
        ],
      ),
      body: _buildBody(authProvider),
    );
  }

  Widget _buildBody(AuthProvider auth) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null || _opportunity == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_errorMessage ?? 'Opportunity not found', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(onPressed: _fetchDetail, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final op = _opportunity!;
    final isFarmer = auth.userRole == 'FARMER';
    final currentUserId = auth.userId;

    // Check initiator vs receiver
    final isInitiatedByMe = (isFarmer && op.initiatedBy == 'FARMER') || (!isFarmer && op.initiatedBy == 'BUYER') || (currentUserId == (op.initiatedBy == 'FARMER' ? op.farmerId : op.buyerId));
    final isReceiver = !isInitiatedByMe;

    final isPending = op.isPending;
    final isAccepted = op.isAccepted;
    final isCompleted = op.isCompleted;
    final isRejected = op.isRejected;
    final isCancelled = op.isCancelled;

    final otherPartyName = isFarmer ? op.buyerName : op.farmerName;
    final otherPartyRole = isFarmer ? 'Buyer' : 'Farmer';
    final otherPartyRatingLabel = isFarmer ? op.buyerRatingLabel : op.farmerRatingLabel;
    final otherPartyPhone = isFarmer ? op.buyerPhone : op.farmerPhone;
    final otherPartyLocation = isFarmer ? op.buyerLocation : op.farmerLocation;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Status Card
          Card(
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              op.commodity,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isInitiatedByMe
                                  ? 'Initiated by You (Sent)'
                                  : 'Received from $otherPartyName',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isInitiatedByMe ? AppColors.textSecondary : (isFarmer ? AppColors.primary : AppColors.secondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusBgColor(op.status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          op.status.toUpperCase(),
                          style: TextStyle(
                            color: _getStatusTextColor(op.status),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quantity', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text(
                            '${op.quantity.toStringAsFixed(0)} ${op.quantityUnit}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Agreed / Offered Price', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text(
                            '₹${op.offeredPrice.toStringAsFixed(0)} / Quintal',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isFarmer ? AppColors.primary : AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 2. 3-Column Price Comparison Matrix (Farmer vs. Market Ref vs. Buyer)
          Card(
            elevation: AppConstants.cardElevation,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Price Comparison Matrix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _PriceCol(
                          label: 'Farmer Expected',
                          price: op.expectedPrice > 0 ? '₹${op.expectedPrice.toStringAsFixed(0)}' : 'Market',
                          color: AppColors.primary,
                        ),
                        _PriceCol(
                          label: 'Market Ref (AGMARKNET)',
                          price: op.marketReferencePrice > 0 ? '₹${op.marketReferencePrice.toStringAsFixed(0)}' : 'Available',
                          color: AppColors.textSecondary,
                        ),
                        _PriceCol(
                          label: 'Buyer Offered',
                          price: '₹${op.offeredPrice.toStringAsFixed(0)}',
                          color: AppColors.secondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 3. Counterparty Details Card
          Card(
            elevation: AppConstants.cardElevation,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$otherPartyRole Details', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Divider(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: (isFarmer ? AppColors.secondary : AppColors.primary).withValues(alpha: 0.1),
                        child: Icon(
                          isFarmer ? Icons.storefront : Icons.agriculture,
                          color: isFarmer ? AppColors.secondary : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(otherPartyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            if (isFarmer && op.buyerBusinessName.isNotEmpty)
                              Text(op.buyerBusinessName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            if (otherPartyLocation.isNotEmpty)
                              Text(otherPartyLocation, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      Chip(
                        avatar: const Icon(Icons.star, size: 14, color: Color(0xFFD97706)),
                        label: Text(
                          otherPartyRatingLabel,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: const Color(0xFFFEF3C7),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  if ((isAccepted || isCompleted) && otherPartyPhone.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone, size: 18, color: AppColors.success),
                          const SizedBox(width: 8),
                          Text(
                            'Contact Phone: $otherPartyPhone',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF166534)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 4. Location & Google Maps Card
          Card(
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
                      const Text('Location & Distance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (op.distanceKm != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.near_me, size: 12, color: Color(0xFF0284C7)),
                              const SizedBox(width: 4),
                              Text(
                                '${op.distanceKm!.toStringAsFixed(1)} km away',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (otherPartyLocation.isNotEmpty)
                    Text(otherPartyLocation, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openGoogleMaps(op.googleMapsUrl),
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('Open in Google Maps'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (op.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              elevation: AppConstants.cardElevation,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Notes / Terms', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(op.notes, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // 5. Action Buttons (Role-aware & Status-aware)
          if (_isProcessing)
            const Center(child: CircularProgressIndicator())
          else if (isPending) ...[
            if (isReceiver)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _handleReject,
                      child: const Text('Decline Offer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFarmer ? AppColors.primary : AppColors.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _handleAccept,
                      child: const Text('Accept Offer'),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _handleCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Withdraw / Cancel Interest'),
                ),
              ),
          ] else if (isAccepted) ...[
            if (op.dealId != null && op.dealId!.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => context.push(AppConstants.routeDealDetail, extra: op.dealId!),
                  icon: const Icon(Icons.handshake),
                  label: const Text('View Deal (Logistics & Payment)'),
                ),
              ),
              const SizedBox(height: 10),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => context.push(isFarmer ? AppConstants.routeFarmerDeals : AppConstants.routeBuyerDeals),
                  icon: const Icon(Icons.handshake),
                  label: const Text('Go to My Deals'),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _handleComplete,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Mark Transaction Completed'),
              ),
            ),
          ] else if (isCompleted) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFarmer ? AppColors.secondary : const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  if (isFarmer) {
                    context.push(AppConstants.routeRateBuyer, extra: op.id);
                  } else {
                    context.push(AppConstants.routeRateFarmer, extra: op.id);
                  }
                },
                icon: const Icon(Icons.star_rate),
                label: Text('Rate $otherPartyRole'),
              ),
            ),
          ] else if (isRejected || isCancelled) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isRejected ? 'This opportunity was declined.' : 'This opportunity was cancelled.',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceCol extends StatelessWidget {
  final String label;
  final String price;
  final Color color;

  const _PriceCol({required this.label, required this.price, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(price, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ],
    );
  }
}

