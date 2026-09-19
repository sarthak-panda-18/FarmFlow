import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_strings.dart';
import '../../models/crop_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/farm_badge.dart';
import '../../widgets/farm_bottom_nav.dart';
import '../../widgets/farm_card.dart';
import '../../widgets/farm_empty_state.dart';
import '../../widgets/farm_section_header.dart';
import '../../widgets/notification_bell_button.dart';
import '../../widgets/verification_status_banner.dart';

class FarmerDashboardScreen extends StatefulWidget {
  const FarmerDashboardScreen({super.key});

  @override
  State<FarmerDashboardScreen> createState() => _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState extends State<FarmerDashboardScreen> {
  final ApiService _apiService = ApiService();
  int _activeCropsCount = 0;
  List<CropModel> _recentActiveCrops = [];
  bool _isLoadingCrops = true;

  String _ratingDisplay = '⭐ New Farmer';

  @override
  void initState() {
    super.initState();
    _fetchCropsData();
    _fetchRatingStats();
  }

  Future<void> _fetchCropsData() async {
    try {
      final response = await _apiService.getMyCrops(page: 1, limit: 100);
      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> body = response.data;
        if (body['success'] == true && body['data'] != null) {
          final List cropsRaw = body['data'];
          final parsed =
              cropsRaw.map((item) => CropModel.fromJson(item)).toList();
          final activeCrops =
              parsed.where((c) => c.status == 'AVAILABLE').toList();
          if (mounted) {
            setState(() {
              _activeCropsCount = activeCrops.length;
              _recentActiveCrops = activeCrops.take(3).toList();
              _isLoadingCrops = false;
            });
          }
          return;
        }
      }
      if (mounted) {
        setState(() {
          _isLoadingCrops = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingCrops = false;
        });
      }
    }
  }

  Future<void> _fetchRatingStats() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.userId != null) {
        final res = await _apiService.getUserRating(auth.userId!);
        if (mounted && res.data != null && res.data['success'] == true) {
          final stats = res.data['data'];
          setState(() {
            _ratingDisplay = stats['displayRating'] ?? '⭐ New Farmer';
          });
        }
      }
    } catch (_) {}
  }

  void _handleAddCropPressed(AuthProvider authProvider) {
    if (!authProvider.isPhoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please verify your mobile number before adding crops.'),
          backgroundColor: AppColors.error,
        ),
      );
      context.push(AppConstants.routeOtpVerification);
      return;
    }

    if (authProvider.verificationStatus != 'VERIFIED') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.verificationStatus == 'PENDING'
                ? 'Your farmer verification is pending approval.'
                : 'Your farmer verification was rejected. Please resubmit verification.',
          ),
          backgroundColor: AppColors.warning,
          action: SnackBarAction(
            label: 'Verify Now',
            textColor: Colors.white,
            onPressed: () {
              context.push(AppConstants.routeFarmerVerification);
            },
          ),
        ),
      );
      context.push(AppConstants.routeFarmerVerification);
      return;
    }

    context.push(AppConstants.routeAddCrop).then((_) => _fetchCropsData());
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final farmerName = authProvider.userName ?? 'Farmer';
    final farmerPhone = authProvider.userPhone ?? 'Mobile Not Set';
    final userAddress =
        authProvider.userAddress ?? authProvider.userDistrict ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.agriculture, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'FarmFlow',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          const NotificationBellButton(),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Logout',
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) {
                context.go(AppConstants.routeLogin);
              }
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context, authProvider, farmerName, farmerPhone),
      bottomNavigationBar: const FarmBottomNav(currentIndex: 0, role: 'FARMER'),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await authProvider.refreshUserProfile();
          await _fetchCropsData();
          await _fetchRatingStats();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Farmer Profile Summary Card (Farm2Market Pale Green Card Style)
              FarmCard(
                variant: FarmCardVariant.paleGreen,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: const Center(
                        child: Icon(Icons.person,
                            color: AppColors.primary, size: 30),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  farmerName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (userAddress.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    size: 13, color: AppColors.textMuted),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    userAddress,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              FarmBadge(
                                label: authProvider.isFullyVerified
                                    ? 'Verified Farmer'
                                    : 'Verification: ${authProvider.verificationStatus}',
                                icon: authProvider.isFullyVerified
                                    ? Icons.check_circle
                                    : Icons.hourglass_empty,
                                type: authProvider.isFullyVerified
                                    ? FarmBadgeType.success
                                    : FarmBadgeType.warning,
                              ),
                              FarmBadge(
                                label: _ratingDisplay,
                                type: FarmBadgeType.neutral,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Verification Status Banner Component
              const VerificationStatusBanner(),

              const SizedBox(height: 16),

              // 2. Summary Metric Cards Row
              Row(
                children: [
                  Expanded(
                    child: FarmCard(
                      variant: FarmCardVariant.white,
                      padding: const EdgeInsets.all(14),
                      onTap: () async {
                        await context.push(AppConstants.routeMyCrops);
                        _fetchCropsData();
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2EFE0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.grass,
                                    color: AppColors.primary, size: 18),
                              ),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 12, color: AppColors.textMuted),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isLoadingCrops ? '...' : '$_activeCropsCount',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Active Crops Listed',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FarmCard(
                      variant: FarmCardVariant.white,
                      padding: const EdgeInsets.all(14),
                      onTap: () => context.push(AppConstants.routeMarketPrices),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2EFE0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.trending_up,
                                    color: AppColors.primary, size: 18),
                              ),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 12, color: AppColors.textMuted),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Market Prices',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Live Mandi Rates',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 3. Quick Actions Section
              const FarmSectionHeader(
                title: 'Quick Actions',
                subtitle: 'Manage listings, explore markets & track deals',
                icon: Icons.flash_on,
              ),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.85,
                children: [
                  _buildQuickActionTile(
                    title: 'Add Crop',
                    icon: Icons.add_circle_outline,
                    color: AppColors.primary,
                    onTap: () => _handleAddCropPressed(authProvider),
                  ),
                  _buildQuickActionTile(
                    title: 'My Crops',
                    icon: Icons.grass,
                    color: const Color(0xFF16A34A),
                    onTap: () async {
                      await context.push(AppConstants.routeMyCrops);
                      _fetchCropsData();
                    },
                  ),
                  _buildQuickActionTile(
                    title: 'Price Trends',
                    icon: Icons.trending_up,
                    color: const Color(0xFFD97706),
                    onTap: () => context.push(AppConstants.routeMarketPrices),
                  ),
                  _buildQuickActionTile(
                    title: 'Matched',
                    icon: Icons.compare_arrows,
                    color: const Color(0xFF0284C7),
                    onTap: () => context.push(AppConstants.routeFarmerMatches),
                  ),
                  _buildQuickActionTile(
                    title: 'Offers',
                    icon: Icons.handshake_outlined,
                    color: const Color(0xFF0D9488),
                    onTap: () =>
                        context.push(AppConstants.routeFarmerOpportunities),
                  ),
                  _buildQuickActionTile(
                    title: 'My Deals',
                    icon: Icons.receipt_long_outlined,
                    color: const Color(0xFF2563EB),
                    onTap: () => context.push(AppConstants.routeFarmerDeals),
                  ),
                  _buildQuickActionTile(
                    title: 'Nearby Map',
                    icon: Icons.map_outlined,
                    color: const Color(0xFF059669),
                    onTap: () => context.push(AppConstants.routeMapDiscovery,
                        extra: 'FARMER'),
                  ),
                  _buildQuickActionTile(
                    title: 'Profile',
                    icon: Icons.person_outline,
                    color: const Color(0xFF7C3AED),
                    onTap: () => context.push(AppConstants.routeFarmerProfile),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 4. Active Crops Highlight Section
              FarmSectionHeader(
                title: 'My Active Crops',
                subtitle: 'Manage current crop produce and selling status',
                icon: Icons.inventory_2_outlined,
                actionText: _activeCropsCount > 0
                    ? 'View All ($_activeCropsCount)'
                    : null,
                onAction: () async {
                  await context.push(AppConstants.routeMyCrops);
                  _fetchCropsData();
                },
              ),

              if (_isLoadingCrops)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2.5),
                  ),
                )
              else if (_recentActiveCrops.isEmpty)
                FarmCard(
                  variant: FarmCardVariant.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: FarmEmptyState(
                    icon: Icons.grass_outlined,
                    title: 'No active crops listed',
                    message:
                        'Add your crop produce to receive buyer offers and AI selling recommendations.',
                    actionLabel: 'Add Your First Crop',
                    actionIcon: Icons.add_circle_outline,
                    onAction: () => _handleAddCropPressed(authProvider),
                  ),
                )
              else ...[
                ..._recentActiveCrops
                    .map((crop) => _buildCropSummaryCard(crop)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleAddCropPressed(authProvider),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('+ Add Another Crop'),
                  ),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCropSummaryCard(CropModel crop) {
    final locationParts = [crop.market, crop.district, crop.state];
    final locStr =
        locationParts.where((e) => e != null && e.isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () async {
            final res =
                await context.push(AppConstants.routeCropDetail, extra: crop);
            if (res == true && mounted) _fetchCropsData();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2EFE0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child:
                        Icon(Icons.grass, color: AppColors.primary, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              crop.cropName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          FarmBadge(
                            label: '${crop.quantity} ${crop.quantityUnit}',
                            type: FarmBadgeType.primary,
                            fontSize: 10,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${crop.commodity}${crop.variety != null && crop.variety!.isNotEmpty ? " • ${crop.variety}" : ""}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      if (locStr.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 11, color: AppColors.textMuted),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                locStr,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, AuthProvider authProvider,
      String name, String phone) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            accountEmail:
                Text('Mobile: $phone', style: const TextStyle(fontSize: 13)),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child:
                  Icon(Icons.agriculture, color: AppColors.primary, size: 32),
            ),
            decoration: const BoxDecoration(color: AppColors.primary),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard, color: AppColors.primary),
            title: const Text(AppStrings.farmerDashboard,
                style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Farmer Profile'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppConstants.routeFarmerProfile);
            },
          ),
          ListTile(
            leading: const Icon(Icons.verified_user),
            title: const Text('Farmer Verification'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppConstants.routeFarmerVerification);
            },
          ),
          ListTile(
            leading: const Icon(Icons.grass),
            title: const Text(AppStrings.myCrops),
            onTap: () async {
              Navigator.pop(context);
              await context.push(AppConstants.routeMyCrops);
              _fetchCropsData();
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Add Crop'),
            onTap: () {
              Navigator.pop(context);
              _handleAddCropPressed(authProvider);
            },
          ),
          ListTile(
            leading: const Icon(Icons.handshake_outlined),
            title: const Text('Opportunities & Offers'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppConstants.routeFarmerOpportunities);
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined,
                color: Color(0xFF2563EB)),
            title: const Text('My Deals'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppConstants.routeFarmerDeals);
            },
          ),
          ListTile(
            leading: const Icon(Icons.trending_up, color: Color(0xFF16A34A)),
            title: const Text('Market Prices'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppConstants.routeMarketPrices);
            },
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined, color: Color(0xFF0284C7)),
            title: const Text('Nearby Map & Discovery'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppConstants.routeMapDiscovery, extra: 'FARMER');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title:
                const Text('Logout', style: TextStyle(color: AppColors.error)),
            onTap: () async {
              Navigator.pop(context);
              await authProvider.logout();
              if (context.mounted) {
                context.go(AppConstants.routeLogin);
              }
            },
          ),
        ],
      ),
    );
  }
}
