import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:swappy_mobile/core/bootstrap/domain/platform_bootstrap.dart';
import 'package:swappy_mobile/core/localization/app_locale_provider.dart';
import 'package:swappy_mobile/core/localization/presentation/language_settings_screen.dart';
import 'package:swappy_mobile/core/storage/secure_storage.dart';
import 'package:swappy_mobile/l10n/generated/app_localizations.dart';
import 'package:swappy_mobile/features/onboarding/presentation/welcome_screen.dart';

void main() {
  test('restores and canonicalizes a saved locale', () async {
    final storage = _LocaleStorage(saved: 'en_us');
    final provider = AppLocaleProvider(storage);

    await provider.initialize();

    expect(provider.locale, const Locale('en', 'US'));
    expect(provider.isLoading, isFalse);
    expect(AppLocaleProvider.toLanguageTag(provider.locale!), 'en-US');
  });

  test('rejects malformed tags and filters noncompiled languages', () {
    expect(AppLocaleProvider.parseLanguageTag('english_US'), isNull);
    expect(
      AppLocaleProvider.supportedLocalesFrom(const [
        SupportedLocale(
          code: 'hi-IN',
          name: 'Hindi',
          direction: 'ltr',
          isDefault: false,
        ),
      ]),
      AppLocaleProvider.fallbackSupportedLocales,
    );
  });

  test('clears a saved locale that is not compiled into this build', () async {
    final storage = _LocaleStorage(saved: 'hi-IN');
    final provider = AppLocaleProvider(storage);

    await provider.initialize();

    expect(provider.locale, isNull);
    expect(storage.saved, isNull);
  });

  test('does not persist a locale that is not compiled', () async {
    final storage = _LocaleStorage();
    final provider = AppLocaleProvider(storage);
    await provider.initialize();

    await provider.selectLocale(const Locale('hi', 'IN'));

    expect(provider.locale, isNull);
    expect(storage.saved, isNull);
    expect(provider.errorMessage, isNotNull);
  });

  test('keeps the previous locale when persistence fails', () async {
    final storage = _LocaleStorage(saved: 'en-US');
    final provider = AppLocaleProvider(storage);
    await provider.initialize();
    storage.failWrites = true;

    await provider.selectLocale(const Locale('en', 'GB'));

    expect(provider.locale, const Locale('en', 'US'));
    expect(provider.errorMessage, isNotNull);
    expect(provider.isLoading, isFalse);
  });

  testWidgets('language settings only show compiled approved locales', (
    tester,
  ) async {
    final storage = _LocaleStorage();
    final provider = AppLocaleProvider(storage);
    await provider.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LanguageSettingsScreen(
            configuredLocales: [
              SupportedLocale(
                code: 'en-US',
                name: 'English (United States)',
                direction: 'ltr',
                isDefault: true,
              ),
              SupportedLocale(
                code: 'hi-IN',
                name: 'Hindi',
                direction: 'ltr',
                isDefault: false,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('English (United States)'), findsOneWidget);
    expect(find.text('Hindi'), findsNothing);

    await tester.tap(find.text('English (United States)'));
    await tester.pumpAndSettle();

    expect(provider.locale, const Locale('en', 'US'));
    expect(storage.saved, 'en-US');
  });

  testWidgets('welcome language entry does not overflow at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = AppLocaleProvider(_LocaleStorage());
    await provider.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const WelcomeScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Language'), findsOneWidget);
  });
}

class _LocaleStorage extends SecureStorage {
  _LocaleStorage({this.saved});

  String? saved;
  bool failWrites = false;

  @override
  Future<String?> getPreferredLocale() async => saved;

  @override
  Future<void> savePreferredLocale(String value) async {
    if (failWrites) throw StateError('write failed');
    saved = value;
  }

  @override
  Future<void> clearPreferredLocale() async {
    if (failWrites) throw StateError('delete failed');
    saved = null;
  }
}
