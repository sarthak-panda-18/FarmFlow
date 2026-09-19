class BuyerOpportunityModel {
  final String id;
  final String farmerId;
  final String farmerName;
  final String farmerPhone;
  final double? farmerRating;
  final int farmerRatingCount;
  final String farmerRatingLabel;
  final bool farmerIsNew;
  final String? cropId;
  final String commodity;
  final String? cropName;
  final double quantity;
  final String quantityUnit;
  final double offeredPrice;
  final String status;
  final String? notes;
  final DateTime createdAt;

  BuyerOpportunityModel({
    required this.id,
    required this.farmerId,
    required this.farmerName,
    required this.farmerPhone,
    this.farmerRating,
    this.farmerRatingCount = 0,
    this.farmerRatingLabel = 'No ratings yet',
    this.farmerIsNew = true,
    this.cropId,
    required this.commodity,
    this.cropName,
    required this.quantity,
    required this.quantityUnit,
    required this.offeredPrice,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory BuyerOpportunityModel.fromJson(Map<String, dynamic> json) {
    final farmer = json['farmer'] as Map<String, dynamic>? ?? {};
    final farmerStats = farmer['ratingStats'] as Map<String, dynamic>? ?? {};
    final crop = json['crop'] as Map<String, dynamic>? ?? {};

    return BuyerOpportunityModel(
      id: json['id'] ?? json['_id'] ?? '',
      farmerId: farmer['id'] ?? farmer['_id'] ?? '',
      farmerName: farmer['name'] ?? 'Farmer',
      farmerPhone: farmer['phone'] ?? '',
      farmerRating: farmerStats['rating'] != null ? (farmerStats['rating'] as num).toDouble() : null,
      farmerRatingCount: farmerStats['ratingCount'] ?? 0,
      farmerRatingLabel: farmerStats['label'] ?? (farmerStats['isNew'] == true ? 'New Farmer' : 'No ratings yet'),
      farmerIsNew: farmerStats['isNew'] ?? (farmerStats['ratingCount'] == 0 || farmerStats['rating'] == null),
      cropId: crop['id'] ?? crop['_id'],
      commodity: json['commodity'] ?? crop['commodity'] ?? 'Crop',
      cropName: crop['cropName'] ?? json['commodity'],
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      quantityUnit: json['quantityUnit'] ?? 'quintal',
      offeredPrice: (json['offeredPrice'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'INTERESTED',
      notes: json['notes'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class DiscoverFarmerCropModel {
  final String id;
  final String commodity;
  final String cropName;
  final String variety;
  final double quantity;
  final String quantityUnit;
  final double expectedPrice;
  final String? harvestDate;
  final String state;
  final String district;
  final String market;
  final String location;
  final String description;
  final String farmerId;
  final String farmerName;
  final double? farmerRating;
  final int farmerRatingCount;
  final String farmerRatingLabel;
  final bool farmerIsNew;
  final String? userInterestStatus;
  final DateTime createdAt;

  DiscoverFarmerCropModel({
    required this.id,
    required this.commodity,
    required this.cropName,
    required this.variety,
    required this.quantity,
    required this.quantityUnit,
    required this.expectedPrice,
    this.harvestDate,
    required this.state,
    required this.district,
    required this.market,
    required this.location,
    required this.description,
    required this.farmerId,
    required this.farmerName,
    this.farmerRating,
    this.farmerRatingCount = 0,
    this.farmerRatingLabel = 'No ratings yet',
    this.farmerIsNew = true,
    this.userInterestStatus,
    required this.createdAt,
  });

  factory DiscoverFarmerCropModel.fromJson(Map<String, dynamic> json) {
    final farmer = json['farmer'] as Map<String, dynamic>? ?? {};
    final farmerStats = farmer['ratingStats'] as Map<String, dynamic>? ?? {};

    return DiscoverFarmerCropModel(
      id: json['id'] ?? json['_id'] ?? '',
      commodity: json['commodity'] ?? '',
      cropName: json['cropName'] ?? json['commodity'] ?? '',
      variety: json['variety'] ?? 'Local',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      quantityUnit: json['quantityUnit'] ?? 'quintal',
      expectedPrice: (json['expectedPrice'] as num?)?.toDouble() ?? 0.0,
      harvestDate: json['harvestDate'],
      state: json['state'] ?? '',
      district: json['district'] ?? '',
      market: json['market'] ?? '',
      location: json['location'] ?? json['district'] ?? '',
      description: json['description'] ?? '',
      farmerId: farmer['id'] ?? farmer['_id'] ?? '',
      farmerName: farmer['name'] ?? 'Farmer',
      farmerRating: farmerStats['rating'] != null ? (farmerStats['rating'] as num).toDouble() : null,
      farmerRatingCount: farmerStats['ratingCount'] ?? 0,
      farmerRatingLabel: farmerStats['label'] ?? (farmerStats['isNew'] == true ? 'New Farmer' : 'No ratings yet'),
      farmerIsNew: farmerStats['isNew'] ?? (farmerStats['ratingCount'] == 0 || farmerStats['rating'] == null),
      userInterestStatus: json['userInterestStatus'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
