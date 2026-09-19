import '../models/deal_model.dart';
import 'api_service.dart';

class DealService {
  final ApiService _apiService;

  DealService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  Future<List<DealModel>> getFarmerDeals({String? status}) async {
    try {
      final res = await _apiService.getFarmerDeals(status: status);
      if (res.data != null && res.data['success'] == true) {
        final List list = res.data['data'] ?? res.data['deals'] ?? [];
        return list.map((item) => DealModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<List<DealModel>> getBuyerDeals({String? status}) async {
    try {
      final res = await _apiService.getBuyerDeals(status: status);
      if (res.data != null && res.data['success'] == true) {
        final List list = res.data['data'] ?? res.data['deals'] ?? [];
        return list.map((item) => DealModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<DealModel> getDealById(String id) async {
    try {
      final cleanId = id.trim();
      if (cleanId.isEmpty) {
        throw Exception('Invalid or missing deal ID.');
      }
      final res = await _apiService.getDealById(cleanId);
      if (res.data != null && res.data['success'] == true) {
        final dealData = res.data['data'] ?? res.data['deal'];
        if (dealData != null && dealData is Map<String, dynamic>) {
          return DealModel.fromJson(dealData);
        }
      }
      throw Exception(res.data?['message'] ?? 'Deal not found.');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDealAgreement(String id) async {
    try {
      final cleanId = id.trim();
      if (cleanId.isEmpty) {
        throw Exception('Invalid or missing deal ID.');
      }
      final res = await _apiService.getDealAgreement(cleanId);
      if (res.data != null && res.data['success'] == true) {
        final data = res.data['data'] ?? res.data['deal'];
        if (data != null && data is Map<String, dynamic>) {
          return Map<String, dynamic>.from(data);
        }
      }
      throw Exception(res.data?['message'] ?? 'Unable to load deal agreement.');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> acceptDealAgreement(String id,
      {required bool agreeToTerms, int? agreementVersion}) async {
    try {
      final cleanId = id.trim();
      if (cleanId.isEmpty) {
        throw Exception('Invalid or missing deal ID.');
      }
      final res = await _apiService.acceptDealAgreement(cleanId,
          agreeToTerms: agreeToTerms, agreementVersion: agreementVersion);
      if (res.data != null && res.data['success'] == true) {
        return Map<String, dynamic>.from(
            res.data['data'] ?? res.data['deal'] ?? {});
      }
      throw Exception(res.data?['message'] ?? 'Failed to accept agreement.');
    } catch (e) {
      rethrow;
    }
  }

  Future<DealModel> updateDealAgreement(
      String id, Map<String, dynamic> data) async {
    try {
      final cleanId = id.trim();
      final res = await _apiService.updateDealAgreement(cleanId, data);
      if (res.data != null && res.data['success'] == true) {
        final dealData = res.data['data'] ?? res.data['deal'];
        if (dealData != null && dealData is Map<String, dynamic>) {
          return DealModel.fromJson(dealData);
        }
      }
      throw Exception(res.data?['message'] ?? 'Failed to update agreement.');
    } catch (e) {
      rethrow;
    }
  }

  Future<DealModel> updateDealStatus(String id, String status,
      {String? notes}) async {
    try {
      final cleanId = id.trim();
      final res =
          await _apiService.updateDealStatus(cleanId, status, notes: notes);
      if (res.data != null && res.data['success'] == true) {
        final dealData = res.data['data'] ?? res.data['deal'];
        if (dealData != null && dealData is Map<String, dynamic>) {
          return DealModel.fromJson(dealData);
        }
      }
      throw Exception(res.data?['message'] ?? 'Failed to update deal status.');
    } catch (e) {
      rethrow;
    }
  }

  Future<DealModel> updateDealLogistics(
    String id, {
    Map<String, dynamic>? pickupLocation,
    Map<String, dynamic>? deliveryLocation,
    bool? transportRequired,
    String? transportType,
    double? transportCost,
    double? otherCosts,
  }) async {
    try {
      final cleanId = id.trim();
      final res = await _apiService.updateDealLogistics(
        cleanId,
        pickupLocation: pickupLocation,
        deliveryLocation: deliveryLocation,
        transportRequired: transportRequired,
        transportType: transportType,
        transportCost: transportCost,
        otherCosts: otherCosts,
      );
      if (res.data != null && res.data['success'] == true) {
        final dealData = res.data['data'] ?? res.data['deal'];
        if (dealData != null && dealData is Map<String, dynamic>) {
          return DealModel.fromJson(dealData);
        }
      }
      throw Exception(res.data?['message'] ?? 'Failed to update logistics.');
    } catch (e) {
      rethrow;
    }
  }

  Future<DealModel> markDealDelivered(String id, {String? notes}) async {
    try {
      final cleanId = id.trim();
      final res = await _apiService.markDealDelivered(cleanId, notes: notes);
      if (res.data != null && res.data['success'] == true) {
        final dealData = res.data['data'] ?? res.data['deal'];
        if (dealData != null && dealData is Map<String, dynamic>) {
          return DealModel.fromJson(dealData);
        }
      }
      throw Exception(
          res.data?['message'] ?? 'Failed to mark deal as delivered.');
    } catch (e) {
      rethrow;
    }
  }

  Future<DealModel> cancelDeal(String id, {required String reason}) async {
    try {
      final cleanId = id.trim();
      final res = await _apiService.cancelDeal(cleanId, reason: reason);
      if (res.data != null && res.data['success'] == true) {
        final dealData = res.data['data'] ?? res.data['deal'];
        if (dealData != null && dealData is Map<String, dynamic>) {
          return DealModel.fromJson(dealData);
        }
      }
      throw Exception(res.data?['message'] ?? 'Failed to cancel deal.');
    } catch (e) {
      rethrow;
    }
  }

  Future<DealModel> reportPaymentMade(String id,
      {String? notes, String? paymentMethod}) async {
    try {
      final cleanId = id.trim();
      final res = await _apiService.reportPaymentMade(cleanId,
          notes: notes, paymentMethod: paymentMethod);
      if (res.data != null && res.data['success'] == true) {
        final dealData = res.data['data'] ?? res.data['deal'];
        if (dealData != null && dealData is Map<String, dynamic>) {
          return DealModel.fromJson(dealData);
        }
      }
      throw Exception(res.data?['message'] ?? 'Failed to report payment.');
    } catch (e) {
      rethrow;
    }
  }

  Future<DealModel> confirmPaymentReceived(String id, {String? notes}) async {
    try {
      final cleanId = id.trim();
      final res =
          await _apiService.confirmPaymentReceived(cleanId, notes: notes);
      if (res.data != null && res.data['success'] == true) {
        final dealData = res.data['data'] ?? res.data['deal'];
        if (dealData != null && dealData is Map<String, dynamic>) {
          return DealModel.fromJson(dealData);
        }
      }
      throw Exception(res.data?['message'] ?? 'Failed to confirm payment.');
    } catch (e) {
      rethrow;
    }
  }

  Future<DealModel> disputePayment(String id, {required String reason}) async {
    try {
      final cleanId = id.trim();
      final res = await _apiService.disputePayment(cleanId, reason: reason);
      if (res.data != null && res.data['success'] == true) {
        final dealData = res.data['data'] ?? res.data['deal'];
        if (dealData != null && dealData is Map<String, dynamic>) {
          return DealModel.fromJson(dealData);
        }
      }
      throw Exception(res.data?['message'] ?? 'Failed to dispute payment.');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> rateDeal(
    String id, {
    required double rating,
    String? feedback,
    Map<String, dynamic>? categoryRatings,
  }) async {
    try {
      final cleanId = id.trim();
      final res = await _apiService.rateDeal(
        cleanId,
        rating: rating,
        feedback: feedback,
        categoryRatings: categoryRatings,
      );
      if (res.data != null && res.data['success'] == true) {
        return;
      }
      throw Exception(res.data?['message'] ?? 'Failed to submit rating.');
    } catch (e) {
      rethrow;
    }
  }
}
