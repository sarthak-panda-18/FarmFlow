class CropModel {
  final String id;
  final String? farmerId;
  final String commodity;
  final String cropName;
  final String? variety;
  final String? grade;
  final double quantity;
  final String quantityUnit;
  final double? expectedPrice;
  final DateTime harvestDate;
  final String state;
  final String district;
  final String? market;
  final String? location;
  final String? description;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CropModel({
    required this.id,
    this.farmerId,
    required this.commodity,
    required this.cropName,
    this.variety,
    this.grade,
    required this.quantity,
    required this.quantityUnit,
    this.expectedPrice,
    required this.harvestDate,
    required this.state,
    required this.district,
    this.market,
    this.location,
    this.description,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory CropModel.fromJson(Map<String, dynamic> json) {
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

    return CropModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      farmerId: json['farmerId']?.toString(),
      commodity: json['commodity']?.toString() ?? 'N/A',
      cropName: json['cropName']?.toString() ?? json['commodity']?.toString() ?? 'N/A',
      variety: json['variety']?.toString(),
      grade: json['grade']?.toString(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      quantityUnit: json['quantityUnit']?.toString() ?? 'kg',
      expectedPrice: (json['expectedPrice'] as num?)?.toDouble(),
      harvestDate: parseDate(json['harvestDate']),
      state: json['state']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      market: json['market']?.toString(),
      location: json['location']?.toString() ?? json['market']?.toString(),
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'AVAILABLE',
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
      'expectedPrice': expectedPrice,
      'harvestDate': harvestDate.toIso8601String().split('T')[0],
      'state': state,
      'district': district,
      'market': market,
      'location': location,
      'description': description,
      'status': status,
    };
  }
}
