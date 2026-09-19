import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_constants.dart';
import '../models/buyer_requirement_model.dart';
import '../models/crop_model.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/otp_verification_screen.dart';
import '../screens/farmer/add_crop_screen.dart';
import '../screens/farmer/crop_detail_screen.dart';
import '../screens/farmer/farmer_dashboard_screen.dart';
import '../screens/farmer/farmer_profile_screen.dart';
import '../screens/farmer/farmer_verification_screen.dart';
import '../screens/farmer/my_crops_screen.dart';
import '../screens/farmer/farmer_recommendations_screen.dart';
import '../screens/farmer/market_prices_screen.dart';
import '../screens/farmer/farmer_opportunities_screen.dart';
import '../screens/farmer/opportunity_detail_screen.dart';
import '../screens/farmer/rate_buyer_screen.dart';
import '../screens/farmer/farmer_notifications_screen.dart';
import '../screens/farmer/farmer_matches_screen.dart';
import '../screens/farmer/farmer_deals_screen.dart';
import '../screens/common/map_discovery_screen.dart';
import '../screens/common/deal_detail_screen.dart';
import '../screens/common/deal_agreement_screen.dart';
import '../screens/buyer/add_requirement_screen.dart';
import '../screens/buyer/buyer_dashboard_screen.dart';
import '../screens/buyer/buyer_requirements_screen.dart';
import '../screens/buyer/buyer_profile_screen.dart';
import '../screens/buyer/buyer_verification_screen.dart';
import '../screens/buyer/requirement_detail_screen.dart';
import '../screens/buyer/buyer_opportunities_screen.dart';
import '../screens/buyer/buyer_deals_screen.dart';
import '../screens/buyer/buyer_matches_screen.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: AppConstants.routeLogin,
    refreshListenable: authProvider,
    redirect: (BuildContext context, GoRouterState state) {
      if (authProvider.status == AuthStatus.loading) {
        return null;
      }

      final isAuthenticated = authProvider.isAuthenticated;
      final userRole = authProvider.userRole;
      final currentLocation = state.matchedLocation;

      final isAuthRoute = currentLocation == AppConstants.routeLogin ||
          currentLocation == AppConstants.routeRegister;

      final isFarmerRoute =
          currentLocation == AppConstants.routeFarmerDashboard ||
              currentLocation == AppConstants.routeFarmerProfile ||
              currentLocation == AppConstants.routeFarmerVerification ||
              currentLocation == AppConstants.routeMyCrops ||
              currentLocation == AppConstants.routeAddCrop ||
              currentLocation == AppConstants.routeEditCrop ||
              currentLocation == AppConstants.routeCropDetail ||
              currentLocation == AppConstants.routeFarmerRecommendations ||
              currentLocation == AppConstants.routeFarmerOpportunities ||
              currentLocation == AppConstants.routeFarmerDeals ||
              currentLocation == AppConstants.routeRateBuyer;

      final isBuyerRoute =
          currentLocation == AppConstants.routeBuyerDashboard ||
              currentLocation == AppConstants.routeBuyerProfile ||
              currentLocation == AppConstants.routeBuyerVerification ||
              currentLocation == AppConstants.routeBuyerRequirements ||
              currentLocation == AppConstants.routeCreateRequirement ||
              currentLocation == AppConstants.routeEditRequirement ||
              currentLocation == AppConstants.routeRequirementDetail ||
              currentLocation == AppConstants.routeBuyerOpportunities ||
              currentLocation == AppConstants.routeBuyerDeals ||
              currentLocation == AppConstants.routeRateFarmer;

      // 1. Unauthenticated users cannot access protected routes
      if (!isAuthenticated) {
        if (isFarmerRoute ||
            isBuyerRoute ||
            currentLocation == AppConstants.routeOtpVerification ||
            currentLocation == AppConstants.routeMarketPrices ||
            currentLocation == AppConstants.routeNotifications) {
          return AppConstants.routeLogin;
        }
        return null;
      }

      // 2. Authenticated users on Auth routes (login/register) get redirected to role dashboard
      if (isAuthRoute) {
        if (userRole == 'BUYER') {
          return AppConstants.routeBuyerDashboard;
        }
        return AppConstants.routeFarmerDashboard;
      }

      // 3. Cross-role route protection (Farmer accessing Buyer routes)
      if (userRole == 'FARMER' && isBuyerRoute) {
        return AppConstants.routeFarmerDashboard;
      }

      // 4. Cross-role route protection (Buyer accessing Farmer routes)
      if (userRole == 'BUYER' && isFarmerRoute) {
        return AppConstants.routeBuyerDashboard;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppConstants.routeLogin,
        builder: (BuildContext context, GoRouterState state) {
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: AppConstants.routeRegister,
        builder: (BuildContext context, GoRouterState state) {
          return const RegisterScreen();
        },
      ),
      GoRoute(
        path: AppConstants.routeOtpVerification,
        builder: (BuildContext context, GoRouterState state) {
          return const OtpVerificationScreen();
        },
      ),
      GoRoute(
        path: AppConstants.routeFarmerVerification,
        builder: (BuildContext context, GoRouterState state) {
          return const FarmerVerificationScreen();
        },
      ),
      GoRoute(
        path: AppConstants.routeBuyerVerification,
        builder: (BuildContext context, GoRouterState state) {
          return const BuyerVerificationScreen();
        },
      ),
      GoRoute(
        path: AppConstants.routeFarmerDashboard,
        builder: (BuildContext context, GoRouterState state) {
          return const FarmerDashboardScreen();
        },
      ),
      GoRoute(
        path: AppConstants.routeFarmerProfile,
        builder: (BuildContext context, GoRouterState state) {
          return const FarmerProfileScreen();
        },
      ),
      GoRoute(
        path: AppConstants.routeMyCrops,
        builder: (BuildContext context, GoRouterState state) {
          return const MyCropsScreen();
        },
      ),
      GoRoute(
        path: AppConstants.routeAddCrop,
        builder: (BuildContext context, GoRouterState state) {
          return const AddCropScreen();
        },
      ),
      GoRoute(
        path: AppConstants.routeEditCrop,
        builder: (BuildContext context, GoRouterState state) {
          final crop = state.extra as CropModel?;
          return AddCropScreen(initialCrop: crop);
        },
      ),
      GoRoute(
        path: AppConstants.routeCropDetail,
        builder: (BuildContext context, GoRouterState state) {
          final crop = state.extra as CropModel;
          return CropDetailScreen(crop: crop);
        },
      ),
      GoRoute(
        path: AppConstants.routeFarmerRecommendations,
        builder: (BuildContext context, GoRouterState state) {
          final cropId = state.extra as String?;
          return FarmerRecommendationsScreen(initialCropId: cropId);
        },
      ),
      GoRoute(
        path: AppConstants.routeMarketPrices,
        builder: (BuildContext context, GoRouterState state) {
          return const MarketPricesScreen();
        },
      ),
      GoRoute(
        path: AppConstants.routeFarmerOpportunities,
        builder: (BuildContext context, GoRouterState state) {
          return const FarmerOpportunitiesScreen();
        },
      ),
      GoRoute(
        path: AppConstants.routeOpportunityDetail,
        builder: (BuildContext context, GoRouterState state) {
          final opId = state.extra as String;
          return OpportunityDetailScreen(opportunityId: opId);
        },
      ),
      GoRoute(
        path: AppConstants.routeFarmerDeals,
        builder: (BuildContext context, GoRouterState state) {
          return const FarmerDealsScreen();
        },
      ),
      GoRoute(
        path: AppConstants.routeDealDetail,
        builder: (BuildContext context, GoRouterState state) {
          final dealId = state.extra as String;
          return DealDetailScreen(dealId: dealId);
        },
      ),
      GoRoute(
        path: AppConstants.routeDealAgreement,
        builder: (BuildContext context, GoRouterState state) {
          final dealId = state.extra as String;
          return DealAgreementScreen(dealId: dealId);
        },
      ),
      GoRoute(
        path: AppConstants.routeRateBuyer,
        builder: (BuildContext context, GoRouterState state) {
          final opId = state.extra as String;
          return RateBuyerScreen(opportunityId: opId);
        },
      ),
      GoRoute(
        path: AppConstants.routeNotifications,
        builder: (BuildContext context, GoRouterState state) {
          return const FarmerNotificationsScreen();
        },
      ),
      GoRoute(
        path: AppConstants.routeBuyerDashboard,
        builder: (BuildContext context, GoRouterState state) {
          return const BuyerDashboardScreen();
        },
      ),
      GoRoute(
        path: AppConstants.routeBuyerDeals,
        builder: (BuildContext context, GoRouterState state) {
          return const BuyerDealsScreen();
        },
      ),
      GoRoute(
        path: AppConstants.routeBuyerRequirements,
        builder: (BuildContext context, GoRouterState state) {
          return const BuyerRequirementsScreen();
        },
      ),
      GoRoute(
        path: AppConstants.routeCreateRequirement,
        builder: (BuildContext context, GoRouterState state) {
          return const AddRequirementScreen();
        },
      ),
      GoRoute(
        path: AppConstants.routeEditRequirement,
        builder: (BuildContext context, GoRouterState state) {
          final req = state.extra as BuyerRequirementModel?;
          return AddRequirementScreen(initialRequirement: req);
        },
      ),
      GoRoute(
        path: AppConstants.routeRequirementDetail,
        builder: (BuildContext context, GoRouterState state) {
          final req = state.extra as BuyerRequirementModel;
          return RequirementDetailScreen(requirement: req);
        },
      ),
      GoRoute(
        path: AppConstants.routeBuyerOpportunities,
        builder: (BuildContext context, GoRouterState state) {
          return const BuyerOpportunitiesScreen();
        },
      ),
      GoRoute(
        path: AppConstants.routeFarmerMatches,
        builder: (BuildContext context, GoRouterState state) {
          final cropId = state.extra as String?;
          return FarmerMatchesScreen(cropId: cropId);
        },
      ),
      GoRoute(
        path: AppConstants.routeMapDiscovery,
        builder: (BuildContext context, GoRouterState state) {
          final role =
              (state.extra as String?) ?? authProvider.userRole ?? 'FARMER';
          return MapDiscoveryScreen(userRole: role);
        },
      ),
      GoRoute(
        path: AppConstants.routeBuyerMatches,
        builder: (BuildContext context, GoRouterState state) {
          final reqId = state.extra as String?;
          return BuyerMatchesScreen(requirementId: reqId);
        },
      ),
      GoRoute(
        path: AppConstants.routeBuyerProfile,
        builder: (BuildContext context, GoRouterState state) {
          return const BuyerProfileScreen();
        },
      ),
    ],
  );
}
