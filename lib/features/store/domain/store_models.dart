class StoreProduct {
  const StoreProduct({
    required this.productId,
    required this.platform,
    required this.productType,
    required this.title,
    required this.description,
    required this.creditsGranted,
    required this.uploadQuota,
    required this.validityDays,
    required this.validityMonths,
    required this.priceFormatted,
    required this.priceMinor,
    required this.features,
    required this.purchaseMode,
  });

  factory StoreProduct.fromJson(Map<String, dynamic> json) {
    final quota = json['uploadQuota'] ?? json['creditsGranted'] ?? 10;
    final validity = json['validityDays'] ?? 90;
    final months = json['validityMonths'] ?? 3;
    final price = json['priceFormatted'] ?? r'$20.00';
    final minor = json['priceMinor'] ?? 2000;
    final rawFeatures = json['features'];
    final features = rawFeatures is List
        ? rawFeatures.map((f) => f.toString()).toList(growable: false)
        : <String>[];

    return StoreProduct(
      productId: _requiredString(json, 'productId'),
      platform: json['platform']?.toString() ?? 'all',
      productType: json['productType']?.toString() ?? 'subscription',
      title: _requiredString(json, 'title'),
      description: _requiredString(json, 'description'),
      creditsGranted: quota is int ? quota : 10,
      uploadQuota: quota is int ? quota : 10,
      validityDays: validity is int ? validity : 90,
      validityMonths: months is int ? months : 3,
      priceFormatted: price.toString(),
      priceMinor: minor is int ? minor : 2000,
      features: features,
      purchaseMode: json['purchaseMode']?.toString() ?? 'seeded_development',
    );
  }

  final String productId;
  final String platform;
  final String productType;
  final String title;
  final String description;
  final int creditsGranted;
  final int uploadQuota;
  final int validityDays;
  final int validityMonths;
  final String priceFormatted;
  final int priceMinor;
  final List<String> features;
  final String purchaseMode;

  bool get isSubscription => productType == 'subscription';
}

class OfferingEntitlement {
  const OfferingEntitlement({
    required this.availableCredits,
    required this.uploadQuotaRemaining,
    required this.totalCreditsGranted,
    required this.creditsConsumed,
    required this.canPublish,
    required this.activeSubscription,
  });

  factory OfferingEntitlement.fromJson(Map<String, dynamic> json) =>
      OfferingEntitlement(
        availableCredits: _nonNegativeInt(json, 'availableCredits'),
        uploadQuotaRemaining: json['uploadQuotaRemaining'] is int
            ? json['uploadQuotaRemaining'] as int
            : _nonNegativeInt(json, 'availableCredits'),
        totalCreditsGranted: _nonNegativeInt(json, 'totalCreditsGranted'),
        creditsConsumed: _nonNegativeInt(json, 'creditsConsumed'),
        canPublish: _requiredBool(json, 'canPublish'),
        activeSubscription: json['activeSubscription'] == null
            ? null
            : ActiveSubscription.fromJson(
                _requiredMap(json, 'activeSubscription'),
              ),
      );

  final int availableCredits;
  final int uploadQuotaRemaining;
  final int totalCreditsGranted;
  final int creditsConsumed;
  final bool canPublish;
  final ActiveSubscription? activeSubscription;
}

class ActiveSubscription {
  const ActiveSubscription({
    required this.productId,
    required this.planTitle,
    required this.uploadQuotaTotal,
    required this.uploadQuotaRemaining,
    required this.platform,
    required this.status,
    required this.startsAt,
    required this.expiresAt,
    required this.daysRemaining,
    required this.autoRenew,
    required this.features,
  });

  factory ActiveSubscription.fromJson(Map<String, dynamic> json) {
    final expiresAt = DateTime.tryParse(_requiredString(json, 'expiresAt'));
    if (expiresAt == null) {
      throw const FormatException('Subscription expiry is invalid.');
    }
    final startsAt = DateTime.tryParse(json['startsAt']?.toString() ?? '') ?? DateTime.now();
    final rawFeatures = json['features'];
    final features = rawFeatures is List
        ? rawFeatures.map((f) => f.toString()).toList(growable: false)
        : <String>[];

    return ActiveSubscription(
      productId: _requiredString(json, 'productId'),
      planTitle: json['planTitle']?.toString() ?? 'Subscription Plan',
      uploadQuotaTotal: json['uploadQuotaTotal'] is int ? json['uploadQuotaTotal'] as int : 10,
      uploadQuotaRemaining: json['uploadQuotaRemaining'] is int ? json['uploadQuotaRemaining'] as int : 10,
      platform: json['platform']?.toString() ?? 'in_app',
      status: _requiredString(json, 'status'),
      startsAt: startsAt,
      expiresAt: expiresAt,
      daysRemaining: json['daysRemaining'] is int ? json['daysRemaining'] as int : 0,
      autoRenew: json['autoRenew'] == true,
      features: features,
    );
  }

  final String productId;
  final String planTitle;
  final int uploadQuotaTotal;
  final int uploadQuotaRemaining;
  final String platform;
  final String status;
  final DateTime startsAt;
  final DateTime expiresAt;
  final int daysRemaining;
  final bool autoRenew;
  final List<String> features;
}

class BillingReceipt {
  const BillingReceipt({
    required this.id,
    required this.receiptNumber,
    required this.productId,
    required this.planTitle,
    required this.uploadQuota,
    required this.validityDays,
    required this.amountFormatted,
    required this.taxFormatted,
    required this.totalFormatted,
    required this.cardBrand,
    required this.cardLast4,
    required this.status,
    required this.paymentMethodType,
    required this.createdAt,
  });

  factory BillingReceipt.fromJson(Map<String, dynamic> json) => BillingReceipt(
        id: _requiredString(json, 'id'),
        receiptNumber: _requiredString(json, 'receiptNumber'),
        productId: _requiredString(json, 'productId'),
        planTitle: _requiredString(json, 'planTitle'),
        uploadQuota: json['uploadQuota'] is int ? json['uploadQuota'] as int : 10,
        validityDays: json['validityDays'] is int ? json['validityDays'] as int : 90,
        amountFormatted: json['amountFormatted']?.toString() ?? r'$0.00',
        taxFormatted: json['taxFormatted']?.toString() ?? r'$0.00',
        totalFormatted: json['totalFormatted']?.toString() ?? r'$0.00',
        cardBrand: json['cardBrand']?.toString() ?? 'Visa',
        cardLast4: json['cardLast4']?.toString() ?? '4242',
        status: json['status']?.toString() ?? 'paid',
        paymentMethodType: json['paymentMethodType']?.toString() ?? 'card',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  final String id;
  final String receiptNumber;
  final String productId;
  final String planTitle;
  final int uploadQuota;
  final int validityDays;
  final String amountFormatted;
  final String taxFormatted;
  final String totalFormatted;
  final String cardBrand;
  final String cardLast4;
  final String status;
  final String paymentMethodType;
  final DateTime createdAt;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key is invalid.');
  }
  return value.trim();
}

int _nonNegativeInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) throw FormatException('$key is invalid.');
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key is invalid.');
  return value;
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) throw FormatException('$key is invalid.');
  return Map<String, dynamic>.from(value);
}
