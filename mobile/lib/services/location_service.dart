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

  bool get isSuccess => state == LocationPermissionState.granted && position != null;
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
          errorMessage: 'Location services are disabled on your device. Please turn on GPS.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            state: LocationPermissionState.denied,
            errorMessage: 'Location permission is required to show nearby farmers, buyers, and markets.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          state: LocationPermissionState.deniedForever,
          errorMessage: 'Location permission is permanently denied. Please enable location permissions in device Settings.',
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
        errorMessage: 'Unable to obtain GPS coordinates: ${e.toString().replaceAll("Exception: ", "")}',
      );
    }
  }

  /// Opens the destination coordinates in Google Maps (deep link with web fallback)
  Future<bool> openGoogleMaps({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    try {
      final encodedLabel = label != null ? Uri.encodeComponent(label) : '';
      
      // 1. Google Maps Universal Search URL
      final Uri webUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude${encodedLabel.isNotEmpty ? '($encodedLabel)' : ''}',
      );

      // 2. Native Maps geo URI
      final Uri geoUrl = Uri.parse(
        'geo:$latitude,$longitude?q=$latitude,$longitude${encodedLabel.isNotEmpty ? '($encodedLabel)' : ''}',
      );

      // Attempt native geo URI first
      if (await canLaunchUrl(geoUrl)) {
        return await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
      }

      // Fallback to Google Maps Web URL
      if (await canLaunchUrl(webUrl)) {
        return await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }

      // Final fallback: launch in platform default browser
      return await launchUrl(webUrl, mode: LaunchMode.platformDefault);
    } catch (e) {
      debugPrint('[LocationService] openGoogleMaps error: $e');
      return false;
    }
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
