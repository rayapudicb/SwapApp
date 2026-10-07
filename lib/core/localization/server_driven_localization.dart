import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';

/// Server-Driven Localization Engine for Swappy Mobile.
///
/// Features:
/// 1. Dynamic remote string dictionary fetched from `/v1/platform/locales/:code/translations`.
/// 2. Key-Level Fallback to default English (`en-US`) for any missing label or alert.
/// 3. In-memory and instant offline rendering.
/// 4. Variable interpolation: `{{variable}}`.
class ServerDrivenLocalization extends ChangeNotifier {
  ServerDrivenLocalization({required ApiClient api}) : _api = api;

  final ApiClient _api;

  String _currentLocaleCode = 'en-US';
  Map<String, String> _translations = const {};
  final Map<String, String> _fallbackEnTranslations = const {};
  bool _isLoading = false;

  String get currentLocaleCode => _currentLocaleCode;
  bool get isLoading => _isLoading;

  /// Translates a key with optional dynamic arguments and fallback to English.
  String translate(String key, {Map<String, Object?>? args}) {
    // 1. Try selected language translation
    String? raw = _translations[key];

    // 2. Fall back to English server translation
    raw ??= _fallbackEnTranslations[key];

    // 3. Fall back to embedded default baseline
    raw ??= _embeddedEnglishBaseline[key];

    // 4. Ultimate fallback: Clean readable version of the key (never raw dot notation)
    if (raw == null) {
      final parts = key.split('.');
      final last = parts.isNotEmpty ? parts.last : key;
      raw = last.replaceAll('_', ' ');
      if (raw.isNotEmpty) {
        raw = raw[0].toUpperCase() + raw.substring(1);
      }
    }

    // Dynamic variable interpolation: {{var}}
    if (args != null && args.isNotEmpty) {
      args.forEach((placeholder, value) {
        raw = raw!.replaceAll('{{$placeholder}}', value?.toString() ?? '');
      });
    }

    return raw!;
  }

  /// Loads translations for the specified locale.
  Future<void> loadTranslations(String localeCode) async {
    _currentLocaleCode = localeCode;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.get('/v1/platform/locales/$localeCode/translations');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['translations'] is Map) {
          final map = Map<String, dynamic>.from(decoded['translations'] as Map);
          _translations = map.map((k, v) => MapEntry(k, v.toString()));
        }
      }
    } catch (_) {
      // Offline fallback remains active
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static const Map<String, String> _embeddedEnglishBaseline = {
    'app.name': 'Swappy',
    'app.tagline': 'The Universal Ticket & Seat Exchange Engine',
    'common.done': 'Done',
    'common.cancel': 'Cancel',
    'common.continue': 'Continue',
    'common.save': 'Save',
    'common.close': 'Close',
    'common.retry': 'Retry',
    'common.loading': 'Loading…',
    'common.error_occurred': 'An unexpected error occurred. Please try again.',
    'profile.title': 'Profile',
    'profile.subscriptions_and_quotas': 'Subscriptions & Upload Quotas',
    'profile.subscriptions_subtitle': 'Manage your upload allowance, season plans & billing',
    'profile.billing_receipts': 'Billing & Digital Receipts',
    'profile.billing_subtitle': 'View your payment history & US order receipts',
    'profile.language': 'Language',
    'profile.sign_out': 'Sign out',
    'profile.account_security': 'Account & security',
    'store.title': 'Subscriptions & Quotas',
    'store.current_allowance': 'CURRENT ALLOWANCE',
    'store.uploads_remaining': 'Uploads Remaining',
    'store.active_plan': 'Active Plan',
    'store.free_quota': 'Free Quota',
    'store.choose_plan': 'Choose {{planTitle}}',
    'store.pay_button': 'Pay {{amount}}',
    'store.checkout_title': 'Checkout',
    'store.sales_tax_usa': 'Estimated Sales Tax (USA)',
    'store.total_due_today': 'Total Due Today',
    'store.card_number_label': 'Card Number',
    'store.subscribed_success': 'Subscribed!',
    'paywall.quota_exhausted_title': 'Upload Quota Finished',
    'paywall.quota_exhausted_body': 'You have used all verified ticket uploads in your current allowance. Choose a subscription plan to continue uploading tickets.',
    'paywall.view_plans_button': 'View Upload Plans & Top Up',
    'paywall.maybe_later': 'Maybe Later',
    'exchange.my_swaps_title': 'My Swaps & Matches',
    'exchange.upload_ticket_button': 'Upload Ticket for Swap',
    'exchange.find_match_button': 'Find Compatible Seats',
    'exchange.rate_swap_title': 'Rate Your Swap',
    'exchange.rate_swap_prompt': 'How was your experience swapping with {{partnerName}}?',
    'exchange.submit_rating_button': 'Submit Rating',
  };
}
