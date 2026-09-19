import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'storage_service.dart';

class ApiService {
  late final Dio _dio;
  final StorageService _storageService;

  ApiService({StorageService? storageService, Dio? dio})
      : _storageService = storageService ?? StorageService() {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: AppConfig.apiTimeoutSeconds),
            receiveTimeout: const Duration(seconds: AppConfig.apiTimeoutSeconds),
            sendTimeout: const Duration(seconds: AppConfig.apiTimeoutSeconds),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storageService.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          return handler.next(error);
        },
      ),
    );
  }

  // Auth APIs
  Future<Response> login(String identifier, String password) async {
    final data = <String, dynamic>{'password': password};
    if (identifier.contains('@')) {
      data['email'] = identifier;
    } else {
      data['phone'] = identifier;
    }
    return await post('/auth/login', data: data);
  }

  Future<Response> register({
    required String name,
    String? email,
    required String phone,
    required String password,
    required String role,
    String? farmerId,
    String? gstin,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'phone': phone,
      'password': password,
      'role': role,
    };
    if (email != null && email.trim().isNotEmpty) {
      data['email'] = email.trim();
    }
    if (farmerId != null && farmerId.trim().isNotEmpty) {
      data['farmerId'] = farmerId.trim();
    }
    if (gstin != null && gstin.trim().isNotEmpty) {
      data['gstin'] = gstin.trim().toUpperCase();
    }
    return await post('/auth/register', data: data);
  }

  Future<Response> getCurrentUser() async {
    return await get('/auth/me');
  }

  // OTP APIs
  Future<Response> sendOtp(String phone) async {
    return await post('/auth/send-otp', data: {'phone': phone});
  }

  Future<Response> verifyOtp(String phone, String otp) async {
    return await post('/auth/verify-otp', data: {'phone': phone, 'otp': otp});
  }

  Future<Response> resendOtp(String phone) async {
    return await post('/auth/resend-otp', data: {'phone': phone});
  }

  // Verification APIs
  Future<Response> submitFarmerVerification(String farmerId, {String? supportingDocument}) async {
    return await post('/verification/farmer', data: {
      'farmerId': farmerId,
      'supportingDocument': supportingDocument ?? '',
    });
  }

  Future<Response> submitBuyerVerification({
    required String businessName,
    required String businessType,
    required String registrationIdentifier,
    String? supportingDocument,
  }) async {
    return await post('/verification/buyer', data: {
      'businessName': businessName,
      'businessType': businessType,
      'registrationIdentifier': registrationIdentifier,
      'supportingDocument': supportingDocument ?? '',
    });
  }

  Future<Response> getVerificationStatus() async {
    return await get('/verification/status');
  }

  // Farmer Crop Management APIs
  Future<Response> createCrop(Map<String, dynamic> cropData) async {
    return await post('/crops', data: cropData);
  }

  Future<Response> getMyCrops({int page = 1, int limit = 20, String? status}) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null && status.isNotEmpty) params['status'] = status;
    return await get('/crops/my', queryParameters: params);
  }

  Future<Response> getCropById(String id) async {
    return await get('/crops/$id');
  }

  Future<Response> updateCrop(String id, Map<String, dynamic> cropData) async {
    return await put('/crops/$id', data: cropData);
  }

  Future<Response> deleteCrop(String id) async {
    return await delete('/crops/$id');
  }

  // Buyer Requirement Management APIs
  Future<Response> createRequirement(Map<String, dynamic> requirementData) async {
    return await post('/requirements', data: requirementData);
  }

  Future<Response> getMyRequirements({int page = 1, int limit = 20, String? status}) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null && status.isNotEmpty) params['status'] = status;
    return await get('/requirements/my', queryParameters: params);
  }

  Future<Response> getRequirementById(String id) async {
    return await get('/requirements/$id');
  }

  Future<Response> updateRequirement(String id, Map<String, dynamic> requirementData) async {
    return await put('/requirements/$id', data: requirementData);
  }

  Future<Response> deleteRequirement(String id) async {
    return await delete('/requirements/$id');
  }

  Future<Response> cancelRequirement(String id) async {
    return await patch('/requirements/$id/cancel');
  }

  // Commodity Catalog APIs
  Future<Response> getCommodities() async {
    return await get('/commodities');
  }

  Future<Response> getCategories() async {
    return await get('/commodities/categories');
  }

  Future<Response> getStates() async {
    return await get('/commodities/states');
  }

  Future<Response> getDistricts({String? state}) async {
    final params = <String, dynamic>{};
    if (state != null && state.isNotEmpty) params['state'] = state;
    return await get('/commodities/districts', queryParameters: params);
  }

  Future<Response> getMarkets({String? state, String? district}) async {
    final params = <String, dynamic>{};
    if (state != null && state.isNotEmpty) params['state'] = state;
    if (district != null && district.isNotEmpty) params['district'] = district;
    return await get('/commodities/markets', queryParameters: params);
  }

  Future<Response> getVarieties({String? commodity}) async {
    final params = <String, dynamic>{};
    if (commodity != null && commodity.isNotEmpty) params['commodity'] = commodity;
    return await get('/commodities/varieties', queryParameters: params);
  }

  Future<Response> getGrades({String? commodity}) async {
    final params = <String, dynamic>{};
    if (commodity != null && commodity.isNotEmpty) params['commodity'] = commodity;
    return await get('/commodities/grades', queryParameters: params);
  }

  // Market Price & Search APIs
  Future<Response> getReferenceMarketPrice({
    required String commodity,
    String? state,
    String? district,
    String? market,
  }) async {
    final params = <String, dynamic>{'commodity': commodity};
    if (state != null && state.isNotEmpty) params['state'] = state;
    if (district != null && district.isNotEmpty) params['district'] = district;
    if (market != null && market.isNotEmpty) params['market'] = market;
    return await get('/markets/reference-price', queryParameters: params);
  }

  Future<Response> getMarketPrices({
    String? commodity,
    String? category,
    String? state,
    String? district,
    String? market,
    String? variety,
    String? grade,
    String? fromDate,
    String? toDate,
    int page = 1,
    int limit = 20,
    String sortBy = 'date',
    String order = 'desc',
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
      'sortBy': sortBy,
      'order': order,
    };
    if (commodity != null && commodity.isNotEmpty) params['commodity'] = commodity;
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (state != null && state.isNotEmpty) params['state'] = state;
    if (district != null && district.isNotEmpty) params['district'] = district;
    if (market != null && market.isNotEmpty) params['market'] = market;
    if (variety != null && variety.isNotEmpty) params['variety'] = variety;
    if (grade != null && grade.isNotEmpty) params['grade'] = grade;
    if (fromDate != null && fromDate.isNotEmpty) params['fromDate'] = fromDate;
    if (toDate != null && toDate.isNotEmpty) params['toDate'] = toDate;

    return await get('/markets/prices', queryParameters: params);
  }

  Future<Response> getMarketPriceHistory({
    required String commodity,
    String? state,
    String? district,
    String? market,
    int limit = 30,
  }) async {
    final params = <String, dynamic>{
      'commodity': commodity,
      'limit': limit,
    };
    if (state != null && state.isNotEmpty) params['state'] = state;
    if (district != null && district.isNotEmpty) params['district'] = district;
    if (market != null && market.isNotEmpty) params['market'] = market;

    return await get('/markets/history', queryParameters: params);
  }

  Future<Response> getCategoryPrices(
    String category, {
    String? state,
    String? district,
  }) async {
    final params = <String, dynamic>{};
    if (state != null && state.isNotEmpty) params['state'] = state;
    if (district != null && district.isNotEmpty) params['district'] = district;

    return await get('/markets/category/$category', queryParameters: params);
  }

  Future<Response> searchMarkets({
    String? q,
    String? commodity,
    String? state,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (q != null && q.isNotEmpty) params['q'] = q;
    if (commodity != null && commodity.isNotEmpty) params['commodity'] = commodity;
    if (state != null && state.isNotEmpty) params['state'] = state;
    return await get('/markets/search', queryParameters: params);
  }

  Future<Response> getMarketStats() async {
    return await get('/markets/stats');
  }

  // Phase 6: Location & GPS APIs
  Future<Response> updateLocation({
    required double latitude,
    required double longitude,
    String? address,
    String? city,
    String? district,
    String? state,
  }) async {
    final data = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
    };
    if (address != null && address.isNotEmpty) data['address'] = address;
    if (city != null && city.isNotEmpty) data['city'] = city;
    if (district != null && district.isNotEmpty) data['district'] = district;
    if (state != null && state.isNotEmpty) data['state'] = state;

    return await put('/location', data: data);
  }

  Future<Response> getMyLocation() async {
    return await get('/location/me');
  }

  Future<Response> getNearbyFarmers({
    double? latitude,
    double? longitude,
    double? maxDistanceKm,
    String? commodity,
    int limit = 30,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (latitude != null) params['latitude'] = latitude;
    if (longitude != null) params['longitude'] = longitude;
    if (maxDistanceKm != null) params['maxDistanceKm'] = maxDistanceKm;
    if (commodity != null && commodity.isNotEmpty) params['commodity'] = commodity;

    return await get('/location/nearby-farmers', queryParameters: params);
  }

  Future<Response> getNearbyBuyers({
    double? latitude,
    double? longitude,
    double? maxDistanceKm,
    String? commodity,
    int limit = 30,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (latitude != null) params['latitude'] = latitude;
    if (longitude != null) params['longitude'] = longitude;
    if (maxDistanceKm != null) params['maxDistanceKm'] = maxDistanceKm;
    if (commodity != null && commodity.isNotEmpty) params['commodity'] = commodity;

    return await get('/location/nearby-buyers', queryParameters: params);
  }

  Future<Response> getNearbyMarkets({
    double? latitude,
    double? longitude,
    String? state,
    String? district,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (latitude != null) params['latitude'] = latitude;
    if (longitude != null) params['longitude'] = longitude;
    if (state != null && state.isNotEmpty) params['state'] = state;
    if (district != null && district.isNotEmpty) params['district'] = district;

    return await get('/location/nearby-markets', queryParameters: params);
  }

  // Phase 7: Farmer <-> Buyer Matching APIs
  Future<Response> getFarmerMatches({
    String? cropId,
    double? maxDistance,
    String? commodity,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cropId != null && cropId.isNotEmpty) params['cropId'] = cropId;
    if (maxDistance != null) params['maxDistance'] = maxDistance;
    if (commodity != null && commodity.isNotEmpty) params['commodity'] = commodity;

    return await get('/matches/farmer', queryParameters: params);
  }

  Future<Response> getBuyerMatches({
    String? requirementId,
    double? maxDistance,
    String? commodity,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (requirementId != null && requirementId.isNotEmpty) params['requirementId'] = requirementId;
    if (maxDistance != null) params['maxDistance'] = maxDistance;
    if (commodity != null && commodity.isNotEmpty) params['commodity'] = commodity;

    return await get('/matches/buyer', queryParameters: params);
  }

  Future<Response> getMatchById(String matchId) async {
    return await get('/matches/$matchId');
  }

  // Opportunity & Interest APIs
  Future<Response> expressInterest({
    required String cropId,
    String? requirementId,
    double? offeredPrice,
    String? notes,
  }) async {
    final data = <String, dynamic>{'cropId': cropId};
    if (requirementId != null && requirementId.isNotEmpty) data['requirementId'] = requirementId;
    if (offeredPrice != null) data['offeredPrice'] = offeredPrice;
    if (notes != null) data['notes'] = notes;
    return await post('/opportunities/express-interest', data: data);
  }

  Future<Response> farmerExpressInterest({
    required String requirementId,
    String? cropId,
    double? offeredPrice,
    String? notes,
  }) async {
    final data = <String, dynamic>{'requirementId': requirementId};
    if (cropId != null && cropId.isNotEmpty) data['cropId'] = cropId;
    if (offeredPrice != null) data['offeredPrice'] = offeredPrice;
    if (notes != null) data['notes'] = notes;
    return await post('/opportunities/farmer-express-interest', data: data);
  }

  Future<Response> getFarmerOpportunities({int page = 1, int limit = 20, String? status}) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null && status.isNotEmpty) params['status'] = status;
    return await get('/opportunities/farmer-opportunities', queryParameters: params);
  }

  Future<Response> getBuyerOpportunities({int page = 1, int limit = 20, String? status}) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null && status.isNotEmpty) params['status'] = status;
    return await get('/opportunities/buyer-opportunities', queryParameters: params);
  }

  Future<Response> getDiscoverableFarmerCrops({
    String? commodity,
    String? state,
    String? district,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (commodity != null && commodity.isNotEmpty) params['commodity'] = commodity;
    if (state != null && state.isNotEmpty) params['state'] = state;
    if (district != null && district.isNotEmpty) params['district'] = district;
    return await get('/opportunities/discover-crops', queryParameters: params);
  }

  Future<Response> getOpportunityById(String id) async {
    return await get('/opportunities/$id');
  }

  Future<Response> acceptOpportunity(String id) async {
    return await post('/opportunities/$id/accept');
  }

  Future<Response> rejectOpportunity(String id) async {
    return await post('/opportunities/$id/reject');
  }

  Future<Response> cancelOpportunity(String id) async {
    return await patch('/opportunities/$id/cancel');
  }

  Future<Response> completeOpportunity(String id) async {
    return await post('/opportunities/$id/complete');
  }

  // Notifications APIs
  Future<Response> getNotifications({int page = 1, int limit = 20, String? status}) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null && status.isNotEmpty) params['status'] = status;
    return await get('/notifications', queryParameters: params);
  }

  Future<Response> getUnreadNotificationCount() async {
    return await get('/notifications/unread-count');
  }

  Future<Response> markNotificationAsRead(String id) async {
    return await patch('/notifications/$id/read');
  }

  Future<Response> markAllNotificationsAsRead() async {
    return await patch('/notifications/read-all');
  }

  // Deal Management APIs (Phases 10, 11, 12)
  Future<Response> getFarmerDeals({String? status}) async {
    final query = <String, dynamic>{};
    if (status != null && status.isNotEmpty && status != 'ALL') {
      query['status'] = status;
    }
    return await get('/deals/farmer', queryParameters: query);
  }

  Future<Response> getBuyerDeals({String? status}) async {
    final query = <String, dynamic>{};
    if (status != null && status.isNotEmpty && status != 'ALL') {
      query['status'] = status;
    }
    return await get('/deals/buyer', queryParameters: query);
  }

  Future<Response> getDealById(String id) async {
    return await get('/deals/$id');
  }

  Future<Response> updateDealStatus(String id, String status, {String? notes}) async {
    return await patch('/deals/$id/status', data: {
      'status': status,
      if (notes != null) 'notes': notes,
    });
  }

  Future<Response> updateDealLogistics(
    String id, {
    Map<String, dynamic>? pickupLocation,
    Map<String, dynamic>? deliveryLocation,
    bool? transportRequired,
    String? transportType,
    double? transportCost,
    double? otherCosts,
  }) async {
    final data = <String, dynamic>{};
    if (pickupLocation != null) data['pickupLocation'] = pickupLocation;
    if (deliveryLocation != null) data['deliveryLocation'] = deliveryLocation;
    if (transportRequired != null) data['transportRequired'] = transportRequired;
    if (transportType != null) data['transportType'] = transportType;
    if (transportCost != null) data['transportCost'] = transportCost;
    if (otherCosts != null) data['otherCosts'] = otherCosts;

    return await patch('/deals/$id/logistics', data: data);
  }

  Future<Response> markDealDelivered(String id, {String? notes}) async {
    return await patch('/deals/$id/deliver', data: {
      if (notes != null) 'notes': notes,
    });
  }

  Future<Response> cancelDeal(String id, {required String reason}) async {
    return await patch('/deals/$id/cancel', data: {
      'reason': reason,
    });
  }

  Future<Response> reportPaymentMade(String id, {String? notes, String? paymentMethod}) async {
    return await patch('/deals/$id/payment/report', data: {
      if (notes != null) 'notes': notes,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
    });
  }

  Future<Response> confirmPaymentReceived(String id, {String? notes}) async {
    return await patch('/deals/$id/payment/confirm', data: {
      if (notes != null) 'notes': notes,
    });
  }

  Future<Response> disputePayment(String id, {required String reason}) async {
    return await patch('/deals/$id/payment/dispute', data: {
      'reason': reason,
    });
  }

  Future<Response> rateDeal(
    String id, {
    required double rating,
    String? feedback,
    Map<String, dynamic>? categoryRatings,
  }) async {
    return await post('/deals/$id/ratings', data: {
      'rating': rating,
      if (feedback != null) 'feedback': feedback,
      if (categoryRatings != null) 'categoryRatings': categoryRatings,
    });
  }

  // Rating & Feedback APIs
  Future<Response> rateFarmer({
    required String opportunityId,
    required double rating,
    Map<String, dynamic>? categoryRatings,
    String? comment,
  }) async {
    return await post('/ratings/buyer-to-farmer', data: {
      'opportunityId': opportunityId,
      'rating': rating,
      'categoryRatings': categoryRatings ?? {
        'productQuality': 5,
        'freshness': 5,
        'spoilage': 5,
        'quantityAccuracy': 5,
        'farmerInteraction': 5,
        'transactionExperience': 5,
      },
      'comment': comment ?? '',
    });
  }

  Future<Response> rateBuyer({
    required String opportunityId,
    required double rating,
    Map<String, dynamic>? categoryRatings,
    String? comment,
  }) async {
    return await post('/ratings/farmer-to-buyer', data: {
      'opportunityId': opportunityId,
      'rating': rating,
      'categoryRatings': categoryRatings ?? {
        'customerInteraction': 5,
        'paymentExperience': 5,
        'communication': 5,
        'transactionExperience': 5,
      },
      'comment': comment ?? '',
    });
  }

  Future<Response> getUserRating(String userId) async {
    return await get('/ratings/user/$userId');
  }

  // Base HTTP Helpers
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    try {
      return await _dio.post(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> put(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    try {
      return await _dio.put(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    try {
      return await _dio.delete(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> patch(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    try {
      return await _dio.patch(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data.containsKey('message')) {
        return Exception(data['message'].toString());
      }
      if (statusCode == 409) return Exception('Conflict error occurred.');
      if (statusCode == 403) return Exception('You are not authorized to perform this action.');
      if (statusCode == 401) return Exception('Invalid or expired authentication.');
      if (statusCode == 404) return Exception('Requested resource not found.');
      if (statusCode == 400) return Exception('Invalid request parameters.');
      if (statusCode == 500) return Exception('Server error. Please try again later.');
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return Exception('No connection to the server. Connection timed out.');
      case DioExceptionType.receiveTimeout:
        return Exception('Server response timed out. Please try again.');
      case DioExceptionType.sendTimeout:
        return Exception('Request sending timed out.');
      case DioExceptionType.connectionError:
        return Exception('Server is unavailable. Please check backend connection.');
      case DioExceptionType.cancel:
        return Exception('Request was cancelled.');
      default:
        return Exception('Network error occurred: ${e.message ?? "Unknown error"}');
    }
  }
}
