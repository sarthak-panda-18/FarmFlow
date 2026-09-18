import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class StorageService {
  final FlutterSecureStorage _storage;

  StorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Save JWT authentication token securely
  Future<void> saveToken(String token) async {
    await _storage.write(key: AppConstants.keyAuthToken, value: token);
  }

  /// Retrieve JWT authentication token
  Future<String?> getToken() async {
    return await _storage.read(key: AppConstants.keyAuthToken);
  }

  /// Delete JWT authentication token
  Future<void> deleteToken() async {
    await _storage.delete(key: AppConstants.keyAuthToken);
  }

  /// Save sanitized user data JSON
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _storage.write(
      key: AppConstants.keyUserData,
      value: jsonEncode(userData),
    );
  }

  /// Retrieve sanitized user data
  Future<Map<String, dynamic>?> getUserData() async {
    final data = await _storage.read(key: AppConstants.keyUserData);
    if (data == null || data.isEmpty) return null;
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Clear all stored credentials and session data
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
