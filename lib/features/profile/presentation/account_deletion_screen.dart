import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:passwordless_identity/passwordless_identity.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final TextEditingController _code = TextEditingController();
  AuthChallenge? _challenge;
  AuthException? _error;
  Timer? _clock;
  DateTime _now = DateTime.now();
  bool _requesting = false;
  bool _submitting = false;
  String? _submittedCode;

  bool get _challengeExpired {
    final challenge = _challenge;
    return challenge != null && !_now.isBefore(challenge.expiresAt);
  }

  bool get _canRequestAnotherCode {
    final challenge = _challenge;
    return challenge == null || !_now.isBefore(challenge.resendAvailableAt);
  }

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestCode();
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_requesting || _submitting) return;
    setState(() {
      _requesting = true;
      _error = null;
    });
    try {
      final challenge = await context
          .read<AuthProvider>()
          .requestDeletionChallenge();
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _now = DateTime.now();
        _submittedCode = null;
        _code.clear();
      });
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _reviewDeletion() async {
    final challenge = _challenge;
    if (challenge == null || _requesting || _submitting) return;

    final code = _code.text.trim();
    if (code.length != 4 && code.length != 6) {
      setState(
        () => _error = const AuthException(
          code: 'OTP_CODE_INVALID',
          message: 'Enter the complete 4- or 6-digit deletion code.',
        ),
      );
      return;
    }
    if (_challengeExpired) {
      setState(
        () => _error = const AuthException(
          code: 'OTP_CHALLENGE_EXPIRED',
          message: 'This deletion code has expired. Request a new code.',
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeletionConfirmationDialog(),
    );
    if (confirmed == true && mounted) await _submitDeletion(code);
  }

  Future<void> _submitDeletion([String? code]) async {
    final challenge = _challenge;
    final submissionCode = _submittedCode ?? code;
    if (challenge == null || submissionCode == null || _submitting) return;

    _submittedCode ??= submissionCode;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().deleteAccount(
        challenge: challenge,
        code: _submittedCode!,
      );
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        if (!error.outcomeUnknown) _submittedCode = null;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final challenge = _challenge;
    final error = _error;
    final outcomeUnknown = error?.outcomeUnknown ?? false;

    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Delete account')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Card(
                color: colors.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: colors.error),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'This schedules deletion of your account and signs '
                          'you out after your request is accepted. '
                          'Continue only if you want to lose account access.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Confirm it is you',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'We use a deletion-specific one-time code. It cannot be used '
                'to sign in or approve another action.',
              ),
              const SizedBox(height: 16),
              if (_requesting && challenge == null)
                const _LoadingCard(label: 'Requesting a secure code…')
              else if (challenge != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Code sent to ${challenge.destinationMasked}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _code,
                          enabled: !_submitting && !outcomeUnknown,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          obscureText: true,
                          obscuringCharacter: '•',
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 10,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Deletion code',
                            hintText: '••••••',
                            helperText: _challengeExpired
                                ? 'Code expired'
                                : 'Expires in ${_remaining(challenge.expiresAt, _now)}',
                            border: const OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _reviewDeletion(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 14),
                _DeletionError(error: error),
              ],
              if (_submitting) ...[
                const SizedBox(height: 14),
                const _LoadingCard(
                  label: 'Verifying the code and submitting your request…',
                ),
              ],
              const SizedBox(height: 18),
              if (outcomeUnknown && challenge == null)
                FilledButton.icon(
                  onPressed: _requesting ? null : _requestCode,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry the same code request safely'),
                )
              else if (outcomeUnknown)
                FilledButton.icon(
                  onPressed: _submitting ? null : _submitDeletion,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry the same request safely'),
                )
              else if (challenge != null)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _requesting || _submitting || _challengeExpired
                      ? null
                      : _reviewDeletion,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Review account deletion'),
                )
              else
                FilledButton.icon(
                  onPressed: _requesting ? null : _requestCode,
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Retry code request'),
                ),
              if (!outcomeUnknown && challenge != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed:
                      _requesting || _submitting || !_canRequestAnotherCode
                      ? null
                      : _requestCode,
                  child: Text(
                    _canRequestAnotherCode
                        ? 'Request a new code'
                        : 'New code available in '
                              '${_remaining(challenge.resendAvailableAt, _now)}',
                  ),
                ),
              ],
              const SizedBox(height: 4),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).maybePop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeletionConfirmationDialog extends StatefulWidget {
  const _DeletionConfirmationDialog();

  @override
  State<_DeletionConfirmationDialog> createState() =>
      _DeletionConfirmationDialogState();
}

class _DeletionConfirmationDialogState
    extends State<_DeletionConfirmationDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.delete_forever_outlined, color: colors.error),
      title: const Text('Delete your account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Swappy will verify the code and then submit a deletion request '
            'using your latest account status. You will be signed out '
            'when it is accepted.',
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _understood,
            onChanged: (value) => setState(() => _understood = value ?? false),
            title: const Text(
              'I understand that I may permanently lose account access.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep account'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: _understood ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Delete account'),
        ),
      ],
    );
  }
}

class _DeletionError extends StatelessWidget {
  const _DeletionError({required this.error});

  final AuthException error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final attempts = error.attemptsRemaining;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error.message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
            if (attempts != null) ...[
              const SizedBox(height: 6),
              Text(
                '$attempts ${attempts == 1 ? 'attempt' : 'attempts'} remaining.',
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ],
            if (error.outcomeUnknown) ...[
              const SizedBox(height: 8),
              Text(
                'Keep this screen open and do not start a different deletion '
                'request. Retrying here reuses the same protected operation.',
                style: TextStyle(
                  color: colors.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    ),
  );
}

String _remaining(DateTime target, DateTime now) {
  final seconds = target.difference(now).inSeconds;
  final safe = seconds < 0 ? 0 : seconds;
  final minutes = safe ~/ 60;
  final remainder = safe % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}
