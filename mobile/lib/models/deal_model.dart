import '../services/location_service.dart';

class DealModel {
  final String id;
  final String farmerId;
  final String farmerName;
  final String farmerPhone;
  final String farmerLocation;
  final double? farmerRating;
  final int farmerRatingCount;
  final String farmerRatingLabel;

  final String buyerId;
  final String buyerName;
  final String buyerPhone;
  final String buyerBusinessName;
  final String buyerLocation;
  final double? buyerRating;
  final int buyerRatingCount;
  final String buyerRatingLabel;

  final String opportunityId;
  final String? cropId;
  final String? requirementId;

  final String commodity;
  final String crop;
  final String variety;
  final double quantity;
  final String quantityUnit;
  final double agreedPrice;
  final String agreedPriceUnit;
  final double totalAmount;
  final DateTime agreedDate;
  final DateTime? deliveryDate;

  final String status;
  final String? cancellationReason;
  final String? cancelledBy;
  final DateTime? cancelledAt;

  // Official Deal Agreement
  final String agreementStatus;
  final bool farmerAccepted;
  final bool farmerAgreementAccepted;
  final bool buyerAccepted;
  final bool buyerAgreementAccepted;
  final DateTime? farmerAcceptedAt;
  final DateTime? buyerAcceptedAt;
  final int agreementVersion;
  final int termsAcceptedVersion;

  // Logistics
  final String pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final double? distanceKm;
  final bool transportRequired;
  final String transportType;
  final double transportCost;
  final double otherCosts;
  final String logisticsStatus;
  final DateTime? deliveredAt;
  final String? pickupMapsUrl;
  final String? deliveryMapsUrl;

  // Net Return Financials
  final double estimatedGrossAmount;
  final double estimatedTransportCost;
  final double estimatedOtherCosts;
  final double estimatedNetReturn;
  final double estimatedTotalBuyerCost;

  // External Payment
  final String paymentStatus;
  final String paymentMethod;
  final String? paymentReportedBy;
  final String? paymentReportedByRole;
  final DateTime? paymentReportedAt;
  final String paymentReportedNotes;
  final String? paymentConfirmedBy;
  final DateTime? paymentConfirmedAt;
  final bool paymentDisputed;
  final String paymentDisputeReason;

  // Rating
  final bool farmerRated;
  final bool buyerRated;
  final DateTime? completedAt;
  final DateTime createdAt;

  DealModel({
    required this.id,
    required this.farmerId,
    required this.farmerName,
    required this.farmerPhone,
    required this.farmerLocation,
    this.farmerRating,
    this.farmerRatingCount = 0,
    required this.farmerRatingLabel,
    required this.buyerId,
    required this.buyerName,
    required this.buyerPhone,
    required this.buyerBusinessName,
    required this.buyerLocation,
    this.buyerRating,
    this.buyerRatingCount = 0,
    required this.buyerRatingLabel,
    required this.opportunityId,
    this.cropId,
    this.requirementId,
    required this.commodity,
    required this.crop,
    this.variety = '',
    required this.quantity,
    this.quantityUnit = 'Quintal',
    required this.agreedPrice,
    this.agreedPriceUnit = 'quintal',
    required this.totalAmount,
    required this.agreedDate,
    this.deliveryDate,
    required this.status,
    this.cancellationReason,
    this.cancelledBy,
    this.cancelledAt,
    this.agreementStatus = 'AGREEMENT_PENDING',
    this.farmerAccepted = false,
    this.farmerAgreementAccepted = false,
    this.buyerAccepted = false,
    this.buyerAgreementAccepted = false,
    this.farmerAcceptedAt,
    this.buyerAcceptedAt,
    this.agreementVersion = 1,
    this.termsAcceptedVersion = 1,
    required this.pickupAddress,
    this.pickupLat,
    this.pickupLng,
    required this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    this.distanceKm,
    this.transportRequired = true,
    this.transportType = 'Standard Road Transport',
    this.transportCost = 0.0,
    this.otherCosts = 0.0,
    this.logisticsStatus = 'NOT_PLANNED',
    this.deliveredAt,
    this.pickupMapsUrl,
    this.deliveryMapsUrl,
    required this.estimatedGrossAmount,
    required this.estimatedTransportCost,
    required this.estimatedOtherCosts,
    required this.estimatedNetReturn,
    required this.estimatedTotalBuyerCost,
    required this.paymentStatus,
    this.paymentMethod = 'External / Direct Payment',
    this.paymentReportedBy,
    this.paymentReportedByRole,
    this.paymentReportedAt,
    this.paymentReportedNotes = '',
    this.paymentConfirmedBy,
    this.paymentConfirmedAt,
    this.paymentDisputed = false,
    this.paymentDisputeReason = '',
    this.farmerRated = false,
    this.buyerRated = false,
    this.completedAt,
    required this.createdAt,
  });

  bool get isAgreementConfirmed =>
      agreementStatus.toUpperCase() == 'DEAL_CONFIRMED' ||
      ((farmerAccepted || farmerAgreementAccepted) &&
          (buyerAccepted || buyerAgreementAccepted));

  bool get isWaitingForBuyer =>
      !isAgreementConfirmed &&
      (agreementStatus.toUpperCase() == 'WAITING_FOR_BUYER' ||
          ((farmerAccepted || farmerAgreementAccepted) &&
              !(buyerAccepted || buyerAgreementAccepted)));

  bool get isWaitingForFarmer =>
      !isAgreementConfirmed &&
      (agreementStatus.toUpperCase() == 'WAITING_FOR_FARMER' ||
          ((buyerAccepted || buyerAgreementAccepted) &&
              !(farmerAccepted || farmerAgreementAccepted)));

  bool get isAgreementPending =>
      !isAgreementConfirmed && !isWaitingForBuyer && !isWaitingForFarmer;

  String get agreementStatusDisplayText {
    if (isAgreementConfirmed) return 'Deal Agreement Confirmed';
    if (isWaitingForBuyer) return 'Waiting for Buyer confirmation';
    if (isWaitingForFarmer) return 'Waiting for Farmer confirmation';
    return 'Agreement Pending';
  }

  double get totalPrice => totalAmount;
  String get pickupLocation => pickupAddress.isNotEmpty
      ? pickupAddress
      : (farmerLocation.isNotEmpty ? farmerLocation : 'Farm Location');
  String get deliveryLocation => deliveryAddress.isNotEmpty
      ? deliveryAddress
      : (buyerLocation.isNotEmpty ? buyerLocation : 'Buyer Location');

  bool get isConfirmed =>
      status.toUpperCase() == 'CONFIRMED' ||
      status.toUpperCase() == 'DEAL_CONFIRMED' ||
      isAgreementConfirmed;
  bool get isDelivered =>
      status.toUpperCase() == 'DELIVERED' ||
      logisticsStatus.toUpperCase() == 'DELIVERED';
  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  bool get isPaymentPending => paymentStatus.toUpperCase() == 'PAYMENT_PENDING';
  bool get isPaymentReported =>
      paymentStatus.toUpperCase() == 'PAYMENT_REPORTED';
  bool get isPaymentConfirmed =>
      paymentStatus.toUpperCase() == 'PAYMENT_CONFIRMED_BY_BOTH';
  bool get isPaymentDisputed =>
      paymentStatus.toUpperCase() == 'PAYMENT_DISPUTED';

  bool get isEligibleForRating =>
      isDelivered || isCompleted || isPaymentConfirmed;

  factory DealModel.fromJson(Map<String, dynamic> json) {
    final farmer = json['farmerId'] is Map<String, dynamic>
        ? json['farmerId']
        : (json['farmer'] is Map<String, dynamic> ? json['farmer'] : {});
    final farmerStats = farmer['ratingStats'] is Map<String, dynamic>
        ? farmer['ratingStats']
        : {};

    final buyer = json['buyerId'] is Map<String, dynamic>
        ? json['buyerId']
        : (json['buyer'] is Map<String, dynamic> ? json['buyer'] : {});
    final buyerStats = buyer['ratingStats'] is Map<String, dynamic>
        ? buyer['ratingStats']
        : {};

    final pickup = json['pickupLocation'] is Map<String, dynamic>
        ? json['pickupLocation']
        : {};
    final delivery = json['deliveryLocation'] is Map<String, dynamic>
        ? json['deliveryLocation']
        : {};

    final double pLat = (pickup['latitude'] as num?)?.toDouble() ?? 0.0;
    final double pLng = (pickup['longitude'] as num?)?.toDouble() ?? 0.0;
    final double dLat = (delivery['latitude'] as num?)?.toDouble() ?? 0.0;
    final double dLng = (delivery['longitude'] as num?)?.toDouble() ?? 0.0;

    final rawFarmerAddr = farmer['address'] is String
        ? farmer['address']
        : (farmer['location'] is String ? farmer['location'] : '');
    final cleanFarmerLocation = LocationService.sanitizeAddress(rawFarmerAddr);

    final rawBuyerAddr = buyer['address'] is String
        ? buyer['address']
        : (buyer['location'] is String ? buyer['location'] : '');
    final cleanBuyerLocation = LocationService.sanitizeAddress(rawBuyerAddr);

    final rawPickup = pickup['address'] is String
        ? pickup['address']
        : (json['pickupAddress'] is String ? json['pickupAddress'] : '');
    final cleanPickup = LocationService.sanitizeAddress(rawPickup);
    final finalPickupAddr =
        cleanPickup.isNotEmpty ? cleanPickup : cleanFarmerLocation;

    final rawDelivery = delivery['address'] is String
        ? delivery['address']
        : (json['deliveryAddress'] is String ? json['deliveryAddress'] : '');
    final cleanDelivery = LocationService.sanitizeAddress(rawDelivery);
    final finalDeliveryAddr =
        cleanDelivery.isNotEmpty ? cleanDelivery : cleanBuyerLocation;

    String? pMapsUrl = json['pickupMapsUrl'] ?? pickup['mapsUrl'];
    if (pMapsUrl != null &&
        (pMapsUrl.contains('query=,') ||
            pMapsUrl.contains('query=%2C') ||
            pMapsUrl.trim().endsWith('query='))) {
      pMapsUrl = null;
    }
    if (pMapsUrl == null && pLat != 0.0 && pLng != 0.0) {
      pMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$pLat,$pLng';
    } else if (pMapsUrl == null && finalPickupAddr.isNotEmpty) {
      pMapsUrl =
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(finalPickupAddr)}';
    }

    String? dMapsUrl = json['deliveryMapsUrl'] ?? delivery['mapsUrl'];
    if (dMapsUrl != null &&
        (dMapsUrl.contains('query=,') ||
            dMapsUrl.contains('query=%2C') ||
            dMapsUrl.trim().endsWith('query='))) {
      dMapsUrl = null;
    }
    if (dMapsUrl == null && dLat != 0.0 && dLng != 0.0) {
      dMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$dLat,$dLng';
    } else if (dMapsUrl == null && finalDeliveryAddr.isNotEmpty) {
      dMapsUrl =
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(finalDeliveryAddr)}';
    }

    return DealModel(
      id: json['id'] ?? json['_id'] ?? '',
      farmerId: farmer['id'] ?? farmer['_id'] ?? json['farmerId'] ?? '',
      farmerName: farmer['name'] ?? 'Farmer',
      farmerPhone: farmer['phone'] ?? '',
      farmerLocation: cleanFarmerLocation,
      farmerRating: (farmerStats['rating'] as num?)?.toDouble(),
      farmerRatingCount: farmerStats['ratingCount'] ?? 0,
      farmerRatingLabel: farmerStats['displayRating'] ?? 'Verified Farmer',
      buyerId: buyer['id'] ?? buyer['_id'] ?? json['buyerId'] ?? '',
      buyerName: buyer['name'] ?? 'Buyer',
      buyerPhone: buyer['phone'] ?? '',
      buyerBusinessName: buyer['businessName'] ?? '',
      buyerLocation: cleanBuyerLocation,
      buyerRating: (buyerStats['rating'] as num?)?.toDouble(),
      buyerRatingCount: buyerStats['ratingCount'] ?? 0,
      buyerRatingLabel: buyerStats['displayRating'] ?? 'Verified Buyer',
      opportunityId: json['opportunityId'] is Map<String, dynamic>
          ? (json['opportunityId']['_id'] ?? json['opportunityId']['id'] ?? '')
          : (json['opportunityId'] ?? ''),
      cropId: json['cropId'] is Map<String, dynamic>
          ? json['cropId']['_id']
          : json['cropId'],
      requirementId: json['requirementId'] is Map<String, dynamic>
          ? json['requirementId']['_id']
          : json['requirementId'],
      commodity: json['commodity'] ?? json['crop'] ?? 'Crop',
      crop: json['crop'] ?? json['commodity'] ?? 'Crop',
      variety: json['variety'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      quantityUnit: json['quantityUnit'] ?? 'Quintal',
      agreedPrice: (json['agreedPrice'] as num?)?.toDouble() ?? 0.0,
      agreedPriceUnit: json['agreedPriceUnit'] ?? 'quintal',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      agreedDate: json['agreedDate'] != null
          ? DateTime.tryParse(json['agreedDate']) ?? DateTime.now()
          : DateTime.now(),
      deliveryDate: json['deliveryDate'] != null
          ? DateTime.tryParse(json['deliveryDate'])
          : null,
      status: json['status'] ?? 'AGREEMENT_PENDING',
      cancellationReason: json['cancellationReason'],
      cancelledBy: json['cancelledBy'],
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.tryParse(json['cancelledAt'])
          : null,
      agreementStatus: json['agreementStatus'] ?? 'AGREEMENT_PENDING',
      farmerAccepted: json['farmerAccepted'] == true ||
          json['farmerAgreementAccepted'] == true,
      farmerAgreementAccepted: json['farmerAgreementAccepted'] == true ||
          json['farmerAccepted'] == true,
      buyerAccepted: json['buyerAccepted'] == true ||
          json['buyerAgreementAccepted'] == true,
      buyerAgreementAccepted: json['buyerAgreementAccepted'] == true ||
          json['buyerAccepted'] == true,
      farmerAcceptedAt: json['farmerAcceptedAt'] != null
          ? DateTime.tryParse(json['farmerAcceptedAt'])
          : null,
      buyerAcceptedAt: json['buyerAcceptedAt'] != null
          ? DateTime.tryParse(json['buyerAcceptedAt'])
          : null,
      agreementVersion: json['agreementVersion'] is num
          ? (json['agreementVersion'] as num).toInt()
          : 1,
      termsAcceptedVersion: json['termsAcceptedVersion'] is num
          ? (json['termsAcceptedVersion'] as num).toInt()
          : 1,
      pickupAddress: finalPickupAddr,
      pickupLat: pLat != 0.0 ? pLat : null,
      pickupLng: pLng != 0.0 ? pLng : null,
      deliveryAddress: finalDeliveryAddr,
      deliveryLat: dLat != 0.0 ? dLat : null,
      deliveryLng: dLng != 0.0 ? dLng : null,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      transportRequired: json['transportRequired'] ?? true,
      transportType: json['transportType'] ?? 'Standard Road Transport',
      transportCost: (json['transportCost'] as num?)?.toDouble() ?? 0.0,
      otherCosts: (json['otherCosts'] as num?)?.toDouble() ?? 0.0,
      logisticsStatus: json['logisticsStatus'] ?? 'NOT_PLANNED',
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.tryParse(json['deliveredAt'])
          : null,
      pickupMapsUrl: pMapsUrl,
      deliveryMapsUrl: dMapsUrl,
      estimatedGrossAmount:
          (json['estimatedGrossAmount'] as num?)?.toDouble() ??
              (json['totalAmount'] as num?)?.toDouble() ??
              0.0,
      estimatedTransportCost:
          (json['estimatedTransportCost'] as num?)?.toDouble() ??
              (json['transportCost'] as num?)?.toDouble() ??
              0.0,
      estimatedOtherCosts: (json['estimatedOtherCosts'] as num?)?.toDouble() ??
          (json['otherCosts'] as num?)?.toDouble() ??
          0.0,
      estimatedNetReturn:
          (json['estimatedNetReturn'] as num?)?.toDouble() ?? 0.0,
      estimatedTotalBuyerCost:
          (json['estimatedTotalBuyerCost'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['paymentStatus'] ?? 'PAYMENT_PENDING',
      paymentMethod: json['paymentMethod'] ?? 'External / Direct Payment',
      paymentReportedBy: json['paymentReportedBy'] is Map
          ? json['paymentReportedBy']['_id']
          : json['paymentReportedBy'],
      paymentReportedByRole: json['paymentReportedByRole'],
      paymentReportedAt: json['paymentReportedAt'] != null
          ? DateTime.tryParse(json['paymentReportedAt'])
          : null,
      paymentReportedNotes: json['paymentReportedNotes'] ?? '',
      paymentConfirmedBy: json['paymentConfirmedBy'] is Map
          ? json['paymentConfirmedBy']['_id']
          : json['paymentConfirmedBy'],
      paymentConfirmedAt: json['paymentConfirmedAt'] != null
          ? DateTime.tryParse(json['paymentConfirmedAt'])
          : null,
      paymentDisputed: json['paymentDisputed'] == true,
      paymentDisputeReason: json['paymentDisputeReason'] ?? '',
      farmerRated: json['farmerRated'] == true,
      buyerRated: json['buyerRated'] == true,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
