class BuyerRequirementModel {
  final String id;
  final String? buyerId;
  final String commodity;
  final String cropName;
  final String? variety;
  final String? grade;
  final double quantity;
  final String quantityUnit;
  final double offeredPrice;
  final DateTime requiredByDate;
  final String state;
  final String district;
  final String? market;
  final String? location;
  final String? notes;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BuyerRequirementModel({
    required this.id,
    this.buyerId,
    required this.commodity,
    required this.cropName,
    this.variety,
    this.grade,
    required this.quantity,
    required this.quantityUnit,
    required this.offeredPrice,
    required this.requiredByDate,
    required this.state,
    required this.district,
    this.market,
    this.location,
    this.notes,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory BuyerRequirementModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value) ?? DateTime.now();
      } else if (value is DateTime) {
        return value;
      }
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      } else if (value is DateTime) {
        return value;
      }
      return null;
    }

    return BuyerRequirementModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      buyerId: json['buyerId']?.toString(),
      commodity: json['commodity']?.toString() ?? 'N/A',
      cropName: json['cropName']?.toString() ??
          json['commodity']?.toString() ??
          'N/A',
      variety: json['variety']?.toString() ?? 'Not specified',
      grade: json['grade']?.toString() ?? 'Not specified',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      quantityUnit: json['quantityUnit']?.toString() ?? 'Quintal',
      offeredPrice: (json['offeredPrice'] as num?)?.toDouble() ?? 0.0,
      requiredByDate: parseDate(json['requiredByDate']),
      state: json['state']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      market: json['market']?.toString(),
      location: json['location']?.toString() ?? json['market']?.toString(),
      notes: json['notes']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      createdAt: parseNullableDate(json['createdAt']),
      updatedAt: parseNullableDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'commodity': commodity,
      'cropName': cropName,
      'variety': variety,
      'grade': grade,
      'quantity': quantity,
      'quantityUnit': quantityUnit,
      'offeredPrice': offeredPrice,
      'requiredByDate': requiredByDate.toIso8601String().split('T')[0],
      'state': state,
      'district': district,
      'market': market,
      'location': location,
      'notes': notes,
      'status': status,
    };
  }
}
