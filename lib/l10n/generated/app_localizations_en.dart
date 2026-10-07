// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Swappy';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageDescription =>
      'Choose the language used by Swappy on this device.';

  @override
  String get languageSystem => 'Use device language';

  @override
  String get languageSystemDescription =>
      'Use a supported language from your device settings.';

  @override
  String get languageAvailableTitle => 'Available now';

  @override
  String get languageLimitedDescription =>
      'Swappy currently provides approved product and legal copy in English. More languages will appear after their translations are reviewed.';

  @override
  String get languageSaveError =>
      'Your language preference could not be saved. Try again.';

  @override
  String get languageRestoreError =>
      'Your saved language could not be restored.';

  @override
  String get languageUnavailableError =>
      'That language is not available in this app version.';

  @override
  String get languageSettingsHint => 'Language and regional formatting';

  @override
  String get retry => 'Retry';

  @override
  String get close => 'Close';
}
