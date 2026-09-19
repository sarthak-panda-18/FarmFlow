/// Centralized Application Configuration
class AppConfig {
  static const String appName = 'Farm-to-Market';
  static const String appVersion = '1.0.0';

  // Preset Connection URLs for convenience
  static const String defaultUsbUrl = 'http://127.0.0.1:5000/api';
  static const String defaultLanUrl = 'http://10.1.36.198:5000/api';
  static const String defaultEmulatorUrl = 'http://10.0.2.2:5000/api';

  // Candidate URLs for auto-discovery probe
  static const List<String> candidateUrls = [
    'http://127.0.0.1:5000/api',
    'http://10.1.36.198:5000/api',
    'http://192.168.137.1:5000/api',
    'http://10.0.2.2:5000/api',
  ];

  static String? _customBaseUrl;

  /// Update base URL dynamically at runtime
  static void setCustomBaseUrl(String? url) {
    if (url != null && url.trim().isNotEmpty) {
      String sanitized = url.trim();
      // Remove trailing slash if present
      if (sanitized.endsWith('/')) {
        sanitized = sanitized.substring(0, sanitized.length - 1);
      }
      // Ensure /api suffix
      if (!sanitized.endsWith('/api')) {
        sanitized = '$sanitized/api';
      }
      _customBaseUrl = sanitized;
    } else {
      _customBaseUrl = null;
    }
  }

  /// Base API configuration (Can be overridden dynamically or via environment)
  /// - If user configured a custom URL, uses that.
  /// - If launched with `--dart-define=API_BASE_URL=...`, uses that.
  /// - Connects via 127.0.0.1:5000 on USB physical device (via adb reverse), Web, Desktop, iOS.
  static String get apiBaseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    return defaultUsbUrl;
  }

  static const int apiTimeoutSeconds = 15;
}
