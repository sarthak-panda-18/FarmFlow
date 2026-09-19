class MatchModel {
  final String id;
  final String? cropId;
  final String? cropName;
  final String commodity;
  final String? requirementId;
  final String? buyerId;
  final String? buyerName;
  final String? buyerBusinessName;
  final String? farmerId;
  final String? farmerName;
  final double farmerAvailableQty;
  final String farmerUnit;
  final double farmerExpectedPrice;
  final double buyerRequiredQty;
  final String buyerUnit;
  final double buyerExpectedPrice;
  final double marketReferencePrice;
  final String marketReferenceUnit;
  final String marketSource;
  final double? distanceKm;
  final String location;
  final double? latitude;
  final double? longitude;
  final String googleMapsUrl;
  final String? harvestDate;
  final String? requiredByDate;
  final int matchScore;
  final String compatibility;
  final Map<String, dynamic> breakdown;
  final double unitPrice;
  final double matchedQty;
  final double sellingPrice;
  final double? transportationCost;
  final bool isTransportAvailable;
  final double otherCosts;
  final double netValue;
  final double netValuePerQ;
  final int rank;
  final bool isRecommended;
  final List<String> recommendationReasons;
  final Map<String, dynamic>? mlPrediction;
  final Map<String, dynamic>? buyerRating;
  final String status;

  MatchModel({
    required this.id,
    this.cropId,
    this.cropName,
    required this.commodity,
    this.requirementId,
    this.buyerId,
    this.buyerName,
    this.buyerBusinessName,
    this.farmerId,
    this.farmerName,
    required this.farmerAvailableQty,
    required this.farmerUnit,
    required this.farmerExpectedPrice,
    required this.buyerRequiredQty,
    required this.buyerUnit,
    required this.buyerExpectedPrice,
    required this.marketReferencePrice,
    required this.marketReferenceUnit,
    required this.marketSource,
    this.distanceKm,
    required this.location,
    this.latitude,
    this.longitude,
    required this.googleMapsUrl,
    this.harvestDate,
    this.requiredByDate,
    required this.matchScore,
    required this.compatibility,
    required this.breakdown,
    this.unitPrice = 0.0,
    this.matchedQty = 0.0,
    this.sellingPrice = 0.0,
    this.transportationCost,
    this.isTransportAvailable = false,
    this.otherCosts = 0.0,
    this.netValue = 0.0,
    this.netValuePerQ = 0.0,
    this.rank = 1,
    this.isRecommended = false,
    this.recommendationReasons = const [],
    this.mlPrediction,
    this.buyerRating,
    this.status = 'POTENTIAL',
  });

  static double _toDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? fallback;
    return fallback;
  }

  static double? _toNullableDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  static int _toInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  static String _toString(dynamic val, [String fallback = '']) {
    if (val == null) return fallback;
    return val.toString();
  }

  static String? _toNullableString(dynamic val) {
    if (val == null) return null;
    final str = val.toString().trim();
    return str.isEmpty ? null : str;
  }

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    double? lat;
    double? lng;

    if (json['buyerCoordinates'] is Map) {
      final bCoords = json['buyerCoordinates'] as Map;
      lat = _toNullableDouble(bCoords['latitude']);
      lng = _toNullableDouble(bCoords['longitude']);
    } else if (json['farmerCoordinates'] is Map) {
      final fCoords = json['farmerCoordinates'] as Map;
      lat = _toNullableDouble(fCoords['latitude']);
      lng = _toNullableDouble(fCoords['longitude']);
    }

    final double fExpected = _toDouble(json['farmerExpectedPrice']);
    final double bExpected = _toDouble(json['buyerExpectedPrice']);
    final double uPrice = _toDouble(
      json['unitPrice'],
      bExpected > 0 ? bExpected : fExpected,
    );

    final double fQty = _toDouble(json['farmerAvailableQty']);
    final double bQty = _toDouble(json['buyerRequiredQty']);
    final double mQty = _toDouble(
      json['matchedQty'],
      fQty > 0 && bQty > 0 ? (fQty < bQty ? fQty : bQty) : fQty,
    );

    final double sPrice = _toDouble(json['sellingPrice'], mQty * uPrice);
    final double? tCost = _toNullableDouble(json['transportationCost']);
    final bool isTransport = json['isTransportAvailable'] == true ||
        (tCost != null && tCost >= 0);
    final double oCosts = _toDouble(json['otherCosts']);

    final double nVal = _toDouble(
      json['netValue'],
      isTransport && tCost != null ? sPrice - tCost - oCosts : sPrice - oCosts,
    );

    final double nValPerQ = _toDouble(
      json['netValuePerQ'],
      mQty > 0 ? nVal / mQty : uPrice,
    );

    List<String> reasons = [];
    if (json['recommendationReasons'] is List) {
      reasons = (json['recommendationReasons'] as List)
          .where((e) => e != null)
          .map((e) => e.toString())
          .toList();
    }

    return MatchModel(
      id: _toString(json['id'], ''),
      cropId: _toNullableString(json['cropId']),
      cropName: _toNullableString(json['cropName']) ??
          _toNullableString(json['commodity']),
      commodity: _toString(json['commodity'], 'Crop'),
      requirementId: _toNullableString(json['requirementId']),
      buyerId: _toNullableString(json['buyerId']),
      buyerName: _toNullableString(json['buyerName']) ?? 'Verified Buyer',
      buyerBusinessName: _toNullableString(json['buyerBusinessName']),
      farmerId: _toNullableString(json['farmerId']),
      farmerName: _toNullableString(json['farmerName']) ?? 'Verified Farmer',
      farmerAvailableQty: fQty,
      farmerUnit: _toString(json['farmerUnit'], 'quintal'),
      farmerExpectedPrice: fExpected,
      buyerRequiredQty: bQty,
      buyerUnit: _toString(json['buyerUnit'], 'quintal'),
      buyerExpectedPrice: bExpected,
      marketReferencePrice: _toDouble(json['marketReferencePrice']),
      marketReferenceUnit: _toString(json['marketReferenceUnit'], 'Quintal'),
      marketSource: _toString(json['marketSource'], 'AGMARKNET Dataset'),
      distanceKm: _toNullableDouble(json['distanceKm']),
      location: _toString(json['location'], 'Location not specified'),
      latitude: lat,
      longitude: lng,
      googleMapsUrl: _toString(json['googleMapsUrl'], ''),
      harvestDate: _toNullableString(json['harvestDate']),
      requiredByDate: _toNullableString(json['requiredByDate']),
      matchScore: _toInt(json['matchScore'], 0),
      compatibility: _toString(json['compatibility'], 'Potential Match'),
      breakdown: json['breakdown'] is Map<String, dynamic>
          ? json['breakdown'] as Map<String, dynamic>
          : {},
      unitPrice: uPrice,
      matchedQty: mQty,
      sellingPrice: sPrice,
      transportationCost: tCost,
      isTransportAvailable: isTransport,
      otherCosts: oCosts,
      netValue: nVal,
      netValuePerQ: nValPerQ,
      rank: _toInt(json['rank'], 1),
      isRecommended: json['isRecommended'] == true,
      recommendationReasons: reasons,
      mlPrediction: json['mlPrediction'] is Map<String, dynamic>
          ? json['mlPrediction'] as Map<String, dynamic>
          : null,
      buyerRating: json['buyerRating'] is Map<String, dynamic>
          ? json['buyerRating'] as Map<String, dynamic>
          : null,
      status: _toString(json['status'], 'POTENTIAL'),
    );
  }
}
