import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

class FarmBottomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const FarmBottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}

class FarmBottomNav extends StatelessWidget {
  final int currentIndex;
  final String role; // 'FARMER' or 'BUYER'

  const FarmBottomNav({
    super.key,
    required this.currentIndex,
    this.role = 'FARMER',
  });

  List<FarmBottomNavItem> get _farmerItems => const [
        FarmBottomNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: 'Home',
          route: AppConstants.routeFarmerDashboard,
        ),
        FarmBottomNavItem(
          icon: Icons.grass_outlined,
          activeIcon: Icons.grass,
          label: 'My Crops',
          route: AppConstants.routeMyCrops,
        ),
        FarmBottomNavItem(
          icon: Icons.trending_up,
          activeIcon: Icons.trending_up,
          label: 'Markets',
          route: AppConstants.routeMarketPrices,
        ),
        FarmBottomNavItem(
          icon: Icons.handshake_outlined,
          activeIcon: Icons.handshake,
          label: 'Deals',
          route: AppConstants.routeFarmerDeals,
        ),
        FarmBottomNavItem(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'Profile',
          route: AppConstants.routeFarmerProfile,
        ),
      ];

  List<FarmBottomNavItem> get _buyerItems => const [
        FarmBottomNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: 'Home',
          route: AppConstants.routeBuyerDashboard,
        ),
        FarmBottomNavItem(
          icon: Icons.list_alt_outlined,
          activeIcon: Icons.list_alt,
          label: 'Requirements',
          route: AppConstants.routeBuyerRequirements,
        ),
        FarmBottomNavItem(
          icon: Icons.handshake_outlined,
          activeIcon: Icons.handshake,
          label: 'Offers',
          route: AppConstants.routeBuyerOpportunities,
        ),
        FarmBottomNavItem(
          icon: Icons.receipt_long_outlined,
          activeIcon: Icons.receipt_long,
          label: 'Deals',
          route: AppConstants.routeBuyerDeals,
        ),
        FarmBottomNavItem(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'Profile',
          route: AppConstants.routeBuyerProfile,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final items = role == 'BUYER' ? _buyerItems : _farmerItems;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == currentIndex;

              return InkWell(
                onTap: () {
                  if (!isSelected) {
                    context.go(item.route);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE2EFE0)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item.activeIcon : item.icon,
                        size: 22,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
