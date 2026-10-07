import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passwordless_identity/passwordless_identity.dart';
import 'package:provider/provider.dart';
import 'package:swappy_mobile/app.dart';
import 'package:swappy_mobile/core/api/health_api_client.dart';
import 'package:swappy_mobile/core/config/app_config.dart';
import 'package:swappy_mobile/core/localization/app_locale_provider.dart';
import 'package:swappy_mobile/core/storage/secure_storage.dart';
import 'package:swappy_mobile/core/theme/theme_provider.dart';
import 'package:swappy_mobile/features/auth/providers/auth_provider.dart';
import 'package:swappy_mobile/features/profile/data/participant_profile_client.dart';

void main() {
  testWidgets('does not open sign-in until the API health check succeeds', (
    tester,
  ) async {
    final health = _CompletingHealthGateway();
    final harness = _AppHarness(health);
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pump();

    expect(find.text('Connecting to Swappy…'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    expect(harness.storage.clearCount, 0);

    health.complete();
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('INTERNAL OTP'), findsNothing);
    expect(harness.storage.clearCount, 1);
    expect(
      Localizations.localeOf(tester.element(find.text('Welcome back'))),
      const Locale('en', 'US'),
    );
  });

  testWidgets('an unavailable API shows a durable retry instead of login', (
    tester,
  ) async {
    final harness = _AppHarness(_FailingHealthGateway());
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(find.text('Unable to connect'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('temporarily unavailable'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    expect(harness.storage.clearCount, 0);
  });

  testWidgets('retry verifies the API and only then initializes identity', (
    tester,
  ) async {
    final health = _RetryHealthGateway();
    final harness = _AppHarness(health);
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    expect(find.text('Unable to connect'), findsOneWidget);
    expect(harness.storage.clearCount, 0);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(health.calls, 2);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(harness.storage.clearCount, 1);
  });

  testWidgets('an incompatible localhost service never opens identity UI', (
    tester,
  ) async {
    final harness = _AppHarness(_WrongServiceHealthGateway());
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(find.text('Unable to connect'), findsOneWidget);
    expect(
      find.text('Swappy could not connect securely. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Welcome back'), findsNothing);
    expect(harness.storage.clearCount, 0);
  });
}

const _healthy = ApiHealth(
  status: 'ok',
  service: 'swappy-api',
  version: '0.1.0',
);

class _CompletingHealthGateway implements ApiHealthGateway {
  final Completer<ApiHealth> _completer = Completer<ApiHealth>();

  void complete() => _completer.complete(_healthy);

  @override
  Future<ApiHealth> fetchHealth() => _completer.future;
}

class _FailingHealthGateway implements ApiHealthGateway {
  @override
  Future<ApiHealth> fetchHealth() async {
    throw const HealthRequestException();
  }
}

class _WrongServiceHealthGateway implements ApiHealthGateway {
  @override
  Future<ApiHealth> fetchHealth() async {
    throw const HealthContractException();
  }
}

class _RetryHealthGateway implements ApiHealthGateway {
  int calls = 0;

  @override
  Future<ApiHealth> fetchHealth() async {
    calls++;
    if (calls == 1) throw const HealthRequestException();
    return _healthy;
  }
}

class _AppHarness {
  _AppHarness(this.health)
    : storage = _TestStorage(),
      sessionStore = _EmptySessionStore() {
    auth = AuthProvider(
      coordinator: PasswordlessAuthCoordinator(
        repository: _UnusedIdentityRepository(),
        sessionStore: sessionStore,
      ),
      profileGateway: _UnusedProfileGateway(),
      legacyStorage: storage,
      autoInitialize: false,
    );
  }

  final ApiHealthGateway health;
  final _TestStorage storage;
  final _EmptySessionStore sessionStore;
  late final AuthProvider auth;

  Widget get widget => MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(storage),
      ),
      ChangeNotifierProvider<AppLocaleProvider>(
        create: (_) => AppLocaleProvider(storage),
      ),
    ],
    child: SwappyApp(config: _config, healthGateway: health),
  );

  static final _config = AppConfig.fromApiBaseUrl('http://127.0.0.1:3100');

  void dispose() => auth.dispose();
}

class _TestStorage extends SecureStorage {
  int clearCount = 0;

  @override
  Future<void> clearLegacyAuthTokens() async {
    clearCount++;
  }

  @override
  Future<bool> getHasSeenWelcome() async => true;

  @override
  Future<String?> getThemeMode() async => null;

  @override
  Future<String?> getPreferredLocale() async => 'en-US';
}

class _EmptySessionStore implements AuthSessionStore {
  @override
  Future<void> clearRefreshSession() async {}

  @override
  Future<String> getOrCreateInstallationId() async =>
      '10000000-0000-4000-8000-000000000001';

  @override
  Future<RefreshSessionState?> readRefreshSession() async => null;

  @override
  Future<void> writeRefreshSession(RefreshSessionState value) async {}
}

class _UnusedIdentityRepository implements PasswordlessAuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedProfileGateway implements ParticipantProfileGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
