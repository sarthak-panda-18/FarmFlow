import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

enum LocationPermissionState {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  error,
}

class LocationResult {
  final LocationPermissionState state;
  final Position? position;
  final String? errorMessage;

  LocationResult({
    required this.state,
    this.position,
    this.errorMessage,
  });

  bool get isSuccess =>
      state == LocationPermissionState.granted && position != null;
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Checks device location permission and service status
  Future<LocationPermissionState> checkStatus() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionState.serviceDisabled;
      }

      final permission = await Geolocator.checkPermission();
      switch (permission) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          return LocationPermissionState.granted;
        case LocationPermission.deniedForever:
          return LocationPermissionState.deniedForever;
        case LocationPermission.denied:
        case LocationPermission.unableToDetermine:
          return LocationPermissionState.denied;
      }
    } catch (e) {
      debugPrint('[LocationService] checkStatus error: $e');
      return LocationPermissionState.error;
    }
  }

  /// Requests location permission from user and fetches current GPS position
  Future<LocationResult> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          state: LocationPermissionState.serviceDisabled,
          errorMessage:
              'Location services are disabled on your device. Please turn on GPS.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            state: LocationPermissionState.denied,
            errorMessage:
                'Location permission is required to show nearby farmers, buyers, and markets.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          state: LocationPermissionState.deniedForever,
          errorMessage:
              'Location permission is permanently denied. Please enable location permissions in device Settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      return LocationResult(
        state: LocationPermissionState.granted,
        position: position,
      );
    } catch (e) {
      debugPrint('[LocationService] getCurrentPosition error: $e');
      return LocationResult(
        state: LocationPermissionState.error,
        errorMessage:
            'Unable to obtain GPS coordinates: ${e.toString().replaceAll("Exception: ", "")}',
      );
    }
  }

  /// Validates whether an address string is genuinely valid and meaningful.
  /// Returns false for empty strings, strings containing only punctuation (e.g. ",", ", "),
  /// or generic placeholder phrases.
  static bool isValidAddress(String? address) {
    if (address == null) return false;
    final clean = address.trim();
    if (clean.isEmpty) return false;

    // Strip all punctuation, commas, whitespace, dashes, slashes
    final stripped = clean.replaceAll(RegExp(r'[\s,;:\-_/.]+'), '');
    if (stripped.isEmpty) return false;

    final lower = clean.toLowerCase();
    const invalidPlaceholders = [
      'not specified',
      'location not available',
      'address not available',
      'no address',
      'unknown',
      'null',
      'undefined',
      'n/a',
      'none',
    ];

    if (invalidPlaceholders.contains(lower)) {
      return false;
    }

    return true;
  }

  /// Cleans leading/trailing punctuation and formatting
  static String sanitizeAddress(String? address) {
    if (!isValidAddress(address)) return '';
    var clean = address!.trim();
    clean = clean.replaceAll(RegExp(r'^[\s,;:\-_/]+|[\s,;:\-_/]+$'), '').trim();
    clean = clean
        .replaceAll(RegExp(r',\s*,+'), ',')
        .replaceAll(RegExp(r'\s{2,}'), ' ');
    return clean;
  }

  /// Opens location in Google Maps app if installed, falling back to browser if not.
  /// Uses coordinates if available, address if coordinates not available, or pre-constructed mapsUrl.
  static Future<bool> launchGoogleMaps({
    double? latitude,
    double? longitude,
    String? address,
    String? mapsUrl,
    String? label,
  }) async {
    try {
      final bool hasCoords = latitude != null &&
          longitude != null &&
          latitude != 0.0 &&
          longitude != 0.0 &&
          !latitude.isNaN &&
          !longitude.isNaN &&
          latitude >= -90 &&
          latitude <= 90 &&
          longitude >= -180 &&
          longitude <= 180;

      final String cleanAddress = sanitizeAddress(address);
      final bool hasAddress = cleanAddress.isNotEmpty;

      // Validate mapsUrl if provided
      Uri? parsedMapsUri;
      if (mapsUrl != null && mapsUrl.trim().isNotEmpty) {
        final parsed = Uri.tryParse(mapsUrl.trim());
        if (parsed != null) {
          final queryParam = parsed.queryParameters['query'];
          if (queryParam == null || isValidAddress(queryParam)) {
            parsedMapsUri = parsed;
          }
        }
      }

      Uri? geoUri;
      Uri? webUri;

      if (hasCoords) {
        final encodedLabel = (label != null && label.trim().isNotEmpty)
            ? '(${Uri.encodeComponent(label.trim())})'
            : '';
        geoUri = Uri.parse(
            'geo:$latitude,$longitude?q=$latitude,$longitude$encodedLabel');
        webUri = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
      } else if (hasAddress) {
        final encodedQuery = Uri.encodeComponent(cleanAddress);
        geoUri = Uri.parse('geo:0,0?q=$encodedQuery');
        webUri = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$encodedQuery');
      } else if (parsedMapsUri != null) {
        webUri = parsedMapsUri;
        final q = parsedMapsUri.queryParameters['query'];
        if (q != null && isValidAddress(q)) {
          geoUri = Uri.tryParse('geo:0,0?q=${Uri.encodeComponent(q.trim())}');
        }
      }

      if (geoUri == null && webUri == null) {
        debugPrint(
            '[LocationService] launchGoogleMaps: No valid coordinates, address, or URL available');
        return false;
      }

      // 1. Try launching native Maps app with geo: scheme
      if (geoUri != null) {
        try {
          if (await canLaunchUrl(geoUri)) {
            final launched =
                await launchUrl(geoUri, mode: LaunchMode.externalApplication);
            if (launched) return true;
          }
        } catch (e) {
          debugPrint('[LocationService] geo URI launch exception: $e');
        }
      }

      // 2. Try launching Google Maps Web URL with external application mode
      if (webUri != null) {
        try {
          if (await canLaunchUrl(webUri)) {
            final launched =
                await launchUrl(webUri, mode: LaunchMode.externalApplication);
            if (launched) return true;
          }
        } catch (e) {
          debugPrint(
              '[LocationService] webUri externalApplication exception: $e');
        }

        // 3. Fallback: Launch in device platform default browser
        try {
          final launched =
              await launchUrl(webUri, mode: LaunchMode.platformDefault);
          if (launched) return true;
        } catch (e) {
          debugPrint('[LocationService] webUri platformDefault exception: $e');
        }

        // 4. Fallback: Launch in inAppBrowserView
        try {
          final launched =
              await launchUrl(webUri, mode: LaunchMode.inAppBrowserView);
          if (launched) return true;
        } catch (e) {
          debugPrint('[LocationService] webUri inAppBrowserView exception: $e');
        }
      }

      return false;
    } catch (e) {
      debugPrint('[LocationService] launchGoogleMaps error: $e');
      return false;
    }
  }

  /// Instance method proxy for backwards compatibility
  Future<bool> openGoogleMaps({
    double? latitude,
    double? longitude,
    String? address,
    String? mapsUrl,
    String? label,
  }) async {
    return launchGoogleMaps(
      latitude: latitude,
      longitude: longitude,
      address: address,
      mapsUrl: mapsUrl,
      label: label,
    );
  }

  /// Opens device location settings
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Opens device location service settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }
}
