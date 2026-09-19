class BuyerRecommendation {
  final String opportunityId;
  final String buyerId;
  final String buyerName;
  final String businessName;
  final String phone;
  final Map<String, dynamic>? ratingStats;
  final String location;
  final double? distanceKm;
  final Map<String, double>? coordinates;
  final String googleMapsUrl;
  final double quantity;
  final String quantityUnit;
  final double unitPrice;
  final double sellingPrice;
  final double? transportationCost;
  final bool isTransportAvailable;
  final double otherCosts;
  final double netValue;
  final String status;
  final String notes;
  final int rank;
  final bool isRecommended;
  final DateTime? createdAt;

  BuyerRecommendation({
    required this.opportunityId,
    required this.buyerId,
    required this.buyerName,
    required this.businessName,
    required this.phone,
    this.ratingStats,
    required this.location,
    this.distanceKm,
    this.coordinates,
    required this.googleMapsUrl,
    required this.quantity,
    this.quantityUnit = 'quintal',
    required this.unitPrice,
    required this.sellingPrice,
    this.transportationCost,
    required this.isTransportAvailable,
    required this.otherCosts,
    required this.netValue,
    required this.status,
    this.notes = '',
    required this.rank,
    required this.isRecommended,
    this.createdAt,
  });

  factory BuyerRecommendation.fromJson(Map<String, dynamic> json) {
    Map<String, double>? coords;
    if (json['coordinates'] != null && json['coordinates'] is Map) {
      coords = {
        'latitude': (json['coordinates']['latitude'] as num?)?.toDouble() ?? 0.0,
        'longitude': (json['coordinates']['longitude'] as num?)?.toDouble() ?? 0.0,
      };
    }

    return BuyerRecommendation(
      opportunityId: json['opportunityId']?.toString() ?? '',
      buyerId: json['buyerId']?.toString() ?? '',
      buyerName: json['buyerName']?.toString() ?? 'Verified Buyer',
      businessName: json['businessName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      ratingStats: json['ratingStats'] as Map<String, dynamic>?,
      location: json['location']?.toString() ?? 'Location not specified',
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      coordinates: coords,
      googleMapsUrl: json['googleMapsUrl']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      quantityUnit: json['quantityUnit']?.toString().toLowerCase() ?? 'quintal',
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      transportationCost: (json['transportationCost'] as num?)?.toDouble(),
      isTransportAvailable: json['isTransportAvailable'] == true,
      otherCosts: (json['otherCosts'] as num?)?.toDouble() ?? 0.0,
      netValue: (json['netValue'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'PENDING',
      notes: json['notes']?.toString() ?? '',
      rank: (json['rank'] as num?)?.toInt() ?? 1,
      isRecommended: json['isRecommended'] == true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }
}

class CropRecommendationData {
  final String cropId;
  final String commodity;
  final String cropName;
  final String variety;
  final double quantity;
  final String quantityUnit;
  final double expectedPrice;
  final String status;
  final String location;
  final int interestedBuyersCount;
  final bool isRecommendationActive;
  final int recommendationThreshold;
  final BuyerRecommendation? recommendedBuyer;
  final String explanation;
  final List<String> reasons;
  final List<BuyerRecommendation> allBuyers;

  CropRecommendationData({
    required this.cropId,
    required this.commodity,
    required this.cropName,
    required this.variety,
    required this.quantity,
    this.quantityUnit = 'quintal',
    required this.expectedPrice,
    required this.status,
    required this.location,
    required this.interestedBuyersCount,
    required this.isRecommendationActive,
    this.recommendationThreshold = 3,
    this.recommendedBuyer,
    required this.explanation,
    required this.reasons,
    required this.allBuyers,
  });

  factory CropRecommendationData.fromJson(Map<String, dynamic> json) {
    final crop = json['crop'] as Map<String, dynamic>? ?? {};
    final rawBuyers = json['allBuyers'] as List? ?? [];
    final buyersList = rawBuyers.map((item) => BuyerRecommendation.fromJson(item as Map<String, dynamic>)).toList();

    BuyerRecommendation? recBuyer;
    if (json['recommendedBuyer'] != null && json['recommendedBuyer'] is Map) {
      recBuyer = BuyerRecommendation.fromJson(json['recommendedBuyer'] as Map<String, dynamic>);
    } else if (buyersList.isNotEmpty && json['isRecommendationActive'] == true) {
      recBuyer = buyersList.firstWhere((b) => b.isRecommended, orElse: () => buyersList.first);
    }

    final rawReasons = json['reasons'] as List? ?? [];
    final reasonsList = rawReasons.map((r) => r.toString()).toList();

    return CropRecommendationData(
      cropId: crop['id']?.toString() ?? crop['_id']?.toString() ?? '',
      commodity: crop['commodity']?.toString() ?? '',
      cropName: crop['cropName']?.toString() ?? crop['commodity']?.toString() ?? '',
      variety: crop['variety']?.toString() ?? '',
      quantity: (crop['quantity'] as num?)?.toDouble() ?? 0.0,
      quantityUnit: crop['quantityUnit']?.toString().toLowerCase() ?? 'quintal',
      expectedPrice: (crop['expectedPrice'] as num?)?.toDouble() ?? 0.0,
      status: crop['status']?.toString() ?? 'AVAILABLE',
      location: crop['location']?.toString() ?? '',
      interestedBuyersCount: (json['interestedBuyersCount'] as num?)?.toInt() ?? buyersList.length,
      isRecommendationActive: json['isRecommendationActive'] == true,
      recommendationThreshold: (json['recommendationThreshold'] as num?)?.toInt() ?? 3,
      recommendedBuyer: recBuyer,
      explanation: json['explanation']?.toString() ?? '',
      reasons: reasonsList,
      allBuyers: buyersList,
    );
  }
}
