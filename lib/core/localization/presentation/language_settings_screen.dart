import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../bootstrap/domain/platform_bootstrap.dart';
import '../../bootstrap/providers/bootstrap_provider.dart';
import '../../theme/medusa_flutter_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../app_locale_provider.dart';

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({this.configuredLocales, super.key});

  final List<SupportedLocale>? configuredLocales;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final localeProvider = context.watch<AppLocaleProvider>();
    final bootstrap = Provider.of<BootstrapProvider?>(context);
    final configured =
        configuredLocales ??
        bootstrap?.bootstrap?.supportedLocales ??
        const <SupportedLocale>[
          SupportedLocale(
            code: 'en-US',
            name: 'English (United States)',
            direction: 'ltr',
            isDefault: true,
          ),
        ];
    final options = _compiledOptions(configured);
    final failureMessage = switch (localeProvider.failure) {
      LocalePreferenceFailure.restore => strings.languageRestoreError,
      LocalePreferenceFailure.unavailable => strings.languageUnavailableError,
      _ => strings.languageSaveError,
    };

    return Scaffold(
      appBar: AppBar(title: Text(strings.languageTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              strings.languageDescription,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            _AvailabilityCard(message: strings.languageLimitedDescription),
            if (localeProvider.errorMessage != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: MaterialBanner(
                  content: Text(failureMessage),
                  actions: [
                    if (localeProvider.failure ==
                        LocalePreferenceFailure.restore)
                      TextButton(
                        onPressed: () => localeProvider.initialize(force: true),
                        child: Text(strings.retry),
                      ),
                    TextButton(
                      onPressed: localeProvider.clearError,
                      child: Text(strings.close),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _LanguageTile(
                    key: const ValueKey('language-system'),
                    title: strings.languageSystem,
                    subtitle: strings.languageSystemDescription,
                    selected: localeProvider.followsSystem,
                    busy: localeProvider.isLoading,
                    onTap: localeProvider.useSystemLocale,
                  ),
                  for (final option in options) ...[
                    const Divider(height: 1),
                    _LanguageTile(
                      key: ValueKey('language-${option.localeTag}'),
                      title: option.name,
                      subtitle: option.localeTag,
                      selected: _sameLocale(
                        localeProvider.locale,
                        option.locale,
                      ),
                      busy: localeProvider.isLoading,
                      onTap: () => localeProvider.selectLocale(option.locale),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<_LanguageOption> _compiledOptions(
    Iterable<SupportedLocale> configured,
  ) {
    final options = <_LanguageOption>[];
    final supported = AppLocaleProvider.supportedLocalesFrom(configured);
    for (final locale in supported) {
      final matching = configured.where((item) {
        final parsed = AppLocaleProvider.parseLanguageTag(item.code);
        return parsed != null && _sameLocale(parsed, locale);
      }).firstOrNull;
      options.add(
        _LanguageOption(
          locale: locale,
          name: matching?.name ?? _fallbackName(locale),
        ),
      );
    }
    return options;
  }

  static bool _sameLocale(Locale? left, Locale right) =>
      left != null &&
      left.languageCode.toLowerCase() == right.languageCode.toLowerCase() &&
      (left.scriptCode ?? '').toLowerCase() ==
          (right.scriptCode ?? '').toLowerCase() &&
      (left.countryCode ?? '').toUpperCase() ==
          (right.countryCode ?? '').toUpperCase();

  static String _fallbackName(Locale locale) => switch (locale.languageCode) {
    'en' => 'English',
    _ => AppLocaleProvider.toLanguageTag(locale),
  };
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final medusa = context.medusa;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: medusa.bgHighlight,
        borderRadius: BorderRadius.circular(MedusaTheme.radiusMedium),
        border: Border.all(color: medusa.borderBase),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.translate, color: medusa.interactive),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: medusa.fgSubtle,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.busy,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool busy;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: ListTile(
      minTileHeight: 56,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: busy && selected
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : selected
          ? const Icon(Icons.check)
          : null,
      enabled: !busy,
      onTap: busy ? null : onTap,
    ),
  );
}

class _LanguageOption {
  const _LanguageOption({required this.locale, required this.name});

  final Locale locale;
  final String name;

  String get localeTag => AppLocaleProvider.toLanguageTag(locale);
}
