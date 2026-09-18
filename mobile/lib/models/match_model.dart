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
    this.status = 'POTENTIAL',
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    double? lat;
    double? lng;

    if (json['buyerCoordinates'] != null) {
      lat = (json['buyerCoordinates']['latitude'] as num?)?.toDouble();
      lng = (json['buyerCoordinates']['longitude'] as num?)?.toDouble();
    } else if (json['farmerCoordinates'] != null) {
      lat = (json['farmerCoordinates']['latitude'] as num?)?.toDouble();
      lng = (json['farmerCoordinates']['longitude'] as num?)?.toDouble();
    }

    return MatchModel(
      id: json['id']?.toString() ?? '',
      cropId: json['cropId']?.toString(),
      cropName: json['cropName']?.toString() ?? json['commodity']?.toString(),
      commodity: json['commodity']?.toString() ?? 'N/A',
      requirementId: json['requirementId']?.toString(),
      buyerId: json['buyerId']?.toString(),
      buyerName: json['buyerName']?.toString() ?? 'Verified Buyer',
      buyerBusinessName: json['buyerBusinessName']?.toString(),
      farmerId: json['farmerId']?.toString(),
      farmerName: json['farmerName']?.toString() ?? 'Verified Farmer',
      farmerAvailableQty: (json['farmerAvailableQty'] as num?)?.toDouble() ?? 0.0,
      farmerUnit: json['farmerUnit']?.toString() ?? 'kg',
      farmerExpectedPrice: (json['farmerExpectedPrice'] as num?)?.toDouble() ?? 0.0,
      buyerRequiredQty: (json['buyerRequiredQty'] as num?)?.toDouble() ?? 0.0,
      buyerUnit: json['buyerUnit']?.toString() ?? 'kg',
      buyerExpectedPrice: (json['buyerExpectedPrice'] as num?)?.toDouble() ?? 0.0,
      marketReferencePrice: (json['marketReferencePrice'] as num?)?.toDouble() ?? 0.0,
      marketReferenceUnit: json['marketReferenceUnit']?.toString() ?? 'Quintal',
      marketSource: json['marketSource']?.toString() ?? 'AGMARKNET',
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      location: json['location']?.toString() ?? 'N/A',
      latitude: lat,
      longitude: lng,
      googleMapsUrl: json['googleMapsUrl']?.toString() ?? '',
      harvestDate: json['harvestDate']?.toString(),
      requiredByDate: json['requiredByDate']?.toString(),
      matchScore: (json['matchScore'] as num?)?.toInt() ?? 0,
      compatibility: json['compatibility']?.toString() ?? 'Potential Match',
      breakdown: json['breakdown'] is Map<String, dynamic>
          ? json['breakdown'] as Map<String, dynamic>
          : {},
      status: json['status']?.toString() ?? 'POTENTIAL',
    );
  }
}
