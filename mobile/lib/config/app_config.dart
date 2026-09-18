/// Centralized Application Configuration
class AppConfig {
  static const String appName = 'Farm-to-Market';
  static const String appVersion = '1.0.0';

  // Base API configuration (Can be overridden by environment)
  // Connects via localhost/127.0.0.1 with adb reverse tcp:5000 tcp:5000 on physical device or emulator
  static const String _defaultBaseUrl = 'http://127.0.0.1:5000/api';

  static String get apiBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    return _defaultBaseUrl;
  }

  static const int apiTimeoutSeconds = 15;
}
