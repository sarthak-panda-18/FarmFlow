import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_strings.dart';
import '../../models/buyer_requirement_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/buyer_provider.dart';
import '../../widgets/farm_badge.dart';
import '../../widgets/farm_bottom_nav.dart';
import '../../widgets/farm_card.dart';
import '../../widgets/farm_empty_state.dart';
import '../../widgets/farm_section_header.dart';
import '../../widgets/notification_bell_button.dart';
import '../../widgets/verification_status_banner.dart';

class BuyerDashboardScreen extends StatefulWidget {
  const BuyerDashboardScreen({super.key});

  @override
  State<BuyerDashboardScreen> createState() => _BuyerDashboardScreenState();
}

class _BuyerDashboardScreenState extends State<BuyerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BuyerProvider>(context, listen: false)
          .fetchRequirements(refresh: true);
    });
  }

  void _handleCreateRequirementPressed(AuthProvider authProvider) async {
    if (!authProvider.isPhoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please verify your mobile number before creating requirements.'),
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
                ? 'Your buyer business verification is pending approval.'
                : 'Your buyer verification was rejected. Please resubmit verification.',
          ),
          backgroundColor: AppColors.warning,
          action: SnackBarAction(
            label: 'Verify Now',
            textColor: Colors.white,
            onPressed: () {
              context.push(AppConstants.routeBuyerVerification);
            },
          ),
        ),
      );
      context.push(AppConstants.routeBuyerVerification);
      return;
    }

    final res = await context.push<bool>(AppConstants.routeCreateRequirement);
    if (res == true && mounted) {
      Provider.of<BuyerProvider>(context, listen: false)
          .fetchRequirements(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final buyerProvider = Provider.of<BuyerProvider>(context);

    final buyerName = authProvider.userName ?? 'Buyer';
    final buyerPhone = authProvider.userPhone ?? 'Mobile Not Set';
    final activeCount = buyerProvider.activeRequirementsCount;
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
                  const Icon(Icons.storefront, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'FarmFlow Buyer',
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
      drawer: _buildDrawer(context, authProvider, buyerName, buyerPhone),
      bottomNavigationBar: const FarmBottomNav(currentIndex: 0, role: 'BUYER'),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await authProvider.refreshUserProfile();
          await buyerProvider.fetchRequirements(refresh: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Buyer Profile Summary Card (Pale Green)
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
                        child: Icon(Icons.storefront,
                            color: AppColors.primary, size: 28),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            buyerName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                                    ? 'Verified Buyer'
                                    : 'Verification: ${authProvider.verificationStatus}',
                                icon: authProvider.isFullyVerified
                                    ? Icons.check_circle
                                    : Icons.hourglass_empty,
                                type: authProvider.isFullyVerified
                                    ? FarmBadgeType.success
                                    : FarmBadgeType.warning,
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
                      onTap: () =>
                          context.push(AppConstants.routeBuyerRequirements),
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
                                child: const Icon(Icons.list_alt,
                                    color: AppColors.primary, size: 18),
                              ),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 12, color: AppColors.textMuted),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$activeCount',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Active Requirements',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary),
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
                      onTap: () =>
                          context.push(AppConstants.routeBuyerOpportunities),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.handshake_outlined,
                                    color: Color(0xFFB45309), size: 18),
                              ),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 12, color: AppColors.textMuted),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Farmer Offers',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Review Incoming',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 3. Quick Actions
              const FarmSectionHeader(
                title: 'Quick Actions',
                subtitle: 'Manage buying demand, view matches & agreements',
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
                    title: 'Post Req',
                    icon: Icons.add_circle_outline,
                    color: AppColors.primary,
                    onTap: () => _handleCreateRequirementPressed(authProvider),
                  ),
                  _buildQuickActionTile(
                    title: 'My Demands',
                    icon: Icons.list_alt,
                    color: const Color(0xFF16A34A),
                    onTap: () =>
                        context.push(AppConstants.routeBuyerRequirements),
                  ),
                  _buildQuickActionTile(
                    title: 'Matched',
                    icon: Icons.compare_arrows,
                    color: const Color(0xFF0284C7),
                    onTap: () => context.push(AppConstants.routeBuyerMatches),
                  ),
                  _buildQuickActionTile(
                    title: 'Offers',
                    icon: Icons.handshake_outlined,
                    color: const Color(0xFF0D9488),
                    onTap: () =>
                        context.push(AppConstants.routeBuyerOpportunities),
                  ),
                  _buildQuickActionTile(
                    title: 'My Deals',
                    icon: Icons.receipt_long_outlined,
                    color: const Color(0xFF2563EB),
                    onTap: () => context.push(AppConstants.routeBuyerDeals),
                  ),
                  _buildQuickActionTile(
                    title: 'Markets',
                    icon: Icons.trending_up,
                    color: const Color(0xFF059669),
                    onTap: () => context.push(AppConstants.routeMarketPrices),
                  ),
                  _buildQuickActionTile(
                    title: 'Nearby Map',
                    icon: Icons.map_outlined,
                    color: const Color(0xFF7C3AED),
                    onTap: () => context.push(AppConstants.routeMapDiscovery,
                        extra: 'BUYER'),
                  ),
                  _buildQuickActionTile(
                    title: 'Profile',
                    icon: Icons.person_outline,
                    color: const Color(0xFF4B5563),
                    onTap: () => context.push(AppConstants.routeBuyerProfile),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 4. Active Requirements Highlight Section
              FarmSectionHeader(
                title: 'Active Requirements',
                subtitle: 'Your active crop procurement listings',
                icon: Icons.assignment_outlined,
                actionText: activeCount > 0 ? 'View All ($activeCount)' : null,
                onAction: () =>
                    context.push(AppConstants.routeBuyerRequirements),
              ),

              if (buyerProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2.5),
                  ),
                )
              else if (buyerProvider.requirements.isEmpty)
                FarmCard(
                  variant: FarmCardVariant.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: FarmEmptyState(
                    icon: Icons.list_alt_outlined,
                    title: 'No requirements posted',
                    message:
                        'Post your crop procurement demand to connect with verified farmers.',
                    actionLabel: 'Post Requirement',
                    actionIcon: Icons.add_circle_outline,
                    onAction: () =>
                        _handleCreateRequirementPressed(authProvider),
                  ),
                )
              else ...[
                ...buyerProvider.requirements
                    .take(3)
                    .map((req) => _buildRequirementCard(req)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _handleCreateRequirementPressed(authProvider),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('+ Post Another Requirement'),
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

  Widget _buildRequirementCard(BuyerRequirementModel req) {
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
            final res = await context.push(AppConstants.routeRequirementDetail,
                extra: req);
            if (res == true && mounted) {
              Provider.of<BuyerProvider>(context, listen: false)
                  .fetchRequirements(refresh: true);
            }
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
                    child: Icon(Icons.shopping_basket_outlined,
                        color: AppColors.primary, size: 22),
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
                              req.commodity,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          FarmBadge(
                            label: '${req.quantity} ${req.quantityUnit}',
                            type: FarmBadgeType.primary,
                            fontSize: 10,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Target Rate: ₹${req.offeredPrice.toStringAsFixed(0)} / ${req.quantityUnit}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
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
              child: Icon(Icons.storefront, color: AppColors.primary, size: 32),
            ),
            decoration: const BoxDecoration(color: AppColors.primary),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard, color: AppColors.primary),
            title: const Text(AppStrings.buyerDashboard,
                style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.handshake),
            title: const Text('Farmer Opportunities'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppConstants.routeBuyerOpportunities);
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined,
                color: Color(0xFF2563EB)),
            title: const Text('My Deals'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppConstants.routeBuyerDeals);
            },
          ),
          ListTile(
            leading: const Icon(Icons.compare_arrows, color: AppColors.primary),
            title: const Text('Matched Crops (Phase 7)'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppConstants.routeBuyerMatches);
            },
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined, color: Color(0xFF0284C7)),
            title: const Text('Nearby Map & Discovery'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppConstants.routeMapDiscovery, extra: 'BUYER');
            },
          ),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text(AppStrings.buyerRequirements),
            onTap: () {
              Navigator.pop(context);
              context.push(AppConstants.routeBuyerRequirements);
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Post Requirement'),
            onTap: () {
              Navigator.pop(context);
              _handleCreateRequirementPressed(authProvider);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text(AppStrings.buyerProfile),
            onTap: () {
              Navigator.pop(context);
              context.push(AppConstants.routeBuyerProfile);
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
