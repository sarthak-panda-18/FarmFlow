import 'package:flutter/material.dart';
import '../models/buyer_requirement_model.dart';
import '../services/api_service.dart';

class BuyerProvider extends ChangeNotifier {
  final ApiService _apiService;

  bool _isLoading = false;
  String? _errorMessage;
  List<BuyerRequirementModel> _requirements = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalRequirements = 0;

  BuyerProvider({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  ApiService get apiService => _apiService;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<BuyerRequirementModel> get requirements => List.unmodifiable(_requirements);
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalRequirements => _totalRequirements;

  int get activeRequirementsCount =>
      _requirements.where((r) => r.status == 'ACTIVE').length;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchRequirements({
    int page = 1,
    int limit = 20,
    String? status,
    bool refresh = false,
  }) async {
    if (refresh) {
      _currentPage = 1;
      _requirements = [];
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.getMyRequirements(
        page: page,
        limit: limit,
        status: status,
      );

      final data = response.data;
      if (data != null && data['success'] == true) {
        final List<dynamic> list = data['data'] ?? [];
        final fetched = list.map((item) => BuyerRequirementModel.fromJson(item)).toList();

        if (page == 1 || refresh) {
          _requirements = fetched;
        } else {
          _requirements.addAll(fetched);
        }

        _currentPage = data['page'] ?? page;
        _totalPages = data['pages'] ?? 1;
        _totalRequirements = data['total'] ?? _requirements.length;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<BuyerRequirementModel?> createRequirement(Map<String, dynamic> requirementData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.createRequirement(requirementData);
      final data = response.data;

      if (data != null && data['success'] == true) {
        final reqJson = data['data']['requirement'];
        final newReq = BuyerRequirementModel.fromJson(reqJson);
        _requirements.insert(0, newReq);
        _totalRequirements += 1;
        _isLoading = false;
        notifyListeners();
        return newReq;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }

  Future<BuyerRequirementModel?> updateRequirement(String id, Map<String, dynamic> requirementData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.updateRequirement(id, requirementData);
      final data = response.data;

      if (data != null && data['success'] == true) {
        final reqJson = data['data']['requirement'];
        final updatedReq = BuyerRequirementModel.fromJson(reqJson);

        final index = _requirements.indexWhere((r) => r.id == id);
        if (index != -1) {
          _requirements[index] = updatedReq;
        }
        _isLoading = false;
        notifyListeners();
        return updatedReq;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }

  Future<bool> cancelRequirement(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.cancelRequirement(id);
      final data = response.data;

      if (data != null && data['success'] == true) {
        final reqJson = data['data']['requirement'];
        if (reqJson != null) {
          final updatedReq = BuyerRequirementModel.fromJson(reqJson);
          final index = _requirements.indexWhere((r) => r.id == id);
          if (index != -1) {
            _requirements[index] = updatedReq;
          }
        } else {
          final index = _requirements.indexWhere((r) => r.id == id);
          if (index != -1) {
            final old = _requirements[index];
            _requirements[index] = BuyerRequirementModel(
              id: old.id,
              buyerId: old.buyerId,
              commodity: old.commodity,
              cropName: old.cropName,
              variety: old.variety,
              grade: old.grade,
              quantity: old.quantity,
              quantityUnit: old.quantityUnit,
              offeredPrice: old.offeredPrice,
              requiredByDate: old.requiredByDate,
              state: old.state,
              district: old.district,
              market: old.market,
              location: old.location,
              notes: old.notes,
              status: 'CANCELLED',
              createdAt: old.createdAt,
              updatedAt: DateTime.now(),
            );
          }
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> deleteRequirement(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.deleteRequirement(id);
      final data = response.data;

      if (data != null && data['success'] == true) {
        _requirements.removeWhere((r) => r.id == id);
        _totalRequirements = _totalRequirements > 0 ? _totalRequirements - 1 : 0;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }
}
