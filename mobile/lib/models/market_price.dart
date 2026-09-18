class MarketPriceModel {
  final String id;
  final String state;
  final String district;
  final String market;
  final String commodity;
  final String variety;
  final String grade;
  final double minPrice;
  final double maxPrice;
  final double modalPrice;
  final String date;

  MarketPriceModel({
    required this.id,
    required this.state,
    required this.district,
    required this.market,
    required this.commodity,
    required this.variety,
    required this.grade,
    required this.minPrice,
    required this.maxPrice,
    required this.modalPrice,
    required this.date,
  });

  factory MarketPriceModel.fromJson(Map<String, dynamic> json) {
    return MarketPriceModel(
      id: json['id']?.toString() ?? '',
      state: json['state']?.toString() ?? 'N/A',
      district: json['district']?.toString() ?? 'N/A',
      market: json['market']?.toString() ?? 'N/A',
      commodity: json['commodity']?.toString() ?? 'N/A',
      variety: json['variety']?.toString() ?? 'Standard',
      grade: json['grade']?.toString() ?? 'FAQ',
      minPrice: (json['minPrice'] as num?)?.toDouble() ?? 0.0,
      maxPrice: (json['maxPrice'] as num?)?.toDouble() ?? 0.0,
      modalPrice: (json['modalPrice'] as num?)?.toDouble() ?? 0.0,
      date: json['date']?.toString() ?? '',
    );
  }
}
