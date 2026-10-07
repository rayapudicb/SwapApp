import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/medusa_flutter_theme.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileBasicsScreen extends StatefulWidget {
  const ProfileBasicsScreen({super.key});

  @override
  State<ProfileBasicsScreen> createState() => _ProfileBasicsScreenState();
}

class _ProfileBasicsScreenState extends State<ProfileBasicsScreen> {
  late final TextEditingController _name;
  final _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _name = TextEditingController(
      text: auth.pendingDisplayName ?? auth.profile?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await context.read<AuthProvider>().completeProfile(_name.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final medusa = context.medusa;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: medusa.bgSubtle,
      appBar: AppBar(
        backgroundColor: medusa.bgSubtle,
        title: Text(
          'Finish account setup',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: medusa.fgBase,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: auth.isLoading ? null : auth.logout,
            icon: Icon(Icons.logout, color: medusa.fgSubtle),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: medusa.interactive,
                    borderRadius: BorderRadius.circular(
                      MedusaTheme.radiusMedium,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.person_outline,
                    color: medusa.onColor,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'What should we call you?',
                  style: textTheme.headlineMedium?.copyWith(
                    color: medusa.fgBase,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your phone is verified for sign-in. Save your display name to complete your profile setup.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: medusa.fgSubtle,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                if (auth.errorMessage != null) ...[
                  _ErrorBanner(message: auth.errorMessage!),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 120,
                  style: TextStyle(color: medusa.fgBase, fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    final normalized = value?.trim() ?? '';
                    if (normalized.isEmpty) return 'Enter your display name.';
                    if (normalized.length > 120) {
                      return 'Use 120 characters or fewer.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: auth.isProfileBusy ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: medusa.buttonPrimary,
                      foregroundColor: medusa.onColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          MedusaTheme.radiusMedium,
                        ),
                      ),
                    ),
                    child: auth.isProfileBusy
                        ? SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: medusa.onColor,
                            ),
                          )
                        : const Text(
                            'Save and continue',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final medusa = context.medusa;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: medusa.tagRedBg,
          borderRadius: BorderRadius.circular(MedusaTheme.radiusMedium),
          border: Border.all(color: medusa.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: medusa.error, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: medusa.tagRedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
