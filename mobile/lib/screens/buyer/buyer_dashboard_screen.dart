import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/buyer_provider.dart';
import '../../widgets/notification_bell_button.dart';

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
      Provider.of<BuyerProvider>(context, listen: false).fetchRequirements(refresh: true);
    });
  }

  void _handleCreateRequirementPressed(AuthProvider authProvider) async {
    if (!authProvider.isPhoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your mobile number before creating requirements.'),
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
      Provider.of<BuyerProvider>(context, listen: false).fetchRequirements(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final buyerProvider = Provider.of<BuyerProvider>(context);

    final buyerName = authProvider.userName ?? 'Buyer';
    final buyerPhone = authProvider.userPhone ?? 'Mobile Not Set';
    final activeCount = buyerProvider.activeRequirementsCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.buyerDashboard),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        actions: [
          const NotificationBellButton(),
          IconButton(
            icon: const Icon(Icons.logout),
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(buyerName),
              accountEmail: Text('Mobile: $buyerPhone'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.storefront, color: AppColors.secondary),
              ),
              decoration: const BoxDecoration(color: AppColors.secondary),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text(AppStrings.buyerDashboard),
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
              leading: const Icon(Icons.handshake_outlined, color: Color(0xFF2563EB)),
              title: const Text('My Deals'),
              onTap: () {
                Navigator.pop(context);
                context.push(AppConstants.routeBuyerDeals);
              },
            ),
            ListTile(
              leading: const Icon(Icons.compare_arrows, color: AppColors.secondary),
              title: const Text('Matched Crops (Phase 7)'),
              onTap: () {
                Navigator.pop(context);
                context.push(AppConstants.routeBuyerMatches);
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined, color: Color(0xFF0284C7)),
              title: const Text('Map & Nearby (Phase 6)'),
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
              leading: const Icon(Icons.trending_up),
              title: const Text('Market Prices'),
              onTap: () {
                Navigator.pop(context);
                context.push(AppConstants.routeMarketPrices);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.pop(context);
                context.push(AppConstants.routeNotifications);
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
              title: const Text('Logout'),
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
      ),
      body: RefreshIndicator(
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
              // Welcome Header Card
              Card(
                color: AppColors.surface,
                elevation: AppConstants.cardElevation,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingMedium),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Color(0xFFFEF3C7),
                        child: Icon(Icons.storefront, color: AppColors.secondary, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, $buyerName',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Chip(
                              avatar: Icon(
                                authProvider.isFullyVerified ? Icons.check_circle : Icons.hourglass_empty,
                                size: 16,
                                color: authProvider.isFullyVerified ? AppColors.secondary : const Color(0xFFD97706),
                              ),
                              label: Text(
                                'Role: Buyer (${authProvider.isFullyVerified ? "Verified" : "Active"})',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: const Color(0xFFFEF3C7),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Active Summary Banner Card
              Card(
                color: AppColors.secondary.withValues(alpha: 0.1),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Requirements',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            buyerProvider.isLoading
                                ? 'Loading requirements...'
                                : '$activeCount Active ${activeCount == 1 ? 'Requirement' : 'Requirements'}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => context.push(AppConstants.routeBuyerRequirements),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('View All'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Buyer Feature Modules',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: [
                  _BuyerFeatureCard(
                    title: 'Matched Crops',
                    subtitle: 'Direct crop matching',
                    icon: Icons.compare_arrows,
                    color: AppColors.secondary,
                    onTap: () => context.push(AppConstants.routeBuyerMatches),
                  ),
                  _BuyerFeatureCard(
                    title: 'Nearby Map',
                    subtitle: 'Nearby farmers & mandis',
                    icon: Icons.map_outlined,
                    color: const Color(0xFF0284C7),
                    onTap: () => context.push(AppConstants.routeMapDiscovery, extra: 'BUYER'),
                  ),
                  _BuyerFeatureCard(
                    title: 'Farmer Opportunities',
                    subtitle: 'Discover crops & responses',
                    icon: Icons.handshake,
                    color: const Color(0xFFD97706),
                    onTap: () => context.push(AppConstants.routeBuyerOpportunities),
                  ),
                  _BuyerFeatureCard(
                    title: 'My Deals',
                    subtitle: 'Agreed deals & logistics',
                    icon: Icons.handshake_outlined,
                    color: const Color(0xFF2563EB),
                    onTap: () => context.push(AppConstants.routeBuyerDeals),
                  ),
                  _BuyerFeatureCard(
                    title: 'My Requirements',
                    subtitle: '$activeCount Active Demand(s)',
                    icon: Icons.assignment,
                    color: const Color(0xFF16A34A),
                    onTap: () => context.push(AppConstants.routeBuyerRequirements),
                  ),
                  _BuyerFeatureCard(
                    title: 'Market Prices',
                    subtitle: 'AGMARKNET trends',
                    icon: Icons.trending_up,
                    color: const Color(0xFF0284C7),
                    onTap: () => context.push(AppConstants.routeMarketPrices),
                  ),
                  _BuyerFeatureCard(
                    title: 'Post Requirement',
                    subtitle: 'Publish crop demand',
                    icon: Icons.add_circle,
                    color: AppColors.success,
                    onTap: () => _handleCreateRequirementPressed(authProvider),
                  ),
                  _BuyerFeatureCard(
                    title: 'Notifications',
                    subtitle: 'Alerts & updates',
                    icon: Icons.notifications_outlined,
                    color: const Color(0xFF8B5CF6),
                    onTap: () => context.push(AppConstants.routeNotifications),
                  ),
                  _BuyerFeatureCard(
                    title: 'Buyer Profile',
                    subtitle: 'GSTIN & details',
                    icon: Icons.person,
                    color: AppColors.info,
                    onTap: () => context.push(AppConstants.routeBuyerProfile),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuyerFeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BuyerFeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
