import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/bootstrap/domain/platform_bootstrap.dart';
import '../../../core/bootstrap/presentation/legal_document_screen.dart';
import '../../../core/bootstrap/providers/bootstrap_provider.dart';
import '../../../core/localization/app_locale_provider.dart';
import '../../../core/localization/presentation/language_settings_screen.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../../store/presentation/billing_receipts_screen.dart';
import '../../store/presentation/subscription_plans_screen.dart';
import 'account_deletion_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().refreshProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final localeProvider = Provider.of<AppLocaleProvider?>(context);
    final bootstrap = Provider.of<BootstrapProvider?>(context);
    final strings = AppLocalizations.of(context);
    final profile = auth.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: auth.refreshProfile,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 34,
                      child: Icon(Icons.person_outline, size: 34),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.displayName ?? 'Loading profile…',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage your profile and account',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: profile == null || auth.isProfileBusy
                          ? null
                          : () => _edit(auth),
                      tooltip: 'Edit display name',
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  auth.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Icon(
                      theme.isDark ? Icons.dark_mode : Icons.light_mode,
                    ),
                    title: const Text('Dark theme'),
                    value: theme.isDark,
                    onChanged: theme.setDark,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: const Text('Subscriptions & Upload Quotas'),
                    subtitle: const Text(
                      'Manage your upload allowance, season plans & billing',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const SubscriptionPlansScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: const Text('Billing & Digital Receipts'),
                    subtitle: const Text(
                      'View your payment history & US order receipts',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const BillingReceiptsScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.translate),
                    title: Text(strings.languageTitle),
                    subtitle: Text(
                      _localeLabel(
                        localeProvider,
                        bootstrap?.bootstrap?.supportedLocales,
                        strings.languageSystem,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: localeProvider != null,
                    onTap: localeProvider == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const LanguageSettingsScreen(),
                            ),
                          ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign out'),
                    enabled: !auth.isLoading,
                    onTap: auth.isLoading
                        ? null
                        : () => _signOut(auth, allDevices: false),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.security_outlined),
                    title: const Text('Account & security'),
                    subtitle: const Text('Sessions and account deletion'),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: !auth.isLoading,
                    onTap: auth.isLoading
                        ? null
                        : () => _showAccountActions(auth),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.policy_outlined),
                    title: Text('Legal documents'),
                    subtitle: Text(
                      'Review the policies published for your account.',
                    ),
                  ),
                  const Divider(height: 1),
                  _LegalDocumentTile(
                    title: 'Terms of Service',
                    slug: 'terms-of-service',
                    enabled:
                        bootstrap?.hasPublishedLegalDocument(
                          'terms-of-service',
                        ) ??
                        false,
                  ),
                  const Divider(height: 1),
                  _LegalDocumentTile(
                    title: 'Privacy Policy',
                    slug: 'privacy-policy',
                    enabled:
                        bootstrap?.hasPublishedLegalDocument(
                          'privacy-policy',
                        ) ??
                        false,
                  ),
                  const Divider(height: 1),
                  _LegalDocumentTile(
                    title: 'End User License Agreement',
                    slug: 'eula',
                    enabled:
                        bootstrap?.hasPublishedLegalDocument('eula') ?? false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAccountActions(AuthProvider auth) async {
    final action = await showModalBottomSheet<_AccountAction>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account & security',
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.phonelink_erase_outlined),
              title: const Text('Sign out on all devices'),
              subtitle: const Text('Revoke every active Swappy session.'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_AccountAction.signOutAll),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: Text(
                'Delete account',
                style: TextStyle(
                  color: Theme.of(sheetContext).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text('Requires a deletion verification code.'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_AccountAction.deleteAccount),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _AccountAction.signOutAll:
        await _signOut(auth, allDevices: true);
        return;
      case _AccountAction.deleteAccount:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AccountDeletionScreen(),
          ),
        );
        return;
    }
  }

  Future<void> _edit(AuthProvider auth) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _EditDisplayNameDialog(
        initialValue: auth.profile?.displayName,
      ),
    );
    if (name != null && name.isNotEmpty && mounted) {
      await auth.completeProfile(name);
    }
  }

  Future<void> _signOut(AuthProvider auth, {required bool allDevices}) async {
    if (allDevices) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sign out on all devices?'),
          content: const Text(
            'Every active Swappy session will be asked to sign in again, '
            'including this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sign out everywhere'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    if (allDevices) {
      await auth.logoutAll();
    } else {
      await auth.logout();
    }
    if (mounted) Navigator.of(context).pop();
  }
}

enum _AccountAction { signOutAll, deleteAccount }

class _LegalDocumentTile extends StatelessWidget {
  const _LegalDocumentTile({
    required this.title,
    required this.slug,
    required this.enabled,
  });

  final String title;
  final String slug;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 52,
    title: Text(title),
    trailing: const Icon(Icons.open_in_new),
    enabled: enabled,
    onTap: !enabled
        ? null
        : () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  LegalDocumentScreen(slug: slug, fallbackTitle: title),
            ),
          ),
  );
}

String _localeLabel(
  AppLocaleProvider? provider,
  List<SupportedLocale>? configured,
  String systemLabel,
) {
  if (provider == null || provider.followsSystem) return systemLabel;
  final locale = provider.locale!;
  final tag = AppLocaleProvider.toLanguageTag(locale);
  for (final option in configured ?? const <SupportedLocale>[]) {
    final parsed = AppLocaleProvider.parseLanguageTag(option.code);
    if (parsed != null &&
        parsed.languageCode == locale.languageCode &&
        parsed.countryCode == locale.countryCode) {
      return option.name;
    }
  }
  return tag;
}

class _EditDisplayNameDialog extends StatefulWidget {
  const _EditDisplayNameDialog({this.initialValue});

  final String? initialValue;

  @override
  State<_EditDisplayNameDialog> createState() => _EditDisplayNameDialogState();
}

class _EditDisplayNameDialogState extends State<_EditDisplayNameDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: AlertDialog(
      title: const Text('Edit display name'),
      content: TextFormField(
        controller: _controller,
        autofocus: true,
        maxLength: 120,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Display name'),
        validator: (value) {
          final normalized = value?.trim() ?? '';
          if (normalized.isEmpty) return 'Enter your display name.';
          if (normalized.length > 120) {
            return 'Use 120 characters or fewer.';
          }
          return null;
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.pop(context, _controller.text.trim());
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
