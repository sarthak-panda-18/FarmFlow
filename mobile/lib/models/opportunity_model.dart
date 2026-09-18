class OpportunityModel {
  final String id;
  final String buyerId;
  final String buyerName;
  final String buyerPhone;
  final String buyerBusinessName;
  final double? buyerRating;
  final int buyerRatingCount;
  final bool isBuyerNew;
  final String buyerRatingLabel;
  final String cropId;
  final String commodity;
  final double quantity;
  final String quantityUnit;
  final double offeredPrice;
  final String status;
  final String notes;
  final DateTime createdAt;

  OpportunityModel({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.buyerPhone,
    required this.buyerBusinessName,
    this.buyerRating,
    this.buyerRatingCount = 0,
    this.isBuyerNew = true,
    required this.buyerRatingLabel,
    required this.cropId,
    required this.commodity,
    required this.quantity,
    required this.quantityUnit,
    required this.offeredPrice,
    required this.status,
    required this.notes,
    required this.createdAt,
  });

  factory OpportunityModel.fromJson(Map<String, dynamic> json) {
    final buyer = json['buyer'] is Map<String, dynamic> ? json['buyer'] : {};
    final buyerStats = buyer['ratingStats'] is Map<String, dynamic> ? buyer['ratingStats'] : {};
    final crop = json['crop'] is Map<String, dynamic> ? json['crop'] : {};

    return OpportunityModel(
      id: json['id'] ?? json['_id'] ?? '',
      buyerId: buyer['id'] ?? json['buyerId'] ?? '',
      buyerName: buyer['name'] ?? 'Buyer',
      buyerPhone: buyer['phone'] ?? '',
      buyerBusinessName: buyer['businessName'] ?? '',
      buyerRating: (buyerStats['rating'] as num?)?.toDouble(),
      buyerRatingCount: buyerStats['ratingCount'] ?? 0,
      isBuyerNew: buyerStats['isNew'] ?? true,
      buyerRatingLabel: buyerStats['displayRating'] ?? 'New Buyer',
      cropId: crop['id'] ?? json['cropId'] ?? '',
      commodity: json['commodity'] ?? crop['commodity'] ?? 'Crop',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      quantityUnit: json['quantityUnit'] ?? 'kg',
      offeredPrice: (json['offeredPrice'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'INTERESTED',
      notes: json['notes'] ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }
}
