import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/api/health_api_client.dart';
import 'core/bootstrap/presentation/maintenance_screen.dart';
import 'core/bootstrap/providers/bootstrap_provider.dart';
import 'core/config/app_config.dart';
import 'core/localization/app_locale_provider.dart';
import 'core/theme/swappy_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/otp_verification_screen.dart';
import 'features/auth/presentation/signup_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/foundation/presentation/participant_foundation_screen.dart';
import 'features/onboarding/presentation/account_status_screen.dart';
import 'features/onboarding/presentation/profile_basics_screen.dart';
import 'features/onboarding/presentation/welcome_screen.dart';
import 'l10n/generated/app_localizations.dart';

class SwappyApp extends StatefulWidget {
  const SwappyApp({required this.config, this.healthGateway, super.key});

  final AppConfig config;
  final ApiHealthGateway? healthGateway;

  @override
  State<SwappyApp> createState() => _SwappyAppState();
}

class _SwappyAppState extends State<SwappyApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  late final ApiHealthGateway _healthGateway;
  _ApiStartupState _startupState = _ApiStartupState.checking;
  String? _startupMessage;
  int _startupRequestVersion = 0;
  bool _authInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final auth = context.read<AuthProvider>();
    _healthGateway =
        widget.healthGateway ??
        HealthApiClient(apiBaseUri: widget.config.apiBaseUri!);

    _router = GoRouter(
      initialLocation: '/loading',
      refreshListenable: auth,
      redirect: (context, state) {
        final location = state.matchedLocation;
        return switch (auth.routeState) {
          ParticipantRouteState.booting =>
            location == '/loading' ? null : '/loading',
          ParticipantRouteState.welcome =>
            location == '/welcome' ? null : '/welcome',
          ParticipantRouteState.signedOut =>
            location == '/login' || location == '/signup' ? null : '/login',
          ParticipantRouteState.recoverable =>
            location == '/restore-error' ? null : '/restore-error',
          ParticipantRouteState.awaitingOtp =>
            location == '/verify' ? null : '/verify',
          ParticipantRouteState.profileBasics =>
            location == '/profile-basics' ? null : '/profile-basics',
          ParticipantRouteState.home => location == '/' ? null : '/',
          ParticipantRouteState.restricted =>
            location == '/restricted' ? null : '/restricted',
        };
      },
      routes: [
        GoRoute(path: '/loading', builder: (_, __) => const _LoadingScreen()),
        GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
        GoRoute(
          path: '/restore-error',
          builder: (_, __) => _SessionRestoreErrorScreen(
            onRetry: () => _checkApi(retryAuth: true),
          ),
        ),
        GoRoute(
          path: '/verify',
          builder: (_, __) => const OtpVerificationScreen(),
        ),
        GoRoute(
          path: '/profile-basics',
          builder: (_, __) => const ProfileBasicsScreen(),
        ),
        GoRoute(
          path: '/restricted',
          builder: (_, __) => const AccountRestrictedScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (_, __) => const ParticipantFoundationScreen(),
        ),
      ],
    );
    unawaited(_checkApi());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _startupState == _ApiStartupState.ready) {
      unawaited(_checkApi(showChecking: false));
    }
  }

  Future<void> _checkApi({
    bool showChecking = true,
    bool retryAuth = false,
  }) async {
    final requestVersion = ++_startupRequestVersion;
    if (showChecking && mounted) {
      setState(() {
        _startupState = _ApiStartupState.checking;
        _startupMessage = null;
      });
    }
    try {
      await _healthGateway.fetchHealth();
      if (!mounted || requestVersion != _startupRequestVersion) return;
      if (!_authInitialized || retryAuth) {
        final bootstrap = Provider.of<BootstrapProvider?>(
          context,
          listen: false,
        );
        final locale = context.read<AppLocaleProvider>();
        await Future.wait([
          context.read<AuthProvider>().initialize(),
          if (bootstrap != null) bootstrap.initialize(),
          locale.initialize(),
        ]);
        if (bootstrap?.hasVerifiedBootstrap ?? false) {
          await locale.reconcileSupportedLocales(
            AppLocaleProvider.supportedLocalesFrom(
              bootstrap?.bootstrap?.supportedLocales,
            ),
          );
        }
        if (!mounted || requestVersion != _startupRequestVersion) return;
        _authInitialized = true;
      }
      setState(() {
        _startupState = _ApiStartupState.ready;
        _startupMessage = null;
      });
    } on HealthContractException {
      if (!mounted || requestVersion != _startupRequestVersion) return;
      setState(() {
        _startupState = _ApiStartupState.wrongService;
        _startupMessage = 'Swappy could not connect securely. Try again.';
      });
    } on HealthRequestException {
      if (!mounted || requestVersion != _startupRequestVersion) return;
      setState(() {
        _startupState = _ApiStartupState.unreachable;
        _startupMessage =
            'Swappy is temporarily unavailable. Check the connection and '
            'try again.';
      });
    } catch (_) {
      if (!mounted || requestVersion != _startupRequestVersion) return;
      setState(() {
        _startupState = _ApiStartupState.unreachable;
        _startupMessage = 'Swappy could not connect. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().mode;
    final bootstrap = Provider.of<BootstrapProvider?>(context);
    final localeProvider = context.watch<AppLocaleProvider>();
    final appSupportedLocales = AppLocaleProvider.supportedLocalesFrom(
      bootstrap?.bootstrap?.supportedLocales,
    );
    final locale = AppLocaleProvider.effectiveLocale(
      localeProvider.locale,
      appSupportedLocales,
    );

    if (_startupState != _ApiStartupState.ready) {
      return MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appSupportedLocales,
        themeMode: themeMode,
        theme: SwappyTheme.light,
        darkTheme: SwappyTheme.dark,
        home: _ApiStartupScreen(
          state: _startupState,
          message: _startupMessage,
          onRetry: _checkApi,
        ),
      );
    }

    if (bootstrap != null && bootstrap.isMaintenanceActive) {
      return MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: appSupportedLocales,
        themeMode: themeMode,
        theme: SwappyTheme.light,
        darkTheme: SwappyTheme.dark,
        home: const MaintenanceScreen(),
      );
    }

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: appSupportedLocales,
      routerConfig: _router,
      themeMode: themeMode,
      theme: SwappyTheme.light,
      darkTheme: SwappyTheme.dark,
    );
  }
}

enum _ApiStartupState { checking, ready, unreachable, wrongService }

class _ApiStartupScreen extends StatelessWidget {
  const _ApiStartupScreen({
    required this.state,
    required this.message,
    required this.onRetry,
  });

  final _ApiStartupState state;
  final String? message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final checking = state == _ApiStartupState.checking;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Semantics(
              liveRegion: !checking,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (checking)
                    const CircularProgressIndicator()
                  else
                    Icon(
                      state == _ApiStartupState.wrongService
                          ? Icons.security_outlined
                          : Icons.cloud_off_outlined,
                      size: 54,
                    ),
                  const SizedBox(height: 18),
                  Text(
                    checking ? 'Connecting to Swappy…' : 'Unable to connect',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    checking
                        ? 'Getting things ready for you.'
                        : message ?? 'Check the connection and try again.',
                    textAlign: TextAlign.center,
                  ),
                  if (!checking) ...[
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionRestoreErrorScreen extends StatelessWidget {
  const _SessionRestoreErrorScreen({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sync_problem_outlined, size: 54),
                  const SizedBox(height: 18),
                  const Text(
                    'Your session is still saved',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    auth.errorMessage ??
                        'Swappy could not restore the session. Try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: auth.isLoading ? null : onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry session restore'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Restoring your secure Swappy session…'),
          ],
        ),
      ),
    ),
  );
}
