import 'package:flutter/material.dart';
import 'package:passwordless_identity/passwordless_identity.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/bootstrap/data/bootstrap_repository.dart';
import 'core/bootstrap/providers/bootstrap_provider.dart';
import 'core/config/app_config.dart';
import 'core/localization/app_locale_provider.dart';
import 'core/storage/secure_storage.dart';
import 'core/theme/swappy_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/exchange/data/exchange_api_client.dart';
import 'features/exchange/providers/exchange_provider.dart';
import 'features/home/data/home_feed_repository.dart';
import 'features/home/providers/home_feed_provider.dart';
import 'features/profile/data/participant_profile_client.dart';
import 'features/store/data/store_repository.dart';
import 'features/store/providers/store_provider.dart';
import 'features/tickets/data/ticket_api_client.dart';
import 'features/tickets/providers/ticket_provider.dart';
import 'l10n/generated/app_localizations.dart';

void runConfiguredSwappy({
  required AppConfig config,
  required PasswordlessAuthRepository identityRepository,
}) {
  final baseUri = config.apiBaseUri!;
  final legacyStorage = SecureStorage();
  final coordinator = PasswordlessAuthCoordinator(
    repository: identityRepository,
    sessionStore: SecureAuthSessionStore(),
  );
  Future<String> tokenProvider({bool forceRefresh = false}) =>
      coordinator.validAccessToken(forceRefresh: forceRefresh);
  final profileClient = ParticipantProfileClient(
    baseUri: baseUri,
    accessTokenProvider: tokenProvider,
    sessionIdentityProvider: () => coordinator.session?.sessionId,
    onSessionRejected: () => coordinator.invalidateSession(
      const AuthException(
        code: 'PARTICIPANT_AUTH_REQUIRED',
        message: 'Your session is no longer valid. Sign in again.',
        sessionInvalid: true,
      ),
    ),
  );
  final authProvider = AuthProvider(
    coordinator: coordinator,
    profileGateway: profileClient,
    legacyStorage: legacyStorage,
    autoInitialize: false,
  );
  final apiClient = ApiClient(
    baseUri: baseUri,
    accessTokenProvider: authProvider.accessToken,
    sessionIdentityProvider: () => coordinator.session?.sessionId,
    onSessionRejected: (error) => coordinator.invalidateSession(
      AuthException(
        code: error.code ?? 'PARTICIPANT_AUTH_REQUIRED',
        message: error.message,
        sessionInvalid: true,
      ),
    ),
  );
  final bootstrapProvider = BootstrapProvider(
    gateway: BootstrapRepository(baseUri: baseUri),
    storage: legacyStorage,
  );
  final localeProvider = AppLocaleProvider(legacyStorage);
  final homeFeedProvider = HomeFeedProvider(
    repository: HomeFeedRepository(apiClient),
  );
  final exchangeProvider = ExchangeProvider(
    gateway: ExchangeApiClient(apiClient: apiClient),
  );
  final ticketProvider = TicketProvider(
    gateway: TicketApiClient(apiClient: apiClient),
  );
  final storeProvider = StoreProvider(repository: StoreRepository(apiClient));
  var scopedSessionId = authProvider.authenticatedSessionId;
  var scopedRouteState = authProvider.routeState;
  authProvider.addListener(() {
    final currentSessionId = authProvider.authenticatedSessionId;
    final currentRouteState = authProvider.routeState;
    final sessionChanged = currentSessionId != scopedSessionId;
    final homeAccessEnded =
        scopedRouteState == ParticipantRouteState.home &&
        currentRouteState != ParticipantRouteState.home;
    scopedSessionId = currentSessionId;
    scopedRouteState = currentRouteState;
    if (!sessionChanged && !homeAccessEnded) return;
    homeFeedProvider.resetForSession();
    exchangeProvider.resetForSession();
    ticketProvider.resetForSession();
    storeProvider.resetForSession();
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider(legacyStorage)),
        ChangeNotifierProvider.value(value: localeProvider),
        ChangeNotifierProvider(create: (_) => bootstrapProvider),
        ChangeNotifierProvider(create: (_) => homeFeedProvider),
        ChangeNotifierProvider(create: (_) => exchangeProvider),
        ChangeNotifierProvider(create: (_) => ticketProvider),
        ChangeNotifierProvider(create: (_) => storeProvider),
      ],
      child: SwappyApp(config: config),
    ),
  );
}

void runSwappyConfigurationError(String _) {
  runApp(const _ConfigurationErrorApp());
}

class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: SwappyTheme.light,
      darkTheme: SwappyTheme.dark,
      themeMode: ThemeMode.system,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Swappy is unavailable',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Check your connection and try again. If the problem '
                      'continues, contact Swappy support.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
