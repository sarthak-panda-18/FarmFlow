import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

enum AuthStatus {
  unauthenticated,
  authenticated,
  loading,
}

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storageService;

  AuthStatus _status = AuthStatus.unauthenticated;
  String? _token;
  Map<String, dynamic>? _user;
  String? _errorMessage;

  AuthProvider({
    ApiService? apiService,
    StorageService? storageService,
  })  : _apiService = apiService ?? ApiService(),
        _storageService = storageService ?? StorageService();

  AuthStatus get status => _status;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _token != null;
  Map<String, dynamic>? get user => _user;
  String? get userId => _user?['id'] ?? _user?['_id'];
  String? get userName => _user?['name'];
  String? get userEmail => _user?['email'];
  String? get userPhone => _user?['phone'];
  String? get userRole => _user?['role'];
  String? get userGstin => _user?['gstin'];
  String? get errorMessage => _errorMessage;

  bool get isPhoneVerified => _user?['phoneVerified'] == true;
  String get verificationStatus => _user?['verificationStatus'] ?? 'PENDING';
  String get verificationType => _user?['verificationType'] ?? 'NONE';
  String? get verificationId => _user?['verificationId'];
  String? get businessName => _user?['businessName'];
  String? get businessType => _user?['businessType'];

  bool get isFullyVerified => isPhoneVerified && verificationStatus == 'VERIFIED';
  bool get isVerificationPending => isPhoneVerified && verificationStatus == 'PENDING';
  bool get isVerificationRejected => verificationStatus == 'REJECTED';

  ApiService get apiService => _apiService;
  StorageService get storageService => _storageService;

  /// Session restoration on application startup
  Future<void> initAuth() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final token = await _storageService.getToken();
      final userData = await _storageService.getUserData();

      if (token != null && token.isNotEmpty && userData != null) {
        _token = token;
        _user = userData;
        _status = AuthStatus.authenticated;
        notifyListeners();

        // Refresh user profile from backend
        try {
          await refreshUserProfile();
        } catch (_) {
          // Keep cached session if offline/unreachable
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
    } finally {
      notifyListeners();
    }
  }

  /// Refresh latest user profile from server
  Future<void> refreshUserProfile() async {
    try {
      final res = await _apiService.getCurrentUser();
      if (res.data != null && res.data['success'] == true) {
        _user = res.data['data']['user'];
        await _storageService.saveUserData(_user!);
        notifyListeners();
      }
    } catch (_) {
      // Ignore if offline
    }
  }

  /// Login with email or phone number
  Future<String> login(String identifier, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.login(identifier.trim(), password.trim());
      final data = response.data['data'];

      _token = data['token'];
      _user = data['user'];
      final role = _user?['role'] ?? 'FARMER';

      await _storageService.saveToken(_token!);
      await _storageService.saveUserData(_user!);

      _status = AuthStatus.authenticated;
      notifyListeners();
      return role;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  /// Registration method submitting selected role (FARMER or BUYER)
  Future<String> register({
    required String name,
    String? email,
    required String phone,
    required String password,
    required String role,
    String? farmerId,
    String? gstin,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
        role: role,
        farmerId: farmerId,
        gstin: gstin,
      );

      final data = response.data['data'];

      _token = data['token'];
      _user = data['user'];
      final assignedRole = _user?['role'] ?? role;

      await _storageService.saveToken(_token!);
      await _storageService.saveUserData(_user!);

      _status = AuthStatus.authenticated;
      notifyListeners();
      return assignedRole;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  /// Request OTP
  Future<Map<String, dynamic>> sendOtp([String? phone]) async {
    final targetPhone = phone ?? userPhone;
    if (targetPhone == null || targetPhone.isEmpty) {
      throw Exception('Phone number required');
    }
    final res = await _apiService.sendOtp(targetPhone);
    return res.data['data'];
  }

  /// Verify OTP
  Future<void> verifyOtp(String otp, [String? phone]) async {
    final targetPhone = phone ?? userPhone;
    if (targetPhone == null || targetPhone.isEmpty) {
      throw Exception('Phone number required');
    }

    _errorMessage = null;
    final res = await _apiService.verifyOtp(targetPhone, otp);
    if (res.data != null && res.data['success'] == true) {
      if (res.data['data']['user'] != null) {
        _user = res.data['data']['user'];
        await _storageService.saveUserData(_user!);
      } else if (_user != null) {
        _user!['phoneVerified'] = true;
        await _storageService.saveUserData(_user!);
      }
      notifyListeners();
    }
  }

  /// Submit Farmer verification details
  Future<void> submitFarmerVerification(String farmerId, {String? supportingDocument}) async {
    _errorMessage = null;
    final res = await _apiService.submitFarmerVerification(farmerId, supportingDocument: supportingDocument);
    if (res.data != null && res.data['success'] == true) {
      await refreshUserProfile();
    }
  }

  /// Submit Buyer verification details
  Future<void> submitBuyerVerification({
    required String businessName,
    required String businessType,
    required String registrationIdentifier,
    String? supportingDocument,
  }) async {
    _errorMessage = null;
    final res = await _apiService.submitBuyerVerification(
      businessName: businessName,
      businessType: businessType,
      registrationIdentifier: registrationIdentifier,
      supportingDocument: supportingDocument,
    );
    if (res.data != null && res.data['success'] == true) {
      await refreshUserProfile();
    }
  }

  /// Session logout - clears stored tokens and resets state
  Future<void> logout() async {
    await _storageService.clearAll();
    _token = null;
    _user = null;
    _errorMessage = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
