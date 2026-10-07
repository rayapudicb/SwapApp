import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/medusa_flutter_theme.dart';
import '../../auth/providers/auth_provider.dart';

class AccountStatusScreen extends StatefulWidget {
  const AccountStatusScreen({super.key});

  @override
  State<AccountStatusScreen> createState() => _AccountStatusScreenState();
}

class _AccountStatusScreenState extends State<AccountStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AuthProvider>().refreshAccountStatus(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final onboarding = auth.onboarding;
    final profile = auth.profile;
    final blockers = onboarding?.policy.blockers ?? const <String>[];
    final medusa = context.medusa;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: medusa.bgSubtle,
      appBar: AppBar(
        backgroundColor: medusa.bgSubtle,
        title: Text(
          'Account setup',
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
      body: RefreshIndicator(
        onRefresh: auth.refreshAccountStatus,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 42),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: medusa.tagGreenBg,
                borderRadius: BorderRadius.circular(MedusaTheme.radiusLarge),
                border: Border.all(
                  color: medusa.tagGreenText.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: medusa.tagGreenText,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your Swappy account is created',
                    style: textTheme.titleLarge?.copyWith(
                      color: medusa.tagGreenText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your phone is verified and your profile is saved. A few '
                    'account checks remain before you can post or swap.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: medusa.tagGreenText,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: medusa.bgComponent,
                      child: Icon(Icons.person_outline, color: medusa.fgBase),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.displayName ?? 'Swappy participant',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: medusa.fgBase,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            profile == null
                                ? 'Loading account details…'
                                : 'Profile saved',
                            style: textTheme.bodySmall?.copyWith(
                              color: medusa.fgSubtle,
                            ),
                          ),
                          Text(
                            '${onboarding?.workflow?.completedSteps.length ?? 0} '
                            'setup step completed',
                            style: textTheme.bodySmall?.copyWith(
                              color: medusa.fgMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Setup progress',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: medusa.fgBase,
              ),
            ),
            const SizedBox(height: 10),
            const _ProgressRow(
              complete: true,
              title: 'Phone verified for sign-in',
              subtitle: 'Verified through the real OTP challenge workflow.',
            ),
            const _ProgressRow(
              complete: true,
              title: 'Profile basics saved',
              subtitle: 'Display name is stored in PostgreSQL.',
            ),
            for (final blocker in blockers)
              _ProgressRow(
                complete: false,
                title: _blockerTitle(blocker),
                subtitle: _blockerDescription(blocker),
              ),
            if (blockers.isEmpty && onboarding == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: CircularProgressIndicator(color: medusa.interactive),
                ),
              ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  auth.errorMessage!,
                  style: TextStyle(color: medusa.error),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: auth.isLoading ? null : auth.refreshAccountStatus,
              icon: auth.isLoading
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: medusa.onColor,
                      ),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('Check account status'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: auth.isLoading ? null : auth.logout,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: 24),
            Text(
              'What happens next',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: medusa.fgBase,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'We are checking the account details required for safe ticket '
              'swaps. You can return here and check again; your account and '
              'saved progress will remain secure.',
              style: textTheme.bodySmall?.copyWith(
                color: medusa.fgSubtle,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountRestrictedScreen extends StatelessWidget {
  const AccountRestrictedScreen({super.key});

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
          'Account unavailable',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: medusa.fgBase,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 54, color: medusa.fgMuted),
                const SizedBox(height: 16),
                Text(
                  'We cannot finish setting up your account right now.',
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: medusa.fgBase,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Try checking your account again. If this continues, '
                  'contact Swappy support.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: medusa.fgSubtle),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: auth.isLoading ? null : auth.refreshAccountStatus,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: auth.isLoading ? null : auth.logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.complete,
    required this.title,
    required this.subtitle,
  });

  final bool complete;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final medusa = context.medusa;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      leading: CircleAvatar(
        backgroundColor: complete ? medusa.tagGreenBg : medusa.bgComponent,
        child: Icon(
          complete ? Icons.check : Icons.lock_clock_outlined,
          color: complete ? medusa.tagGreenText : medusa.fgMuted,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: medusa.fgBase,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: textTheme.bodySmall?.copyWith(color: medusa.fgSubtle),
      ),
    );
  }
}

String _blockerTitle(String blocker) => switch (blocker) {
  'launch_jurisdiction' => 'Launch jurisdiction approval',
  'adult_eligibility_policy' => 'Adult eligibility policy',
  'participant_disclosures' => 'Participant disclosures',
  'profile_data_governance' => 'Profile-data governance',
  _ => 'Required policy approval',
};

String _blockerDescription(String blocker) => switch (blocker) {
  'launch_jurisdiction' => 'The first approved country or state is undecided.',
  'adult_eligibility_policy' =>
    'Age rules and acceptable eligibility evidence are undecided.',
  'participant_disclosures' =>
    'Versioned participant terms and disclosures are not approved.',
  'profile_data_governance' =>
    'Data purpose, retention, and deletion rules are not approved.',
  _ => 'This account requirement is still being reviewed.',
};
