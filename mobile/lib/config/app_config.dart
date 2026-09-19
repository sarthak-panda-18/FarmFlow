import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Centralized Application Configuration
class AppConfig {
  static const String appName = 'Farm-to-Market';
  static const String appVersion = '1.0.0';

  // Base API configuration (Can be overridden by environment)
  // Connects via 10.0.2.2 on Android Emulator (points to host machine localhost:5000)
  // Connects via 127.0.0.1 on Web, Desktop, iOS Simulator, or when adb reverse is used
  static String get apiBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:5000/api';
    }
    return 'http://127.0.0.1:5000/api';
  }

  static const int apiTimeoutSeconds = 15;
}

