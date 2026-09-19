import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'constants/app_colors.dart';
import 'navigation/app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/farmer_provider.dart';
import 'providers/buyer_provider.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize service dependencies
  final storageService = StorageService();

  // Load custom server URL if previously configured by user
  try {
    final savedServerUrl = await storageService.getServerUrl();
    if (savedServerUrl != null && savedServerUrl.isNotEmpty) {
      AppConfig.setCustomBaseUrl(savedServerUrl);
    }
  } catch (_) {
    // Fall back to default
  }

  final apiService = ApiService(storageService: storageService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            apiService: apiService,
            storageService: storageService,
          )..initAuth(),
        ),
        ChangeNotifierProvider(
          create: (_) => FarmerProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => BuyerProvider(apiService: apiService),
        ),
      ],
      child: const FarmToMarketApp(),
    ),
  );
}

class FarmToMarketApp extends StatefulWidget {
  const FarmToMarketApp({super.key});

  @override
  State<FarmToMarketApp> createState() => _FarmToMarketAppState();
}

class _FarmToMarketAppState extends State<FarmToMarketApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _router = createRouter(authProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}
