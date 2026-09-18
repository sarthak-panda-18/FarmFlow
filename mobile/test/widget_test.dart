import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:farm_to_market/main.dart';
import 'package:farm_to_market/providers/auth_provider.dart';
import 'package:farm_to_market/providers/farmer_provider.dart';
import 'package:farm_to_market/providers/buyer_provider.dart';
import 'package:farm_to_market/services/api_service.dart';
import 'package:farm_to_market/services/storage_service.dart';

void main() {
  testWidgets('App initializes successfully smoke test', (WidgetTester tester) async {
    final storageService = StorageService();
    final apiService = ApiService(storageService: storageService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider(
              apiService: apiService,
              storageService: storageService,
            ),
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

    expect(find.byType(FarmToMarketApp), findsOneWidget);
  });
}
