import 'package:flutter_test/flutter_test.dart';
import 'package:farm_to_market/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationService Address Validation Tests', () {
    test('isValidAddress rejects empty, whitespace, and comma-only strings', () {
      expect(LocationService.isValidAddress(''), isFalse);
      expect(LocationService.isValidAddress('   '), isFalse);
      expect(LocationService.isValidAddress(','), isFalse);
      expect(LocationService.isValidAddress(', '), isFalse);
      expect(LocationService.isValidAddress(' , , '), isFalse);
      expect(LocationService.isValidAddress(' ; - / '), isFalse);
    });

    test('isValidAddress rejects placeholder phrases', () {
      expect(LocationService.isValidAddress('not specified'), isFalse);
      expect(LocationService.isValidAddress('Location Not Available'), isFalse);
      expect(LocationService.isValidAddress('address not available'), isFalse);
      expect(LocationService.isValidAddress('null'), isFalse);
      expect(LocationService.isValidAddress('undefined'), isFalse);
      expect(LocationService.isValidAddress('N/A'), isFalse);
    });

    test('isValidAddress accepts genuine locations', () {
      expect(LocationService.isValidAddress('Nashik, Maharashtra'), isTrue);
      expect(LocationService.isValidAddress('APMC Market, Pune'), isTrue);
      expect(LocationService.isValidAddress('Pimpalgaon Farm Yard'), isTrue);
    });

    test('sanitizeAddress cleans leading/trailing punctuation and internal commas', () {
      expect(LocationService.sanitizeAddress(', Nashik, Maharashtra, '), equals('Nashik, Maharashtra'));
      expect(LocationService.sanitizeAddress(' , , '), equals(''));
      expect(LocationService.sanitizeAddress('Pimpalgaon, , Nashik'), equals('Pimpalgaon, Nashik'));
    });
  });

  group('LocationService Google Maps Launcher Tests', () {
    test('launchGoogleMaps returns false when no parameters are provided', () async {
      final result = await LocationService.launchGoogleMaps();
      expect(result, isFalse);
    });

    test('launchGoogleMaps handles empty address and null coordinates gracefully', () async {
      final result = await LocationService.launchGoogleMaps(
        latitude: null,
        longitude: null,
        address: '   ',
        mapsUrl: null,
      );
      expect(result, isFalse);
    });

    test('launchGoogleMaps rejects comma-only address and prevents "," query launch', () async {
      final result = await LocationService.launchGoogleMaps(
        address: ', ',
      );
      expect(result, isFalse);
    });

    test('launchGoogleMaps rejects query=, mapsUrl gracefully', () async {
      final result = await LocationService.launchGoogleMaps(
        mapsUrl: 'https://www.google.com/maps/search/?api=1&query=,',
      );
      expect(result, isFalse);
    });

    test('launchGoogleMaps handles "not specified" address gracefully', () async {
      final result = await LocationService.launchGoogleMaps(
        address: 'Address not specified',
      );
      expect(result, isFalse);
    });

    test('LocationService instance method calls launchGoogleMaps', () async {
      final service = LocationService();
      final result = await service.openGoogleMaps();
      expect(result, isFalse);
    });
  });
}
