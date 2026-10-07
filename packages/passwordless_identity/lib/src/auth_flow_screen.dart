import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_coordinator.dart';
import 'auth_models.dart';

class PasswordlessAuthFlowScreen extends StatefulWidget {
  const PasswordlessAuthFlowScreen({
    required this.coordinator,
    this.applicationName = 'Account',
    this.logo,
    super.key,
  });

  final PasswordlessAuthCoordinator coordinator;
  final String applicationName;
  final Widget? logo;

  @override
  State<PasswordlessAuthFlowScreen> createState() =>
      _PasswordlessAuthFlowScreenState();
}

class _PasswordlessAuthFlowScreenState
    extends State<PasswordlessAuthFlowScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _phoneFocus = FocusNode();
  final _codeFocus = FocusNode();
  Timer? _countdown;
  bool _recoveryCopy = false;

  @override
  void initState() {
    super.initState();
    widget.coordinator.addListener(_coordinatorChanged);
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          widget.coordinator.phase == AuthCoordinatorPhase.awaitingOtp) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant PasswordlessAuthFlowScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinator == widget.coordinator) return;
    oldWidget.coordinator.removeListener(_coordinatorChanged);
    widget.coordinator.addListener(_coordinatorChanged);
  }

  @override
  void dispose() {
    widget.coordinator.removeListener(_coordinatorChanged);
    _countdown?.cancel();
    _phone.dispose();
    _code.dispose();
    _phoneFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _coordinatorChanged() {
    if (!mounted) return;
    if (widget.coordinator.phase == AuthCoordinatorPhase.awaitingOtp &&
        _codeFocus.canRequestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _codeFocus.requestFocus();
      });
    }
    setState(() {});
  }

  Future<void> _requestOtp() => widget.coordinator.requestOtp(_phone.text);

  Future<void> _verifyOtp() => widget.coordinator.verifyOtp(_code.text);

  @override
  Widget build(BuildContext context) {
    final coordinator = widget.coordinator;
    final challenge = coordinator.challenge;
    final waitingForCode = challenge != null &&
        {
          AuthCoordinatorPhase.awaitingOtp,
          AuthCoordinatorPhase.verifyingOtp,
          AuthCoordinatorPhase.requestingOtp,
        }.contains(coordinator.phase);
    final otpOperationBusy =
        coordinator.phase == AuthCoordinatorPhase.requestingOtp ||
            coordinator.phase == AuthCoordinatorPhase.verifyingOtp;

    if (coordinator.phase == AuthCoordinatorPhase.booting ||
        coordinator.phase == AuthCoordinatorPhase.refreshing) {
      return Scaffold(
        body: Center(
          child: Semantics(
            label: 'Restoring your secure session',
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (coordinator.phase == AuthCoordinatorPhase.recoverableFailure) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Session unavailable',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    coordinator.error?.message ??
                        'The saved session could not be restored.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('retry-session-restore'),
                    onPressed: coordinator.bootstrap,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: widget.logo ??
                    CircleAvatar(
                      radius: 28,
                      child: Text(
                        widget.applicationName.characters.first.toUpperCase(),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
              ),
              const SizedBox(height: 30),
              Text(
                waitingForCode
                    ? 'Verify your phone'
                    : _recoveryCopy
                        ? 'Recover access'
                        : 'Continue with your phone',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                waitingForCode
                    ? 'Enter the four- or six-digit code sent to '
                        '${challenge.destinationMasked}.'
                    : _recoveryCopy
                        ? 'Because this account is passwordless, a new phone '
                            'verification restores access.'
                        : 'New phone numbers create an account. Existing phone '
                            'numbers sign in securely.',
              ),
              const SizedBox(height: 28),
              if (!waitingForCode) ...[
                TextField(
                  key: const Key('auth-phone-number'),
                  controller: _phone,
                  focusNode: _phoneFocus,
                  enabled:
                      coordinator.phase != AuthCoordinatorPhase.requestingOtp,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  onSubmitted: (_) => _requestOtp(),
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '+12025550123',
                    prefixIcon: Icon(Icons.phone_outlined),
                    helperText: 'Include the country code.',
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('request-otp'),
                  onPressed:
                      coordinator.phase == AuthCoordinatorPhase.requestingOtp
                          ? null
                          : _requestOtp,
                  child: Text(
                    coordinator.phase == AuthCoordinatorPhase.requestingOtp
                        ? 'Requesting code…'
                        : 'Continue',
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  key: const Key('recover-access'),
                  onPressed: () {
                    setState(() => _recoveryCopy = !_recoveryCopy);
                    _phoneFocus.requestFocus();
                  },
                  child: Text(
                    _recoveryCopy
                        ? 'Back to sign in'
                        : 'Need to recover access?',
                  ),
                ),
              ] else ...[
                TextField(
                  key: const Key('auth-otp-code'),
                  controller: _code,
                  focusNode: _codeFocus,
                  enabled: !otpOperationBusy,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onSubmitted: (_) => _verifyOtp(),
                  decoration: const InputDecoration(
                    labelText: 'Verification code',
                    hintText: '0000 or 000000',
                    prefixIcon: Icon(Icons.password_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('verify-otp'),
                  onPressed: otpOperationBusy ? null : _verifyOtp,
                  child: Text(
                    coordinator.phase == AuthCoordinatorPhase.verifyingOtp
                        ? 'Verifying…'
                        : 'Verify and continue',
                  ),
                ),
                const SizedBox(height: 8),
                _ResendAction(
                  challenge: challenge,
                  busy: otpOperationBusy,
                  onResend: () async {
                    _code.clear();
                    await coordinator.resendOtp();
                  },
                ),
                TextButton(
                  key: const Key('change-phone-number'),
                  onPressed: otpOperationBusy
                      ? null
                      : () {
                          // A code belongs to exactly one challenge. Keeping
                          // the previous value after changing the destination
                          // can submit it against the replacement challenge.
                          _code.clear();
                          coordinator.cancelChallenge();
                        },
                  child: const Text('Change phone number'),
                ),
              ],
              if (coordinator.error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    coordinator.error!.message,
                    key: const Key('auth-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Your verification code, phone number, and session tokens are '
                'never written to application logs.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResendAction extends StatelessWidget {
  const _ResendAction({
    required this.challenge,
    required this.busy,
    required this.onResend,
  });

  final AuthChallenge challenge;
  final bool busy;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final remaining =
        challenge.resendAvailableAt.difference(DateTime.now()).inSeconds;
    final ready = remaining <= 0;
    return TextButton(
      key: const Key('resend-otp'),
      onPressed: ready && !busy ? onResend : null,
      child: Text(
        ready ? 'Send a new code' : 'Send a new code in ${remaining + 1}s',
      ),
    );
  }
}
