class OpportunityModel {
  final String id;
  final String buyerId;
  final String buyerName;
  final String buyerPhone;
  final String buyerBusinessName;
  final String buyerLocation;
  final double? buyerRating;
  final int buyerRatingCount;
  final bool isBuyerNew;
  final String buyerRatingLabel;

  final String farmerId;
  final String farmerName;
  final String farmerPhone;
  final String farmerLocation;
  final double? farmerRating;
  final int farmerRatingCount;
  final bool isFarmerNew;
  final String farmerRatingLabel;

  final String? cropId;
  final String commodity;
  final String cropName;
  final String variety;
  final double quantity;
  final String quantityUnit;
  final double offeredPrice;
  final double expectedPrice;
  final String? harvestDate;
  final String? requiredByDate;
  final String? requirementId;

  final double marketReferencePrice;
  final String marketSource;
  final double? distanceKm;
  final String? googleMapsUrl;

  final String? dealId;
  final String? dealStatus;

  final String initiatedBy;
  final String status;
  final String notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  OpportunityModel({
    required this.id,
    this.dealId,
    this.dealStatus,
    required this.buyerId,
    required this.buyerName,
    required this.buyerPhone,
    required this.buyerBusinessName,
    required this.buyerLocation,
    this.buyerRating,
    this.buyerRatingCount = 0,
    this.isBuyerNew = true,
    required this.buyerRatingLabel,
    required this.farmerId,
    required this.farmerName,
    required this.farmerPhone,
    required this.farmerLocation,
    this.farmerRating,
    this.farmerRatingCount = 0,
    this.isFarmerNew = true,
    required this.farmerRatingLabel,
    this.cropId,
    required this.commodity,
    required this.cropName,
    this.variety = '',
    required this.quantity,
    required this.quantityUnit,
    required this.offeredPrice,
    this.expectedPrice = 0.0,
    this.harvestDate,
    this.requiredByDate,
    this.requirementId,
    this.marketReferencePrice = 0.0,
    this.marketSource = 'AGMARKNET Reference',
    this.distanceKm,
    this.googleMapsUrl,
    required this.initiatedBy,
    required this.status,
    required this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  String get normalizedStatus => status.toUpperCase() == 'INTERESTED' ? 'PENDING' : status.toUpperCase();
  bool get isPending => status.toUpperCase() == 'PENDING' || status.toUpperCase() == 'INTERESTED';
  bool get isAccepted => status.toUpperCase() == 'ACCEPTED';
  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  factory OpportunityModel.fromJson(Map<String, dynamic> json) {
    final buyer = json['buyer'] is Map<String, dynamic> ? json['buyer'] : {};
    final buyerStats = buyer['ratingStats'] is Map<String, dynamic> ? buyer['ratingStats'] : {};

    final farmer = json['farmer'] is Map<String, dynamic> ? json['farmer'] : {};
    final farmerStats = farmer['ratingStats'] is Map<String, dynamic> ? farmer['ratingStats'] : {};

    final crop = json['crop'] is Map<String, dynamic> ? json['crop'] : {};
    final requirement = json['requirement'] is Map<String, dynamic> ? json['requirement'] : {};

    return OpportunityModel(
      id: json['id'] ?? json['_id'] ?? '',
      dealId: json['dealId'],
      dealStatus: json['dealStatus'],
      buyerId: buyer['id'] ?? json['buyerId'] ?? '',
      buyerName: buyer['name'] ?? 'Buyer',
      buyerPhone: buyer['phone'] ?? '',
      buyerBusinessName: buyer['businessName'] ?? '',
      buyerLocation: buyer['location'] ?? '',
      buyerRating: (buyerStats['rating'] as num?)?.toDouble(),
      buyerRatingCount: buyerStats['ratingCount'] ?? 0,
      isBuyerNew: buyerStats['isNew'] ?? true,
      buyerRatingLabel: buyerStats['displayRating'] ?? (buyerStats['isNew'] == true ? 'New Buyer' : 'Verified'),

      farmerId: farmer['id'] ?? json['farmerId'] ?? '',
      farmerName: farmer['name'] ?? 'Farmer',
      farmerPhone: farmer['phone'] ?? '',
      farmerLocation: farmer['location'] ?? '',
      farmerRating: (farmerStats['rating'] as num?)?.toDouble(),
      farmerRatingCount: farmerStats['ratingCount'] ?? 0,
      isFarmerNew: farmerStats['isNew'] ?? true,
      farmerRatingLabel: farmerStats['displayRating'] ?? (farmerStats['isNew'] == true ? 'New Farmer' : 'Verified'),

      cropId: crop['id'] ?? json['cropId'],
      commodity: json['commodity'] ?? crop['commodity'] ?? requirement['commodity'] ?? 'Crop',
      cropName: crop['cropName'] ?? json['cropName'] ?? json['commodity'] ?? 'Crop',
      variety: crop['variety'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? (crop['quantity'] as num?)?.toDouble() ?? 0.0,
      quantityUnit: json['quantityUnit'] ?? crop['quantityUnit'] ?? 'kg',
      offeredPrice: (json['offeredPrice'] as num?)?.toDouble() ?? 0.0,
      expectedPrice: (crop['expectedPrice'] as num?)?.toDouble() ?? (json['expectedPrice'] as num?)?.toDouble() ?? 0.0,
      harvestDate: crop['harvestDate'] ?? json['harvestDate'],
      requiredByDate: requirement['requiredByDate'] ?? json['requiredByDate'],
      requirementId: requirement['id'] ?? json['requirementId'],

      marketReferencePrice: (json['marketReferencePrice'] as num?)?.toDouble() ?? 0.0,
      marketSource: json['marketSource'] ?? 'AGMARKNET Reference',
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      googleMapsUrl: json['googleMapsUrl'],

      initiatedBy: json['initiatedBy'] ?? 'BUYER',
      status: json['status'] ?? 'PENDING',
      notes: json['notes'] ?? '',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
    );
  }
}

