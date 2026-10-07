class MaintenanceMode {
  const MaintenanceMode({required this.enabled, this.reason});

  final bool enabled;
  final String? reason;

  factory MaintenanceMode.fromJson(Map<String, dynamic> json) {
    return MaintenanceMode(
      enabled: json['enabled'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }
}

class ActiveCountry {
  const ActiveCountry({
    required this.code,
    required this.name,
    required this.currency,
    required this.status,
    required this.defaultRadiusKm,
    required this.ocrAutoApprove,
  });

  final String code;
  final String name;
  final String currency;
  final String status;
  final int defaultRadiusKm;
  final bool ocrAutoApprove;

  factory ActiveCountry.fromJson(Map<String, dynamic> json) {
    return ActiveCountry(
      code: (json['code'] as String? ?? '').toUpperCase(),
      name: json['name'] as String? ?? '',
      currency: (json['currency'] as String? ?? 'USD').toUpperCase(),
      status: json['status'] as String? ?? 'PILOT',
      defaultRadiusKm: (json['defaultRadiusKm'] as num?)?.toInt() ?? 50,
      ocrAutoApprove: json['ocrAutoApprove'] as bool? ?? false,
    );
  }
}

class SupportedCurrency {
  const SupportedCurrency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.enabled,
  });

  final String code;
  final String symbol;
  final String name;
  final bool enabled;

  factory SupportedCurrency.fromJson(Map<String, dynamic> json) {
    return SupportedCurrency(
      code: (json['code'] as String? ?? 'USD').toUpperCase(),
      symbol: json['symbol'] as String? ?? r'$',
      name: json['name'] as String? ?? 'US Dollar',
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

class SupportedLocale {
  const SupportedLocale({
    required this.code,
    required this.name,
    required this.direction,
    required this.isDefault,
  });

  final String code;
  final String name;
  final String direction;
  final bool isDefault;

  factory SupportedLocale.fromJson(Map<String, dynamic> json) {
    return SupportedLocale(
      code: json['code'] as String? ?? 'en-US',
      name: json['name'] as String? ?? 'English (United States)',
      direction: json['direction'] as String? ?? 'ltr',
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

class ExchangePolicy {
  const ExchangePolicy({
    required this.holdDurationMinutes,
    required this.maxActiveIntentsPerUser,
    required this.ocrConfidenceThresholdPercent,
  });

  final int holdDurationMinutes;
  final int maxActiveIntentsPerUser;
  final int ocrConfidenceThresholdPercent;

  factory ExchangePolicy.fromJson(Map<String, dynamic> json) {
    return ExchangePolicy(
      holdDurationMinutes: (json['holdDurationMinutes'] as num?)?.toInt() ?? 15,
      maxActiveIntentsPerUser:
          (json['maxActiveIntentsPerUser'] as num?)?.toInt() ?? 5,
      ocrConfidenceThresholdPercent:
          (json['ocrConfidenceThresholdPercent'] as num?)?.toInt() ?? 85,
    );
  }
}

class PublishedLegalDocument {
  const PublishedLegalDocument({
    required this.slug,
    required this.title,
    required this.version,
    required this.contentDigest,
    required this.publishedAt,
  });

  final String slug;
  final String title;
  final int version;
  final String contentDigest;
  final DateTime publishedAt;

  factory PublishedLegalDocument.fromJson(Map<String, dynamic> json) {
    final slug = json['slug'];
    final title = json['title'];
    final version = json['version'];
    final digest = json['contentDigest'];
    final publishedAt = DateTime.tryParse(json['publishedAt'] as String? ?? '');
    if (slug is! String ||
        slug.trim().isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        version is! num ||
        version != version.toInt() ||
        version.toInt() <= 0 ||
        digest is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(digest) ||
        publishedAt == null) {
      throw const FormatException('Invalid published legal summary.');
    }
    return PublishedLegalDocument(
      slug: slug.trim(),
      title: title.trim(),
      version: version.toInt(),
      contentDigest: digest.toLowerCase(),
      publishedAt: publishedAt,
    );
  }
}

class PlatformBootstrap {
  const PlatformBootstrap({
    required this.maintenanceMode,
    required this.minAppVersion,
    required this.activeCountries,
    required this.supportedCurrencies,
    required this.supportedLocales,
    required this.exchangePolicy,
    required this.legalDocuments,
  });

  final MaintenanceMode maintenanceMode;
  final String minAppVersion;
  final List<ActiveCountry> activeCountries;
  final List<SupportedCurrency> supportedCurrencies;
  final List<SupportedLocale> supportedLocales;
  final ExchangePolicy exchangePolicy;
  final List<PublishedLegalDocument> legalDocuments;

  ActiveCountry? countryForCode(String code) {
    final upper = code.trim().toUpperCase();
    for (final country in activeCountries) {
      if (country.code == upper) return country;
    }
    return null;
  }

  PublishedLegalDocument? legalDocumentForSlug(String slug) {
    final normalized = slug.trim();
    for (final document in legalDocuments) {
      if (document.slug == normalized) return document;
    }
    return null;
  }

  factory PlatformBootstrap.fromJson(Map<String, dynamic> json) {
    return PlatformBootstrap(
      maintenanceMode: MaintenanceMode.fromJson(
        (json['maintenanceMode'] as Map<String, dynamic>?) ?? {},
      ),
      minAppVersion: json['minAppVersion'] as String? ?? '1.0.0',
      activeCountries:
          (json['activeCountries'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ActiveCountry.fromJson)
              .toList() ??
          const [],
      supportedCurrencies:
          (json['supportedCurrencies'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(SupportedCurrency.fromJson)
              .toList() ??
          const [],
      supportedLocales:
          (json['supportedLocales'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(SupportedLocale.fromJson)
              .toList() ??
          const [],
      exchangePolicy: ExchangePolicy.fromJson(
        (json['exchangePolicy'] as Map<String, dynamic>?) ?? {},
      ),
      legalDocuments: _parseLegalDocuments(json['legalDocuments']),
    );
  }
}

class LegalDocument {
  const LegalDocument({
    required this.slug,
    required this.title,
    required this.version,
    required this.contentMarkdown,
    required this.contentDigest,
    required this.locale,
    required this.jurisdiction,
    required this.effectiveAt,
  });

  final String slug;
  final String title;
  final int version;
  final String contentMarkdown;
  final String contentDigest;
  final String locale;
  final String jurisdiction;
  final DateTime effectiveAt;

  factory LegalDocument.fromJson(Map<String, dynamic> json) {
    final slug = json['slug'];
    final title = json['title'];
    final version = json['version'];
    final content = json['contentMarkdown'];
    final digest = json['contentDigest'];
    final locale = json['locale'];
    final jurisdiction = json['jurisdiction'];
    final effectiveAt = DateTime.tryParse(json['effectiveAt'] as String? ?? '');
    final status = json['status'];
    if (slug is! String ||
        slug.trim().isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        version is! num ||
        version != version.toInt() ||
        version.toInt() <= 0 ||
        content is! String ||
        content.trim().isEmpty ||
        digest is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(digest) ||
        locale is! String ||
        locale.trim().isEmpty ||
        jurisdiction is! String ||
        jurisdiction.trim().isEmpty ||
        effectiveAt == null ||
        status != 'published') {
      throw const FormatException('Invalid published legal document.');
    }
    return LegalDocument(
      slug: slug,
      title: title,
      version: version.toInt(),
      contentMarkdown: content,
      contentDigest: digest.toLowerCase(),
      locale: locale.trim(),
      jurisdiction: jurisdiction.trim().toUpperCase(),
      effectiveAt: effectiveAt,
    );
  }
}

List<PublishedLegalDocument> _parseLegalDocuments(Object? value) {
  if (value is! List<dynamic>) {
    throw const FormatException('Published legal documents are required.');
  }
  return List.unmodifiable(
    value.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid published legal summary.');
      }
      return PublishedLegalDocument.fromJson(item);
    }),
  );
}
