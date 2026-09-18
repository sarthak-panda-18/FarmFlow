import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FarmerProvider extends ChangeNotifier {
  final ApiService _apiService;

  bool _isLoading = false;
  final List<dynamic> _crops = [];
  final List<dynamic> _recommendations = [];

  FarmerProvider({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  ApiService get apiService => _apiService;

  bool get isLoading => _isLoading;
  List<dynamic> get crops => List.unmodifiable(_crops);
  List<dynamic> get recommendations => List.unmodifiable(_recommendations);

  /// Phase 1 state initialization foundation
  Future<void> fetchCrops() async {
    _isLoading = true;
    notifyListeners();

    // Phase 1 placeholder
    await Future.delayed(const Duration(milliseconds: 300));
    _isLoading = false;
    notifyListeners();
  }
}
