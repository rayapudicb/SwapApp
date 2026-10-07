import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AuthSessionStore {
  Future<String> getOrCreateInstallationId();

  Future<RefreshSessionState?> readRefreshSession();

  Future<void> writeRefreshSession(RefreshSessionState session);

  Future<void> clearRefreshSession();
}

/// Optional durable capability used to resume an unexpired OTP entry step.
///
/// The state deliberately cannot contain the phone number or verification
/// code. Hosts with a custom [AuthSessionStore] can implement this interface to
/// opt into challenge resumption without changing their existing session-store
/// contract.
abstract interface class PendingAuthChallengeStore {
  Future<PendingAuthChallengeState?> readPendingAuthChallenge();

  Future<void> writePendingAuthChallenge(PendingAuthChallengeState challenge);

  Future<void> clearPendingAuthChallenge();
}

class RefreshSessionState {
  const RefreshSessionState({
    required this.refreshToken,
    this.pendingRefreshIdempotencyKey,
  });

  final String refreshToken;
  final String? pendingRefreshIdempotencyKey;
}

class PendingAuthChallengeState {
  const PendingAuthChallengeState({
    required this.challengeId,
    required this.destinationMasked,
    required this.expiresAt,
    required this.resendAvailableAt,
  });

  final String challengeId;
  final String destinationMasked;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;
}

class SecureAuthSessionStore
    implements AuthSessionStore, PendingAuthChallengeStore {
  SecureAuthSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.unlocked_this_device,
              ),
            );

  static const _installationIdKey =
      'passwordless_identity.installation_identifier.v1';
  static const _legacyRefreshTokenKey =
      'passwordless_identity.refresh_token.v1';
  static const _refreshSessionKey = 'passwordless_identity.refresh_session.v2';
  static const _pendingAuthChallengeKey =
      'passwordless_identity.pending_auth_challenge.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<String> getOrCreateInstallationId() async {
    final existing = await _storage.read(key: _installationIdKey);
    if (existing != null && _isUuid(existing)) return existing;

    final created = _newUuid();
    await _storage.write(key: _installationIdKey, value: created);
    return created;
  }

  @override
  Future<RefreshSessionState?> readRefreshSession() async {
    final encoded = await _storage.read(key: _refreshSessionKey);
    if (encoded != null) {
      final decoded = _decodeRefreshSession(encoded);
      if (decoded != null) return decoded;
      await clearRefreshSession();
      return null;
    }

    final legacy = await _storage.read(key: _legacyRefreshTokenKey);
    if (legacy == null || legacy.trim().isEmpty) return null;
    final migrated = RefreshSessionState(refreshToken: legacy);
    await writeRefreshSession(migrated);
    await _storage.delete(key: _legacyRefreshTokenKey);
    return migrated;
  }

  @override
  Future<void> writeRefreshSession(RefreshSessionState session) {
    if (session.refreshToken.trim().isEmpty) {
      throw ArgumentError.value(
        session.refreshToken,
        'refreshToken',
        'must not be empty',
      );
    }
    final pendingKey = session.pendingRefreshIdempotencyKey;
    if (pendingKey != null && !_isUuid(pendingKey)) {
      throw ArgumentError.value(
        pendingKey,
        'pendingRefreshIdempotencyKey',
        'must be a UUID',
      );
    }
    return _storage.write(
      key: _refreshSessionKey,
      value: jsonEncode({
        'version': 2,
        'refreshToken': session.refreshToken,
        'pendingRefreshIdempotencyKey': pendingKey,
      }),
    );
  }

  @override
  Future<void> clearRefreshSession() async {
    await _storage.delete(key: _refreshSessionKey);
    await _storage.delete(key: _legacyRefreshTokenKey);
  }

  @override
  Future<PendingAuthChallengeState?> readPendingAuthChallenge() async {
    final encoded = await _storage.read(key: _pendingAuthChallengeKey);
    if (encoded == null) return null;
    final decoded = _decodePendingAuthChallenge(encoded);
    if (decoded != null) return decoded;
    await clearPendingAuthChallenge();
    return null;
  }

  @override
  Future<void> writePendingAuthChallenge(
    PendingAuthChallengeState challenge,
  ) {
    if (challenge.challengeId.trim().isEmpty) {
      throw ArgumentError.value(
        challenge.challengeId,
        'challengeId',
        'must not be empty',
      );
    }
    if (challenge.destinationMasked.trim().isEmpty) {
      throw ArgumentError.value(
        challenge.destinationMasked,
        'destinationMasked',
        'must not be empty',
      );
    }
    if (_looksLikeUnmaskedPhoneNumber(challenge.destinationMasked)) {
      throw ArgumentError.value(
        challenge.destinationMasked,
        'destinationMasked',
        'must not contain an unmasked E.164 phone number',
      );
    }
    if (challenge.resendAvailableAt.isAfter(challenge.expiresAt)) {
      throw ArgumentError.value(
        challenge.resendAvailableAt,
        'resendAvailableAt',
        'must not be after expiresAt',
      );
    }
    return _storage.write(
      key: _pendingAuthChallengeKey,
      value: jsonEncode({
        'version': 1,
        'challengeId': challenge.challengeId,
        'destinationMasked': challenge.destinationMasked,
        'expiresAt': challenge.expiresAt.toUtc().toIso8601String(),
        'resendAvailableAt':
            challenge.resendAvailableAt.toUtc().toIso8601String(),
      }),
    );
  }

  @override
  Future<void> clearPendingAuthChallenge() =>
      _storage.delete(key: _pendingAuthChallengeKey);
}

String newIdentityOperationId() => _newUuid();

String _newUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

bool _isUuid(String value) => RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value);

bool _looksLikeUnmaskedPhoneNumber(String value) {
  final compact = value.trim().replaceAll(RegExp(r'[\s()-]'), '');
  return RegExp(r'\+[1-9][0-9]{7,14}(?![0-9])').hasMatch(compact);
}

RefreshSessionState? _decodeRefreshSession(String encoded) {
  try {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map ||
        decoded['version'] != 2 ||
        decoded['refreshToken'] is! String ||
        (decoded['refreshToken'] as String).trim().isEmpty) {
      return null;
    }
    final pending = decoded['pendingRefreshIdempotencyKey'];
    if (pending != null && (pending is! String || !_isUuid(pending))) {
      return null;
    }
    return RefreshSessionState(
      refreshToken: decoded['refreshToken'] as String,
      pendingRefreshIdempotencyKey: pending as String?,
    );
  } on FormatException {
    return null;
  }
}

PendingAuthChallengeState? _decodePendingAuthChallenge(String encoded) {
  try {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map ||
        decoded['version'] != 1 ||
        decoded['challengeId'] is! String ||
        (decoded['challengeId'] as String).trim().isEmpty ||
        decoded['destinationMasked'] is! String ||
        (decoded['destinationMasked'] as String).trim().isEmpty ||
        _looksLikeUnmaskedPhoneNumber(
          decoded['destinationMasked'] as String,
        ) ||
        decoded['expiresAt'] is! String ||
        decoded['resendAvailableAt'] is! String) {
      return null;
    }
    final expiresAt = DateTime.tryParse(decoded['expiresAt'] as String);
    final resendAvailableAt = DateTime.tryParse(
      decoded['resendAvailableAt'] as String,
    );
    if (expiresAt == null ||
        resendAvailableAt == null ||
        resendAvailableAt.isAfter(expiresAt)) {
      return null;
    }
    return PendingAuthChallengeState(
      challengeId: decoded['challengeId'] as String,
      destinationMasked: decoded['destinationMasked'] as String,
      expiresAt: expiresAt.toLocal(),
      resendAvailableAt: resendAvailableAt.toLocal(),
    );
  } on FormatException {
    return null;
  }
}
