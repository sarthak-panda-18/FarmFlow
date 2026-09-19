import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/deal_service.dart';
import '../../services/location_service.dart';
import '../../widgets/farm_empty_state.dart';

class DealAgreementScreen extends StatefulWidget {
  final String dealId;

  const DealAgreementScreen({super.key, required this.dealId});

  @override
  State<DealAgreementScreen> createState() => _DealAgreementScreenState();
}

class _DealAgreementScreenState extends State<DealAgreementScreen> {
  final DealService _dealService = DealService();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, dynamic>? _agreementData;

  bool _hasAgreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _fetchAgreement();
  }

  Future<void> _fetchAgreement() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _dealService.getDealAgreement(widget.dealId);
      if (mounted) {
        setState(() {
          _agreementData = data;
          _isLoading = false;
          // If current user has already accepted, check the box by default
          if (data['userHasAccepted'] == true) {
            _hasAgreedToTerms = true;
          }
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

  Future<void> _handleAcceptAgreement() async {
    if (!_hasAgreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please check the box to agree to the Terms & Conditions before accepting.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentVersion = _agreementData?['agreementVersion'] as int? ?? 1;
      final result = await _dealService.acceptDealAgreement(
        widget.dealId,
        agreeToTerms: true,
        agreementVersion: currentVersion,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        final bool bothAccepted = result['bothAccepted'] == true;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(bothAccepted
                ? 'Mutual agreement confirmed! Deal is officially confirmed.'
                : 'Agreement accepted. Waiting for counterparty.'),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchAgreement();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _openGoogleMaps(String? url, double? lat, double? lng,
      {String? address, String? label}) async {
    final success = await LocationService.launchGoogleMaps(
      latitude: lat,
      longitude: lng,
      address: address,
      mapsUrl: url,
      label: label,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to launch Google Maps.')),
      );
    }
  }

  String _formatCurrency(num? val) {
    if (val == null) return '₹0';
    final format =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return format.format(val);
  }

  String _formatDate(dynamic d) {
    if (d == null) return 'Not Specified';
    if (d is DateTime) {
      return DateFormat('dd MMM yyyy').format(d);
    }
    final parsed = DateTime.tryParse(d.toString());
    if (parsed != null) {
      return DateFormat('dd MMM yyyy').format(parsed);
    }
    return d.toString();
  }

  String _formatDateTime(dynamic d) {
    if (d == null) return '';
    final parsed = d is DateTime ? d : DateTime.tryParse(d.toString());
    if (parsed != null) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
    }
    return d.toString();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isFarmer = authProvider.userRole == 'FARMER';
    final themeColor = isFarmer ? AppColors.primary : AppColors.secondary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Official Deal Agreement'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading || _isSubmitting ? null : _fetchAgreement,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: FarmEmptyState(
                      icon: Icons.error_outline,
                      title: 'Unable to Load Agreement',
                      message: _errorMessage!,
                      actionLabel: 'Try Again',
                      actionIcon: Icons.refresh,
                      onAction: _fetchAgreement,
                    ),
                  ),
                )
              : _agreementData == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: FarmEmptyState(
                          icon: Icons.article_outlined,
                          title: 'Agreement not found',
                          message:
                              'Official deal agreement details could not be found.',
                          actionLabel: 'Go Back',
                          actionIcon: Icons.arrow_back,
                          onAction: () => Navigator.of(context).pop(),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchAgreement,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.all(AppConstants.paddingMedium),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Official Header Card
                            _buildHeaderCard(),
                            const SizedBox(height: 16),

                            // 2. Mutual Acceptance Progress Card
                            _buildMutualAcceptanceCard(),
                            const SizedBox(height: 16),

                            // 3. Agreement Details Card
                            _buildDetailsCard(),
                            const SizedBox(height: 16),

                            // 4. Logistics & Location Card
                            _buildLogisticsCard(),
                            const SizedBox(height: 16),

                            // 5. Terms & Conditions Card
                            _buildTermsCard(),
                            const SizedBox(height: 16),

                            // 6. Explicit Acceptance Checkbox & Button
                            _buildAcceptanceSection(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildHeaderCard() {
    final version = _agreementData!['agreementVersion'] ?? 1;
    final isFullyConfirmed = _agreementData!['isFullyConfirmed'] == true;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isFullyConfirmed
              ? const Color(0xFF16A34A)
              : const Color(0xFFCBD5E1),
          width: isFullyConfirmed ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  'Agreement v$version',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF475569)),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isFullyConfirmed
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFullyConfirmed
                        ? const Color(0xFF86EFAC)
                        : const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFullyConfirmed
                          ? Icons.check_circle
                          : Icons.hourglass_top,
                      size: 14,
                      color: isFullyConfirmed
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isFullyConfirmed
                          ? 'DEAL AGREEMENT CONFIRMED'
                          : ((_agreementData?['farmer']?['hasAccepted'] ==
                                      true &&
                                  _agreementData?['buyer']?['hasAccepted'] !=
                                      true)
                              ? 'WAITING FOR BUYER CONFIRMATION'
                              : ((_agreementData?['buyer']?['hasAccepted'] ==
                                          true &&
                                      _agreementData?['farmer']
                                              ?['hasAccepted'] !=
                                          true)
                                  ? 'WAITING FOR FARMER CONFIRMATION'
                                  : 'MUTUAL CONFIRMATION PENDING')),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isFullyConfirmed
                            ? const Color(0xFF15803D)
                            : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'FARMFLOW DEAL AGREEMENT',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Legally structured mutual agreement between Farmer & Buyer',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMutualAcceptanceCard() {
    final farmer = _agreementData!['farmer'] as Map<String, dynamic>? ?? {};
    final buyer = _agreementData!['buyer'] as Map<String, dynamic>? ?? {};

    final bool farmerAccepted = farmer['hasAccepted'] == true;
    final bool buyerAccepted = buyer['hasAccepted'] == true;

    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mutual Confirmation Status',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary),
            ),
            const Divider(height: 20),
            // Farmer Acceptance Row
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: farmerAccepted
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFF1F5F9),
                  child: Icon(
                    farmerAccepted ? Icons.check : Icons.person_outline,
                    color: farmerAccepted
                        ? const Color(0xFF16A34A)
                        : AppColors.textMuted,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Farmer: ${farmer['name'] ?? 'Farmer'}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        farmerAccepted
                            ? 'Accepted on ${_formatDateTime(farmer['acceptedAt'])}'
                            : 'Waiting for acceptance...',
                        style: TextStyle(
                          fontSize: 11,
                          color: farmerAccepted
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFD97706),
                          fontWeight: farmerAccepted
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  farmerAccepted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: farmerAccepted
                      ? const Color(0xFF16A34A)
                      : Colors.grey[400],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Buyer Acceptance Row
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: buyerAccepted
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFF1F5F9),
                  child: Icon(
                    buyerAccepted ? Icons.check : Icons.business_outlined,
                    color: buyerAccepted
                        ? const Color(0xFF16A34A)
                        : AppColors.textMuted,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buyer: ${buyer['businessName']?.isNotEmpty == true ? buyer['businessName'] : buyer['name'] ?? 'Buyer'}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        buyerAccepted
                            ? 'Accepted on ${_formatDateTime(buyer['acceptedAt'])}'
                            : 'Waiting for acceptance...',
                        style: TextStyle(
                          fontSize: 11,
                          color: buyerAccepted
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFD97706),
                          fontWeight: buyerAccepted
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  buyerAccepted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: buyerAccepted
                      ? const Color(0xFF16A34A)
                      : Colors.grey[400],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    final d = _agreementData!;
    final farmer = d['farmer'] as Map<String, dynamic>? ?? {};
    final buyer = d['buyer'] as Map<String, dynamic>? ?? {};

    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agreed Deal Parameters',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary),
            ),
            const Divider(height: 20),
            _buildInfoRow('Farmer Name:', farmer['name'] ?? 'Farmer'),
            _buildInfoRow(
                'Buyer Name:',
                buyer['businessName']?.isNotEmpty == true
                    ? buyer['businessName']
                    : buyer['name'] ?? 'Buyer'),
            _buildInfoRow('Crop:', d['crop'] ?? d['commodity'] ?? 'Crop'),
            if (d['variety'] != null && d['variety'].toString().isNotEmpty)
              _buildInfoRow('Variety:', d['variety'].toString()),
            _buildInfoRow('Quantity:', '${d['quantity']} Quintal'),
            _buildInfoRow('Agreed Price:', '₹${d['agreedPrice']} / Quintal'),
            _buildInfoRow(
                'Total Deal Value:', _formatCurrency(d['totalAmount']),
                isBold: true, highlightColor: AppColors.primary),
            _buildInfoRow(
                'Delivery / Required Date:', _formatDate(d['deliveryDate'])),
            const Divider(height: 20),
            _buildInfoRow(
                'Transport Required:',
                d['transportRequired'] == true
                    ? 'Yes (${d['transportType'] ?? 'Road'})'
                    : 'Not Required'),
            _buildInfoRow('Estimated Transport Cost:',
                _formatCurrency(d['transportCost'])),
            _buildInfoRow('Other Costs (Loading/Packaging):',
                _formatCurrency(d['otherCosts'])),
            _buildInfoRow('Estimated Net Return (Farmer):',
                _formatCurrency(d['estimatedNetReturn']),
                isBold: true, highlightColor: const Color(0xFF16A34A)),
            _buildInfoRow('Estimated Total Landed Cost (Buyer):',
                _formatCurrency(d['estimatedTotalBuyerCost']),
                isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildLogisticsCard() {
    final d = _agreementData!;
    final pickup = d['pickupLocation'] as Map<String, dynamic>? ?? {};
    final delivery = d['deliveryLocation'] as Map<String, dynamic>? ?? {};

    final double? pLat = (pickup['latitude'] as num?)?.toDouble();
    final double? pLng = (pickup['longitude'] as num?)?.toDouble();
    final double? dLat = (delivery['latitude'] as num?)?.toDouble();
    final double? dLng = (delivery['longitude'] as num?)?.toDouble();

    final String? pMaps = pickup['mapsUrl'];
    final String? dMaps = delivery['mapsUrl'];

    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Location & Route Details',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary),
                ),
                if (d['distanceKm'] != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Distance: ${d['distanceKm']} km',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Color(0xFF2563EB)),
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            // Pickup
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.storefront_outlined,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pickup Location (Farmer)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        pickup['address']?.isNotEmpty == true
                            ? pickup['address']
                            : 'Address not specified',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openGoogleMaps(pMaps, pLat, pLng,
                      address: pickup['address'],
                      label: 'Pickup Location (Farmer)'),
                  icon: const Icon(Icons.map, size: 16),
                  label: const Text('Maps', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Delivery
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 20, color: AppColors.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Delivery Location (Buyer)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        delivery['address']?.isNotEmpty == true
                            ? delivery['address']
                            : 'Address not specified',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openGoogleMaps(dMaps, dLat, dLng,
                      address: delivery['address'],
                      label: 'Delivery Location (Buyer)'),
                  icon: const Icon(Icons.map, size: 16),
                  label: const Text('Maps', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsCard() {
    final List terms = (_agreementData!['termsAndConditions'] as List?) ?? [];

    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.gavel_outlined, size: 20, color: Color(0xFF475569)),
                SizedBox(width: 8),
                Text(
                  'Terms & Conditions',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
            const Divider(height: 20),
            ...terms.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.primary)),
                      Expanded(
                        child: Text(
                          t.toString().replaceFirst(RegExp(r'^\d+\.\s*'), ''),
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptanceSection() {
    final bool userHasAccepted = _agreementData!['userHasAccepted'] == true;
    final bool isFullyConfirmed = _agreementData!['isFullyConfirmed'] == true;

    if (isFullyConfirmed) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified, color: Color(0xFF16A34A), size: 24),
            SizedBox(width: 10),
            Text(
              'Agreement Mutually Confirmed & Locked',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF15803D)),
            ),
          ],
        ),
      );
    }

    if (userHasAccepted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: const Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, color: Color(0xFF16A34A)),
                SizedBox(width: 8),
                Text(
                  'You have accepted this agreement.',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF15803D),
                      fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              'Waiting for counterparty to review and accept.',
              style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Required Checkbox
        CheckboxListTile(
          value: _hasAgreedToTerms,
          activeColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            'I have reviewed and agree to the above terms and deal specifications.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          onChanged: _isSubmitting
              ? null
              : (val) {
                  setState(() {
                    _hasAgreedToTerms = val ?? false;
                  });
                },
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: (_hasAgreedToTerms && !_isSubmitting)
              ? _handleAcceptAgreement
              : null,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.handshake_outlined),
          label: Text(
            _isSubmitting
                ? 'Recording Agreement...'
                : 'Accept Official Agreement',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool isBold = false, Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: highlightColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
