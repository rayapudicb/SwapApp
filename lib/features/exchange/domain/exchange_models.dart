import 'dart:convert';
import 'dart:math';

/// Raised when a request or response does not conform to the exchange API
/// contract. Values from the payload are deliberately excluded from messages.
class ExchangeContractException implements Exception {
  const ExchangeContractException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum EvidenceState {
  received,
  processing,
  processed,
  rejected,
  quarantined,
  expired;

  String get wireValue => name;

  static EvidenceState fromJson(Object? value, String field) =>
      _parseEnum(values, value, field);
}

enum EligibilityDecision {
  eligible,
  ineligible,
  review;

  static EligibilityDecision fromJson(Object? value, String field) =>
      _parseEnum(values, value, field);
}

enum EntitlementState {
  eligible,
  ineligible,
  expired,
  revoked;

  String get wireValue => name;

  static EntitlementState fromJson(Object? value, String field) =>
      _parseEnum(values, value, field);
}

enum SwapIntentState {
  draft,
  published,
  paused,
  withdrawn,
  expired;

  String get wireValue => name;

  static SwapIntentState fromJson(Object? value, String field) =>
      _parseEnum(values, value, field);
}

enum AgreementState {
  agreed,
  awaitingConsent,
  readyForHandoff,
  onePartyConfirmed,
  awaitingCashConfirmation,
  reportedComplete,
  providerVerifiedComplete,
  cancelled,
  expired,
  disputed,

  // Retained only so the currently unreachable legacy presentation compiles.
  // The current participant agreement endpoint never returns these values.
  holdLocked,
  completed;

  static AgreementState fromJson(Object? value, String field) {
    if (value is! String) {
      throw ExchangeContractException('$field must be a string.');
    }
    return switch (value) {
      'agreed' => agreed,
      'awaiting_consent' => awaitingConsent,
      'ready_for_handoff' => readyForHandoff,
      'one_party_confirmed' => onePartyConfirmed,
      'awaiting_cash_confirmation' => awaitingCashConfirmation,
      'reported_complete' => reportedComplete,
      'provider_verified_complete' => providerVerifiedComplete,
      'cancelled' => cancelled,
      'expired' => expired,
      'disputed' => disputed,
      _ => throw ExchangeContractException('$field has an unsupported value.'),
    };
  }
}

enum AgreementCashRole {
  payer,
  receiver;

  static AgreementCashRole fromJson(Object? value, String field) =>
      _parseEnum(values, value, field);
}

class AgreementCashSettlement {
  const AgreementCashSettlement({
    required this.role,
    required this.amountMinor,
    required this.currency,
    required this.youConfirmed,
    required this.counterpartyConfirmed,
  });

  final AgreementCashRole role;
  final int amountMinor;
  final String currency;
  final bool youConfirmed;
  final bool counterpartyConfirmed;

  factory AgreementCashSettlement.fromJson(Map<String, dynamic> json) {
    _expectKeys(json, const {
      'role',
      'amountMinor',
      'currency',
      'status',
      'youConfirmed',
      'counterpartyConfirmed',
    }, 'agreement cash settlement');
    final amount = json['amountMinor'];
    final currency = _requiredString(json, 'currency').toUpperCase();
    if (amount is! int ||
        amount < 1 ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(currency) ||
        json['status'] != 'participant_reported_unprotected') {
      throw const ExchangeContractException(
        'The agreement cash settlement is invalid.',
      );
    }
    return AgreementCashSettlement(
      role: AgreementCashRole.fromJson(json['role'], 'cashSettlement.role'),
      amountMinor: amount,
      currency: currency,
      youConfirmed: _requiredBool(json, 'youConfirmed'),
      counterpartyConfirmed: _requiredBool(json, 'counterpartyConfirmed'),
    );
  }
}

class EventPresenceGrantRequest {
  EventPresenceGrantRequest({
    required this.contextRef,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.observedAt,
    String? deviceIntegrityToken,
  }) : _deviceIntegrityToken = deviceIntegrityToken {
    if (!_ticketmasterContextRefPattern.hasMatch(contextRef)) {
      throw const ExchangeContractException(
        'contextRef must be a supported Ticketmaster event reference.',
      );
    }
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw const ExchangeContractException(
        'latitude must be between -90 and 90.',
      );
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw const ExchangeContractException(
        'longitude must be between -180 and 180.',
      );
    }
    if (!accuracyMeters.isFinite ||
        accuracyMeters < 0 ||
        accuracyMeters > 100) {
      throw const ExchangeContractException(
        'accuracyMeters must be between 0 and 100.',
      );
    }
    if (deviceIntegrityToken != null &&
        (deviceIntegrityToken.isEmpty || deviceIntegrityToken.length > 4096)) {
      throw const ExchangeContractException(
        'deviceIntegrityToken has an invalid length.',
      );
    }
  }

  final String contextRef;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime observedAt;
  final String? _deviceIntegrityToken;

  Map<String, dynamic> toJson() => {
    'contextRef': contextRef,
    'latitude': latitude,
    'longitude': longitude,
    'accuracyMeters': accuracyMeters,
    'observedAt': _toWireDateTime(observedAt),
    if (_deviceIntegrityToken != null)
      'deviceIntegrityToken': _deviceIntegrityToken,
  };

  @override
  String toString() =>
      'EventPresenceGrantRequest(contextRef: $contextRef, location: [REDACTED], '
      'deviceIntegrityToken: [REDACTED])';
}

class EventPresenceGrant {
  EventPresenceGrant._({
    required String presenceGrantRef,
    required this.contextRef,
    required this.issuedAt,
    required this.expiresAt,
    required this.policyVersion,
  }) : _presenceGrantRef = presenceGrantRef;

  final String _presenceGrantRef;
  final String contextRef;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String policyVersion;

  bool isUsableAt(DateTime now) => expiresAt.toUtc().isAfter(now.toUtc());

  /// Serializes the opaque capability only into an immediately-issued command.
  ///
  /// The raw reference is deliberately not exposed as a readable model field.
  Map<String, dynamic> toCommandJson() => {
    'presenceGrantRef': _presenceGrantRef,
  };

  factory EventPresenceGrant.fromJson(Map<String, dynamic> json) {
    _expectKeys(json, const {
      'presenceGrantRef',
      'contextRef',
      'status',
      'issuedAt',
      'expiresAt',
      'policyVersion',
    }, 'event presence grant');
    final reference = _requiredString(json, 'presenceGrantRef');
    final contextRef = _requiredString(json, 'contextRef');
    final issuedAt = _requiredDateTime(json, 'issuedAt');
    final expiresAt = _requiredDateTime(json, 'expiresAt');
    if (!_presenceGrantRefPattern.hasMatch(reference) ||
        !_ticketmasterContextRefPattern.hasMatch(contextRef) ||
        json['status'] != 'eligible' ||
        !expiresAt.isAfter(issuedAt)) {
      throw const ExchangeContractException(
        'The event presence grant response is invalid.',
      );
    }
    final policyVersion = _requiredString(json, 'policyVersion');
    _requireMaxLength(policyVersion, 'policyVersion', 64);
    return EventPresenceGrant._(
      presenceGrantRef: reference,
      contextRef: contextRef,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      policyVersion: policyVersion,
    );
  }

  @override
  String toString() =>
      'EventPresenceGrant(contextRef: $contextRef, reference: [REDACTED], '
      'expiresAt: $expiresAt, policyVersion: $policyVersion)';
}

class RevealedEntitlement {
  const RevealedEntitlement({
    required this.id,
    required this.section,
    required this.row,
    required this.seat,
    this.barcodeValue,
    this.transferUrl,
  });

  final String id;
  final String section;
  final String row;
  final String seat;
  final String? barcodeValue;
  final String? transferUrl;

  factory RevealedEntitlement.fromJson(Map<String, dynamic> json) {
    return RevealedEntitlement(
      id: json['id'] as String? ?? '',
      section: json['section'] as String? ?? '',
      row: json['row'] as String? ?? '',
      seat: json['seat'] as String? ?? '',
      barcodeValue: json['barcodeValue'] as String?,
      transferUrl: json['transferUrl'] as String?,
    );
  }
}

class SwapAgreement {
  const SwapAgreement({
    required this.id,
    required this.swapRequestId,
    required this.contextRef,
    required this.state,
    required this.status,
    required this.isPartyA,
    required this.youConsented,
    required this.counterpartyConsented,
    required this.youConfirmedHandoff,
    required this.counterpartyConfirmedHandoff,
    required this.cashSettlement,
    required this.holdExpiresAt,
    required this.completedAt,
    required this.cancelledAt,
    required this.disputedAt,
    required this.disputeReason,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String swapRequestId;
  final String contextRef;
  final AgreementState state;
  final String status;
  final bool isPartyA;
  final bool youConsented;
  final bool counterpartyConsented;
  final bool youConfirmedHandoff;
  final bool counterpartyConfirmedHandoff;
  final AgreementCashSettlement? cashSettlement;
  final DateTime holdExpiresAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? disputedAt;
  final String? disputeReason;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isComplete =>
      state == AgreementState.reportedComplete ||
      state == AgreementState.providerVerifiedComplete;

  bool get myLegConfirmed => youConfirmedHandoff;
  bool get counterpartyLegConfirmed => counterpartyConfirmedHandoff;
  RevealedEntitlement? get revealedEntitlement => null;

  factory SwapAgreement.fromJson(Map<String, dynamic> json) {
    _expectKeys(json, const {
      'id',
      'swapRequestId',
      'contextRef',
      'state',
      'status',
      'participantAId',
      'participantBId',
      'isPartyA',
      'consents',
      'handoffConfirmations',
      'cashSettlement',
      'holdExpiresAt',
      'completedAt',
      'cancelledAt',
      'disputedAt',
      'disputeReason',
      'version',
      'createdAt',
      'updatedAt',
    }, 'swap agreement');
    final id = _requiredString(json, 'id');
    final requestId = _requiredString(json, 'swapRequestId');
    final participantAId = _requiredString(json, 'participantAId');
    final participantBId = _requiredString(json, 'participantBId');
    _requireUuid(id, 'agreement.id');
    _requireUuid(requestId, 'agreement.swapRequestId');
    _requireUuid(participantAId, 'agreement.participantAId');
    _requireUuid(participantBId, 'agreement.participantBId');
    final contextRef = _requiredString(json, 'contextRef');
    if (!_ticketmasterContextRefPattern.hasMatch(contextRef)) {
      throw const ExchangeContractException(
        'agreement.contextRef is unsupported.',
      );
    }
    final state = AgreementState.fromJson(json['state'], 'agreement.state');
    final status = _requiredString(json, 'status');
    if (status.toLowerCase() != _agreementWireValue(state)) {
      throw const ExchangeContractException(
        'agreement status and state are inconsistent.',
      );
    }
    final isPartyA = _requiredBool(json, 'isPartyA');
    final consents = _requiredMap(json, 'consents');
    _expectKeys(consents, const {
      'participantA',
      'participantB',
    }, 'agreement consents');
    final handoffs = _requiredMap(json, 'handoffConfirmations');
    _expectKeys(handoffs, const {
      'participantA',
      'participantB',
    }, 'agreement handoff confirmations');
    final rawCash = json['cashSettlement'];
    if (rawCash != null && rawCash is! Map) {
      throw const ExchangeContractException(
        'cashSettlement must be an object or null.',
      );
    }
    return SwapAgreement(
      id: id,
      swapRequestId: requestId,
      contextRef: contextRef,
      state: state,
      status: status,
      isPartyA: isPartyA,
      youConsented: _requiredBool(
        consents,
        isPartyA ? 'participantA' : 'participantB',
      ),
      counterpartyConsented: _requiredBool(
        consents,
        isPartyA ? 'participantB' : 'participantA',
      ),
      youConfirmedHandoff: _requiredBool(
        handoffs,
        isPartyA ? 'participantA' : 'participantB',
      ),
      counterpartyConfirmedHandoff: _requiredBool(
        handoffs,
        isPartyA ? 'participantB' : 'participantA',
      ),
      cashSettlement: rawCash == null
          ? null
          : AgreementCashSettlement.fromJson(
              Map<String, dynamic>.from(rawCash),
            ),
      holdExpiresAt: _requiredDateTime(json, 'holdExpiresAt'),
      completedAt: _nullableDateTime(json, 'completedAt'),
      cancelledAt: _nullableDateTime(json, 'cancelledAt'),
      disputedAt: _nullableDateTime(json, 'disputedAt'),
      disputeReason: _nullableString(json, 'disputeReason'),
      version: _requiredPositiveInt(json, 'version'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

String _agreementWireValue(AgreementState state) => switch (state) {
  AgreementState.agreed => 'agreed',
  AgreementState.awaitingConsent => 'awaiting_consent',
  AgreementState.readyForHandoff => 'ready_for_handoff',
  AgreementState.onePartyConfirmed => 'one_party_confirmed',
  AgreementState.awaitingCashConfirmation => 'awaiting_cash_confirmation',
  AgreementState.reportedComplete => 'reported_complete',
  AgreementState.providerVerifiedComplete => 'provider_verified_complete',
  AgreementState.cancelled => 'cancelled',
  AgreementState.expired => 'expired',
  AgreementState.disputed => 'disputed',
  AgreementState.holdLocked ||
  AgreementState.completed => throw const ExchangeContractException(
    'Legacy agreement states are not accepted from the server.',
  ),
};

enum SwapIntentOfferedSource {
  providerVerified('provider_verified'),
  photoChecked('photo_checked');

  const SwapIntentOfferedSource(this.wireValue);

  final String wireValue;

  static SwapIntentOfferedSource fromJson(Object? value, String field) {
    for (final source in values) {
      if (source.wireValue == value) return source;
    }
    throw ExchangeContractException('$field has an unsupported value.');
  }
}

enum CashDifferenceDirection {
  none,
  willPay,
  wantsToReceive;

  String get wireValue => switch (this) {
    none => 'none',
    willPay => 'will_pay',
    wantsToReceive => 'wants_to_receive',
  };

  static CashDifferenceDirection fromJson(Object? value, String field) {
    for (final direction in values) {
      if (direction.wireValue == value) return direction;
    }
    throw ExchangeContractException('$field has an unsupported value.');
  }
}

enum SwapIntentActorType {
  participant,
  operator,
  system;

  static SwapIntentActorType fromJson(Object? value, String field) =>
      _parseEnum(values, value, field);
}

class EvidenceSubmissionRequest {
  EvidenceSubmissionRequest({
    required this.verticalKey,
    required this.providerKey,
    required this.contextRef,
    required this.evidenceType,
    required String protectedObjectRef,
    this.retentionUntil,
  }) : _protectedObjectRef = protectedObjectRef {
    _requirePattern(
      verticalKey,
      'verticalKey',
      _verticalKeyPattern,
      maxLength: 64,
    );
    _requirePattern(
      providerKey,
      'providerKey',
      _providerKeyPattern,
      maxLength: 128,
    );
    _requireLength(contextRef, 'contextRef', min: 1, max: 255);
    _requirePattern(
      evidenceType,
      'evidenceType',
      _verticalKeyPattern,
      maxLength: 64,
    );
    _requireLength(protectedObjectRef, 'protectedObjectRef', min: 8, max: 512);
    if (!_protectedObjectRefPattern.hasMatch(protectedObjectRef)) {
      throw const ExchangeContractException(
        'protectedObjectRef does not match the approved reference format.',
      );
    }
  }

  final String verticalKey;
  final String providerKey;
  final String contextRef;
  final String evidenceType;
  final String _protectedObjectRef;
  final DateTime? retentionUntil;

  Map<String, dynamic> toJson() => {
    'verticalKey': verticalKey,
    'providerKey': providerKey,
    'contextRef': contextRef,
    'evidenceType': evidenceType,
    'protectedObjectRef': _protectedObjectRef,
    'retentionUntil': retentionUntil == null
        ? null
        : _toWireDateTime(retentionUntil!),
  };

  @override
  String toString() =>
      'EvidenceSubmissionRequest(verticalKey: $verticalKey, '
      'providerKey: $providerKey, evidenceType: $evidenceType, '
      'protectedObjectRef: [REDACTED])';
}

class CreateSwapIntentRequest {
  CreateSwapIntentRequest({
    this.offeredEntitlementId,
    this.offeredTicketBundleId,
    required List<String> desiredAssignmentLabels,
    required this.acceptsAnyAssignment,
    required this.expiresAt,
    this.cashDifferenceDirection = CashDifferenceDirection.none,
    this.cashDifferenceAmountMinor,
    this.cashDifferenceCurrency,
  }) : desiredAssignmentLabels = List.unmodifiable(desiredAssignmentLabels) {
    if ((offeredEntitlementId == null) == (offeredTicketBundleId == null)) {
      throw const ExchangeContractException(
        'Choose exactly one ticket to offer.',
      );
    }
    if (offeredEntitlementId != null) {
      _requireUuid(offeredEntitlementId!, 'offeredEntitlementId');
    }
    if (offeredTicketBundleId != null) {
      _requireUuid(offeredTicketBundleId!, 'offeredTicketBundleId');
    }
    _validateAssignmentLabels(
      this.desiredAssignmentLabels,
      acceptsAnyAssignment: acceptsAnyAssignment,
    );
    _validateCashDifference(
      cashDifferenceDirection,
      cashDifferenceAmountMinor,
      cashDifferenceCurrency,
    );
  }

  final String? offeredEntitlementId;
  final String? offeredTicketBundleId;
  final List<String> desiredAssignmentLabels;
  final bool acceptsAnyAssignment;
  final DateTime expiresAt;
  final CashDifferenceDirection cashDifferenceDirection;
  final int? cashDifferenceAmountMinor;
  final String? cashDifferenceCurrency;

  Map<String, dynamic> toJson() => {
    if (offeredEntitlementId != null)
      'offeredEntitlementId': offeredEntitlementId,
    if (offeredTicketBundleId != null)
      'offeredTicketBundleId': offeredTicketBundleId,
    'desiredAssignmentLabels': desiredAssignmentLabels,
    'acceptsAnyAssignment': acceptsAnyAssignment,
    'cashDifferenceDirection': cashDifferenceDirection.wireValue,
    if (cashDifferenceAmountMinor != null)
      'cashDifferenceAmountMinor': cashDifferenceAmountMinor,
    if (cashDifferenceCurrency != null)
      'cashDifferenceCurrency': cashDifferenceCurrency!.toUpperCase(),
    'expiresAt': _toWireDateTime(expiresAt),
  };
}

class UpdateSwapIntentRequest {
  UpdateSwapIntentRequest({
    required List<String> desiredAssignmentLabels,
    required this.acceptsAnyAssignment,
    required this.expiresAt,
    required this.expectedVersion,
    this.cashDifferenceDirection = CashDifferenceDirection.none,
    this.cashDifferenceAmountMinor,
    this.cashDifferenceCurrency,
  }) : desiredAssignmentLabels = List.unmodifiable(desiredAssignmentLabels) {
    _validateAssignmentLabels(
      this.desiredAssignmentLabels,
      acceptsAnyAssignment: acceptsAnyAssignment,
    );
    _requirePositiveVersion(expectedVersion, 'expectedVersion');
    _validateCashDifference(
      cashDifferenceDirection,
      cashDifferenceAmountMinor,
      cashDifferenceCurrency,
    );
  }

  final List<String> desiredAssignmentLabels;
  final bool acceptsAnyAssignment;
  final DateTime expiresAt;
  final int expectedVersion;
  final CashDifferenceDirection cashDifferenceDirection;
  final int? cashDifferenceAmountMinor;
  final String? cashDifferenceCurrency;

  Map<String, dynamic> toJson() => {
    'desiredAssignmentLabels': desiredAssignmentLabels,
    'acceptsAnyAssignment': acceptsAnyAssignment,
    'cashDifferenceDirection': cashDifferenceDirection.wireValue,
    if (cashDifferenceAmountMinor != null)
      'cashDifferenceAmountMinor': cashDifferenceAmountMinor,
    if (cashDifferenceCurrency != null)
      'cashDifferenceCurrency': cashDifferenceCurrency!.toUpperCase(),
    'expiresAt': _toWireDateTime(expiresAt),
    'expectedVersion': expectedVersion,
  };
}

class EligibilityProjection {
  const EligibilityProjection({
    required this.id,
    required this.decision,
    required this.mode,
    required this.policyVersion,
    required this.adapterVersion,
    required this.reasonCode,
    required this.decidedAt,
    required this.validUntil,
    required this.revokedAt,
  });

  final String id;
  final EligibilityDecision decision;
  final String mode;
  final String policyVersion;
  final String adapterVersion;
  final String reasonCode;
  final DateTime decidedAt;
  final DateTime validUntil;
  final DateTime? revokedAt;

  factory EligibilityProjection.fromJson(Map<String, dynamic> json) {
    _expectKeys(json, const {
      'id',
      'decision',
      'mode',
      'policyVersion',
      'adapterVersion',
      'reasonCode',
      'decidedAt',
      'validUntil',
      'revokedAt',
    }, 'eligibility');
    final id = _requiredString(json, 'id');
    _requireUuid(id, 'eligibility.id');
    final mode = _requiredString(json, 'mode');
    final policyVersion = _requiredString(json, 'policyVersion');
    final adapterVersion = _requiredString(json, 'adapterVersion');
    final reasonCode = _requiredString(json, 'reasonCode');
    _requireMaxLength(mode, 'eligibility.mode', 64);
    _requireMaxLength(policyVersion, 'eligibility.policyVersion', 64);
    _requireMaxLength(adapterVersion, 'eligibility.adapterVersion', 64);
    _requireMaxLength(reasonCode, 'eligibility.reasonCode', 128);
    return EligibilityProjection(
      id: id,
      decision: EligibilityDecision.fromJson(
        json['decision'],
        'eligibility.decision',
      ),
      mode: mode,
      policyVersion: policyVersion,
      adapterVersion: adapterVersion,
      reasonCode: reasonCode,
      decidedAt: _requiredDateTime(json, 'decidedAt'),
      validUntil: _requiredDateTime(json, 'validUntil'),
      revokedAt: _nullableDateTime(json, 'revokedAt'),
    );
  }
}

class EvidenceProjection {
  const EvidenceProjection({
    required this.id,
    required this.verticalKey,
    required this.providerKey,
    required this.contextRef,
    required this.evidenceType,
    required this.state,
    required this.retentionUntil,
    required this.createdAt,
    required this.latestEligibility,
  });

  final String id;
  final String verticalKey;
  final String providerKey;
  final String contextRef;
  final String evidenceType;
  final EvidenceState state;
  final DateTime? retentionUntil;
  final DateTime createdAt;
  final EligibilityProjection? latestEligibility;

  factory EvidenceProjection.fromJson(Map<String, dynamic> json) {
    _expectKeys(json, const {
      'id',
      'verticalKey',
      'providerKey',
      'contextRef',
      'evidenceType',
      'state',
      'retentionUntil',
      'createdAt',
      'latestEligibility',
    }, 'evidence');
    final id = _requiredString(json, 'id');
    _requireUuid(id, 'evidence.id');
    return EvidenceProjection(
      id: id,
      verticalKey: _requiredString(json, 'verticalKey'),
      providerKey: _requiredString(json, 'providerKey'),
      contextRef: _requiredString(json, 'contextRef'),
      evidenceType: _requiredString(json, 'evidenceType'),
      state: EvidenceState.fromJson(json['state'], 'evidence.state'),
      retentionUntil: _nullableDateTime(json, 'retentionUntil'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      latestEligibility: json['latestEligibility'] == null
          ? null
          : EligibilityProjection.fromJson(
              _requiredMap(json, 'latestEligibility'),
            ),
    );
  }
}

class EntitlementProjection {
  const EntitlementProjection({
    required this.id,
    required this.verticalKey,
    required this.providerKey,
    required this.contextRef,
    required this.assignmentLabel,
    required this.state,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.eligibility,
  });

  final String id;
  final String verticalKey;
  final String providerKey;
  final String contextRef;
  final String assignmentLabel;
  final EntitlementState state;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final EligibilityProjection eligibility;

  factory EntitlementProjection.fromJson(Map<String, dynamic> json) {
    _expectKeys(json, const {
      'id',
      'verticalKey',
      'providerKey',
      'contextRef',
      'assignmentLabel',
      'state',
      'version',
      'createdAt',
      'updatedAt',
      'eligibility',
    }, 'entitlement');
    final id = _requiredString(json, 'id');
    final assignmentLabel = _requiredString(json, 'assignmentLabel');
    _requireUuid(id, 'entitlement.id');
    _requireMaxLength(assignmentLabel, 'entitlement.assignmentLabel', 128);
    return EntitlementProjection(
      id: id,
      verticalKey: _requiredString(json, 'verticalKey'),
      providerKey: _requiredString(json, 'providerKey'),
      contextRef: _requiredString(json, 'contextRef'),
      assignmentLabel: assignmentLabel,
      state: EntitlementState.fromJson(json['state'], 'entitlement.state'),
      version: _requiredPositiveInt(json, 'version'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      eligibility: EligibilityProjection.fromJson(
        _requiredMap(json, 'eligibility'),
      ),
    );
  }
}

class SwapIntentProjection {
  const SwapIntentProjection({
    required this.id,
    required this.state,
    required this.version,
    required this.desiredAssignmentLabels,
    required this.acceptsAnyAssignment,
    required this.expiresAt,
    required this.publishedAt,
    required this.pausedAt,
    required this.withdrawnAt,
    required this.createdAt,
    required this.updatedAt,
    this.offeredSource = SwapIntentOfferedSource.providerVerified,
    required this.offeredEntitlement,
    this.offeredTicketBundle,
    this.cashDifference = const PostCashDifference(
      direction: CashDifferenceDirection.none,
      amountMinor: null,
      currency: null,
      status: 'proposal_only',
      paymentProtected: false,
    ),
  });

  final String id;
  final SwapIntentState state;
  final int version;
  final List<String> desiredAssignmentLabels;
  final bool acceptsAnyAssignment;
  final DateTime expiresAt;
  final DateTime? publishedAt;
  final DateTime? pausedAt;
  final DateTime? withdrawnAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SwapIntentOfferedSource offeredSource;
  final EntitlementProjection? offeredEntitlement;
  final PhotoTicketBundleProjection? offeredTicketBundle;
  final PostCashDifference cashDifference;

  factory SwapIntentProjection.fromJson(Map<String, dynamic> json) {
    _expectKeys(json, const {
      'id',
      'state',
      'version',
      'desiredAssignmentLabels',
      'acceptsAnyAssignment',
      'expiresAt',
      'publishedAt',
      'pausedAt',
      'withdrawnAt',
      'createdAt',
      'updatedAt',
      'offeredSource',
      'offeredEntitlement',
      'offeredTicketBundle',
      'cashDifference',
    }, 'intent');
    final id = _requiredString(json, 'id');
    _requireUuid(id, 'intent.id');
    final labels = _requiredStringList(json, 'desiredAssignmentLabels');
    if (labels.length > 20) {
      throw const ExchangeContractException(
        'intent.desiredAssignmentLabels exceeds 20 items.',
      );
    }
    final offeredSource = SwapIntentOfferedSource.fromJson(
      json['offeredSource'],
      'intent.offeredSource',
    );
    final offeredEntitlement = json['offeredEntitlement'] == null
        ? null
        : EntitlementProjection.fromJson(
            _requiredMap(json, 'offeredEntitlement'),
          );
    final offeredTicketBundle = json['offeredTicketBundle'] == null
        ? null
        : PhotoTicketBundleProjection.fromJson(
            _requiredMap(json, 'offeredTicketBundle'),
          );
    if ((offeredSource == SwapIntentOfferedSource.providerVerified &&
            (offeredEntitlement == null || offeredTicketBundle != null)) ||
        (offeredSource == SwapIntentOfferedSource.photoChecked &&
            (offeredTicketBundle == null || offeredEntitlement != null))) {
      throw const ExchangeContractException(
        'intent offered source is inconsistent with its ticket.',
      );
    }
    return SwapIntentProjection(
      id: id,
      state: SwapIntentState.fromJson(json['state'], 'intent.state'),
      version: _requiredPositiveInt(json, 'version'),
      desiredAssignmentLabels: labels,
      acceptsAnyAssignment: _requiredBool(json, 'acceptsAnyAssignment'),
      expiresAt: _requiredDateTime(json, 'expiresAt'),
      publishedAt: _nullableDateTime(json, 'publishedAt'),
      pausedAt: _nullableDateTime(json, 'pausedAt'),
      withdrawnAt: _nullableDateTime(json, 'withdrawnAt'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      offeredSource: offeredSource,
      offeredEntitlement: offeredEntitlement,
      offeredTicketBundle: offeredTicketBundle,
      cashDifference: PostCashDifference.fromJson(
        _requiredMap(json, 'cashDifference'),
      ),
    );
  }
}

class PhotoTicketBundleProjection {
  const PhotoTicketBundleProjection({
    required this.id,
    required this.contextRef,
    required this.eventTitle,
    required this.startsAt,
    required this.timezone,
    required this.venueName,
    required this.sectionLabel,
    required this.rowLabel,
    required this.seatLabels,
    required this.quantity,
    required this.state,
    required this.version,
  });

  final String id;
  final String contextRef;
  final String eventTitle;
  final DateTime? startsAt;
  final String? timezone;
  final String? venueName;
  final String? sectionLabel;
  final String? rowLabel;
  final List<String> seatLabels;
  final int quantity;
  final String state;
  final int version;

  factory PhotoTicketBundleProjection.fromJson(Map<String, dynamic> json) {
    _expectKeys(json, const {
      'id',
      'contextRef',
      'eventTitle',
      'startsAt',
      'timezone',
      'venueName',
      'sectionLabel',
      'rowLabel',
      'seatLabels',
      'quantity',
      'trustLevel',
      'ownershipVerified',
      'transferabilityVerified',
      'state',
      'version',
      'createdAt',
      'updatedAt',
    }, 'photo ticket bundle');
    final id = _requiredString(json, 'id');
    _requireUuid(id, 'photoTicketBundle.id');
    final seats = _requiredStringList(json, 'seatLabels');
    final quantity = _requiredPositiveInt(json, 'quantity');
    if (json['trustLevel'] != 'photo_checked' ||
        json['ownershipVerified'] != false ||
        json['transferabilityVerified'] != false ||
        !const {'active', 'revoked', 'expired'}.contains(json['state']) ||
        seats.length != quantity ||
        seats.isEmpty ||
        seats.length > 3) {
      throw const ExchangeContractException(
        'photo ticket bundle trust fields are invalid.',
      );
    }
    _requiredDateTime(json, 'createdAt');
    _requiredDateTime(json, 'updatedAt');
    return PhotoTicketBundleProjection(
      id: id,
      contextRef: _requiredString(json, 'contextRef'),
      eventTitle: _requiredString(json, 'eventTitle'),
      startsAt: _nullableDateTime(json, 'startsAt'),
      timezone: _nullableString(json, 'timezone'),
      venueName: _nullableString(json, 'venueName'),
      sectionLabel: _nullableString(json, 'sectionLabel'),
      rowLabel: _nullableString(json, 'rowLabel'),
      seatLabels: seats,
      quantity: quantity,
      state: _requiredString(json, 'state'),
      version: _requiredPositiveInt(json, 'version'),
    );
  }
}

class PostCashDifference {
  const PostCashDifference({
    required this.direction,
    required this.amountMinor,
    required this.currency,
    required this.status,
    required this.paymentProtected,
  });

  final CashDifferenceDirection direction;
  final int? amountMinor;
  final String? currency;
  final String status;
  final bool paymentProtected;

  factory PostCashDifference.fromJson(Map<String, dynamic> json) {
    _expectKeys(json, const {
      'direction',
      'amountMinor',
      'currency',
      'status',
      'paymentProtected',
    }, 'cash difference');
    final direction = CashDifferenceDirection.fromJson(
      json['direction'],
      'cashDifference.direction',
    );
    final amount = json['amountMinor'];
    final currency = json['currency'];
    if ((amount != null &&
            (amount is! int || amount < 1 || amount > 100000000)) ||
        (currency != null &&
            (currency is! String ||
                !RegExp(r'^[A-Z]{3}$').hasMatch(currency))) ||
        json['status'] != 'proposal_only' ||
        json['paymentProtected'] != false ||
        (direction == CashDifferenceDirection.none &&
            (amount != null || currency != null)) ||
        (direction != CashDifferenceDirection.none &&
            (amount == null || currency == null))) {
      throw const ExchangeContractException(
        'cash difference projection is invalid.',
      );
    }
    return PostCashDifference(
      direction: direction,
      amountMinor: amount as int?,
      currency: currency as String?,
      status: 'proposal_only',
      paymentProtected: false,
    );
  }
}

class SwapIntentTimelineItem {
  const SwapIntentTimelineItem({
    required this.id,
    required this.fromState,
    required this.toState,
    required this.actorType,
    required this.reasonCode,
    required this.correlationId,
    required this.occurredAt,
  });

  final String id;
  final String? fromState;
  final String toState;
  final SwapIntentActorType actorType;
  final String reasonCode;
  final String correlationId;
  final DateTime occurredAt;

  factory SwapIntentTimelineItem.fromJson(Map<String, dynamic> json) {
    _expectKeys(json, const {
      'id',
      'fromState',
      'toState',
      'actorType',
      'reasonCode',
      'correlationId',
      'occurredAt',
    }, 'timeline item');
    final id = _requiredString(json, 'id');
    final correlationId = _requiredString(json, 'correlationId');
    _requireUuid(id, 'timeline.id');
    _requireUuid(correlationId, 'timeline.correlationId');
    return SwapIntentTimelineItem(
      id: id,
      fromState: _nullableString(json, 'fromState'),
      toState: _requiredString(json, 'toState'),
      actorType: SwapIntentActorType.fromJson(
        json['actorType'],
        'timeline.actorType',
      ),
      reasonCode: _requiredString(json, 'reasonCode'),
      correlationId: correlationId,
      occurredAt: _requiredDateTime(json, 'occurredAt'),
    );
  }
}

class ExchangePage<T> {
  const ExchangePage({required this.items, required this.total});

  final List<T> items;
  final int total;
}

class SwapIntentDetail {
  const SwapIntentDetail({required this.intent, required this.timeline});

  final SwapIntentProjection intent;
  final List<SwapIntentTimelineItem> timeline;
}

/// Creates a cryptographically secure, URL-safe 256-bit command replay key.
String newExchangeIdempotencyKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

void validateExchangeIdempotencyKey(String value) {
  if (value.length < 16 ||
      value.length > 255 ||
      !_idempotencyKeyPattern.hasMatch(value)) {
    throw const ExchangeContractException(
      'Idempotency key must be 16-255 URL-safe characters.',
    );
  }
}

void validateExchangePage({required int limit, required int offset}) {
  if (limit < 1 || limit > 100) {
    throw const ExchangeContractException('limit must be between 1 and 100.');
  }
  if (offset < 0 || offset > 1000000) {
    throw const ExchangeContractException(
      'offset must be between 0 and 1000000.',
    );
  }
}

void validateSwapIntentExpiry(DateTime expiresAt, {required DateTime now}) {
  final remaining = expiresAt.toUtc().difference(now.toUtc());
  if (remaining < const Duration(minutes: 5) ||
      remaining > const Duration(days: 90)) {
    throw const ExchangeContractException(
      'expiresAt must be between 5 minutes and 90 days from now.',
    );
  }
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final RegExp _rfc3339Pattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$',
);
final RegExp _verticalKeyPattern = RegExp(r'^[a-z][a-z0-9_-]{0,63}$');
final RegExp _providerKeyPattern = RegExp(r'^[a-z][a-z0-9_-]{0,127}$');
final RegExp _ticketmasterContextRefPattern = RegExp(
  r'^ticketmaster:event:[A-Za-z0-9_-]{1,200}$',
);
final RegExp _presenceGrantRefPattern = RegExp(r'^presence://[0-9a-f]{48}$');
final RegExp _protectedObjectRefPattern = RegExp(
  r'^(evidence|provider-connection)://[A-Za-z0-9._/-]{8,480}$',
);
final RegExp _idempotencyKeyPattern = RegExp(r'^[A-Za-z0-9._~-]+$');

T _parseEnum<T extends Enum>(List<T> values, Object? value, String field) {
  if (value is String) {
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
  }
  throw ExchangeContractException('$field has an unsupported value.');
}

void _expectKeys(
  Map<String, dynamic> json,
  Set<String> keys,
  String objectName,
) {
  if (json.length != keys.length ||
      json.keys.any((key) => !keys.contains(key))) {
    throw ExchangeContractException('$objectName has unexpected fields.');
  }
  for (final key in keys) {
    if (!json.containsKey(key)) {
      throw ExchangeContractException('$objectName.$key is required.');
    }
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw ExchangeContractException('$key must be a string.');
  }
  return value;
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw ExchangeContractException('$key must be a string or null.');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw ExchangeContractException('$key must be a boolean.');
  }
  return value;
}

int _requiredPositiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 1) {
    throw ExchangeContractException('$key must be a positive integer.');
  }
  return value;
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) {
    throw ExchangeContractException('$key must be an object.');
  }
  return Map<String, dynamic>.from(value);
}

List<String> _requiredStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw ExchangeContractException('$key must be a string array.');
  }
  return List<String>.unmodifiable(value.cast<String>());
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  if (!_rfc3339Pattern.hasMatch(value)) {
    throw ExchangeContractException('$key must be an RFC 3339 timestamp.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw ExchangeContractException('$key must be an RFC 3339 timestamp.');
  }
  return parsed;
}

DateTime? _nullableDateTime(Map<String, dynamic> json, String key) {
  if (json[key] == null) return null;
  return _requiredDateTime(json, key);
}

void _requireUuid(String value, String field) {
  if (!_uuidPattern.hasMatch(value)) {
    throw ExchangeContractException('$field must be a UUID.');
  }
}

void _requirePositiveVersion(int value, String field) {
  if (value < 1) {
    throw ExchangeContractException('$field must be at least 1.');
  }
}

void _requireLength(
  String value,
  String field, {
  required int min,
  required int max,
}) {
  if (value.length < min || value.length > max) {
    throw ExchangeContractException('$field must be $min-$max characters.');
  }
}

void _requireMaxLength(String value, String field, int max) {
  if (value.length > max) {
    throw ExchangeContractException('$field must be at most $max characters.');
  }
}

void _requirePattern(
  String value,
  String field,
  RegExp pattern, {
  required int maxLength,
}) {
  if (value.length > maxLength || !pattern.hasMatch(value)) {
    throw ExchangeContractException('$field has an invalid format.');
  }
}

void _validateAssignmentLabels(
  List<String> labels, {
  required bool acceptsAnyAssignment,
}) {
  if (labels.length > 20) {
    throw const ExchangeContractException(
      'desiredAssignmentLabels cannot exceed 20 items.',
    );
  }
  if (labels.toSet().length != labels.length) {
    throw const ExchangeContractException(
      'desiredAssignmentLabels must contain unique values.',
    );
  }
  if (!acceptsAnyAssignment && labels.isEmpty) {
    throw const ExchangeContractException(
      'Select at least one desired assignment or accept any assignment.',
    );
  }
  for (final label in labels) {
    _requireLength(label, 'desiredAssignmentLabels item', min: 1, max: 128);
  }
}

void _validateCashDifference(
  CashDifferenceDirection direction,
  int? amountMinor,
  String? currency,
) {
  if (direction == CashDifferenceDirection.none) {
    if (amountMinor != null || currency != null) {
      throw const ExchangeContractException(
        'A price cannot be supplied when no cash difference is selected.',
      );
    }
    return;
  }
  final normalizedCurrency = currency?.trim().toUpperCase();
  if (amountMinor == null ||
      amountMinor < 1 ||
      amountMinor > 100000000 ||
      normalizedCurrency == null ||
      !RegExp(r'^[A-Z]{3}$').hasMatch(normalizedCurrency)) {
    throw const ExchangeContractException(
      'Enter a positive cash amount and a three-letter currency.',
    );
  }
}

String _toWireDateTime(DateTime value) => DateTime.fromMillisecondsSinceEpoch(
  value.millisecondsSinceEpoch,
  isUtc: true,
).toIso8601String();
