import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/verification_status_banner.dart';

class FarmerDashboardScreen extends StatefulWidget {
  const FarmerDashboardScreen({super.key});

  @override
  State<FarmerDashboardScreen> createState() => _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState extends State<FarmerDashboardScreen> {
  final ApiService _apiService = ApiService();
  int _activeCropsCount = 0;
  bool _isLoadingCrops = true;

  String _ratingDisplay = '⭐ New Farmer';

  @override
  void initState() {
    super.initState();
    _fetchCropsCount();
    _fetchRatingStats();
  }

  Future<void> _fetchCropsCount() async {
    try {
      final response = await _apiService.getMyCrops(page: 1, limit: 100);
      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> body = response.data;
        if (body['success'] == true && body['data'] != null) {
          final List crops = body['data'];
          final activeCrops = crops.where((c) => c['status'] == 'AVAILABLE').toList();
          if (mounted) {
            setState(() {
              _activeCropsCount = activeCrops.length;
              _isLoadingCrops = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingCrops = false;
          });
        }
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
          content: Text('Please verify your mobile number before adding crops.'),
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

    context.push(AppConstants.routeAddCrop).then((_) => _fetchCropsCount());
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final farmerName = authProvider.userName ?? 'Farmer';
    final farmerPhone = authProvider.userPhone ?? 'Mobile Not Set';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.farmerDashboard),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () => context.push(AppConstants.routeNotifications),
          ),
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
              accountName: Text(farmerName),
              accountEmail: Text('Mobile: $farmerPhone'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.agriculture, color: AppColors.primary),
              ),
              decoration: const BoxDecoration(color: AppColors.primary),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text(AppStrings.farmerDashboard),
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
                _fetchCropsCount();
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
              title: const Text('Opportunities'),
              onTap: () {
                Navigator.pop(context);
                context.push(AppConstants.routeFarmerOpportunities);
              },
            ),
            ListTile(
              leading: const Icon(Icons.compare_arrows, color: AppColors.primary),
              title: const Text('Matched Buyers (Phase 7)'),
              onTap: () {
                Navigator.pop(context);
                context.push(AppConstants.routeFarmerMatches);
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined, color: Color(0xFF0284C7)),
              title: const Text('Map & Nearby (Phase 6)'),
              onTap: () {
                Navigator.pop(context);
                context.push(AppConstants.routeMapDiscovery, extra: 'FARMER');
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
              leading: const Icon(Icons.trending_up),
              title: const Text('Market Prices'),
              onTap: () {
                Navigator.pop(context);
                context.push(AppConstants.routeMarketPrices);
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
          await _fetchCropsCount();
          await _fetchRatingStats();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header Card with Rating Badge
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
                        backgroundColor: Color(0xFFDCFCE7),
                        child: Icon(Icons.person, color: AppColors.primary, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, $farmerName',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  avatar: Icon(
                                    authProvider.isFullyVerified ? Icons.check_circle : Icons.hourglass_empty,
                                    size: 16,
                                    color: authProvider.isFullyVerified ? AppColors.primary : const Color(0xFFD97706),
                                  ),
                                  label: Text(
                                    'Role: Farmer (${authProvider.verificationStatus})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                  backgroundColor: const Color(0xFFDCFCE7),
                                  visualDensity: VisualDensity.compact,
                                ),
                                Chip(
                                  avatar: const Icon(Icons.star, size: 14, color: Color(0xFFD97706)),
                                  label: Text(
                                    _ratingDisplay,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                  backgroundColor: const Color(0xFFFEF3C7),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Verification Status Banner Component
              const VerificationStatusBanner(),

              const SizedBox(height: 16),

              Text(
                'Farmer Crop Management',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
              ),

              const SizedBox(height: 12),

              // Highlight Card: My Crops
              Card(
                elevation: AppConstants.cardElevation,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
                child: InkWell(
                  onTap: () async {
                    await context.push(AppConstants.routeMyCrops);
                    _fetchCropsCount();
                  },
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingMedium),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.grass, color: AppColors.primary, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Crops',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isLoadingCrops
                                    ? 'Loading active crops...'
                                    : '$_activeCropsCount Active ${_activeCropsCount == 1 ? "Crop" : "Crops"} Listed',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Action Card: Add New Crop
              Card(
                color: authProvider.isFullyVerified ? AppColors.primary : Colors.grey,
                elevation: AppConstants.cardElevation,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
                child: InkWell(
                  onTap: () => _handleAddCropPressed(authProvider),
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingMedium),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          authProvider.isFullyVerified ? Icons.add_circle : Icons.lock,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          authProvider.isFullyVerified ? 'Add New Crop' : 'Add New Crop (Verification Required)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Market Information & Buyer Interest',
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
                childAspectRatio: 1.3,
                children: [
                  _FeatureCard(
                    title: 'Matched Buyers',
                    subtitle: 'Direct crop matching',
                    icon: Icons.compare_arrows,
                    color: AppColors.primary,
                    onTap: () => context.push(AppConstants.routeFarmerMatches),
                  ),
                  _FeatureCard(
                    title: 'Nearby Map',
                    subtitle: 'Nearby buyers & mandis',
                    icon: Icons.map_outlined,
                    color: const Color(0xFF0284C7),
                    onTap: () => context.push(AppConstants.routeMapDiscovery, extra: 'FARMER'),
                  ),
                  _FeatureCard(
                    title: 'Opportunities',
                    subtitle: 'Buyer interest & offers',
                    icon: Icons.handshake_outlined,
                    color: AppColors.secondary,
                    onTap: () => context.push(AppConstants.routeFarmerOpportunities),
                  ),
                  _FeatureCard(
                    title: 'Market Prices',
                    subtitle: 'AGMARKNET reference rates',
                    icon: Icons.trending_up,
                    color: const Color(0xFF16A34A),
                    onTap: () => context.push(AppConstants.routeMarketPrices),
                  ),
                  _FeatureCard(
                    title: 'Notifications',
                    subtitle: 'Alerts & interest updates',
                    icon: Icons.notifications_outlined,
                    color: const Color(0xFFD97706),
                    onTap: () => context.push(AppConstants.routeNotifications),
                  ),
                  _FeatureCard(
                    title: 'Recommendations',
                    subtitle: 'Decision optimization',
                    icon: Icons.analytics,
                    color: const Color(0xFF6366F1),
                    onTap: () => context.push(AppConstants.routeFarmerRecommendations),
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

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
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
