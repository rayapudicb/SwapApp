import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/medusa_flutter_theme.dart';
import '../providers/auth_provider.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _code = TextEditingController();
  Timer? _clock;
  bool _showCodeValidationError = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();

    final codeToVerify = _code.text.trim();
    if (!_isValidOtp(codeToVerify)) {
      setState(() => _showCodeValidationError = true);
      return;
    }

    await context.read<AuthProvider>().verifyOtp(codeToVerify);
  }

  Future<void> _resend(AuthProvider auth) async {
    FocusScope.of(context).unfocus();
    final previousChallenge = auth.challenge;
    await auth.resendOtp();
    if (!mounted || identical(previousChallenge, auth.challenge)) return;
    _code.clear();
    setState(() => _showCodeValidationError = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final challenge = auth.challenge;
    final medusa = context.medusa;
    final textTheme = Theme.of(context).textTheme;
    if (challenge == null) {
      return Scaffold(
        backgroundColor: medusa.bgSubtle,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sms_failed_outlined,
                    size: 48,
                    color: medusa.fgMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Request a new verification code',
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge?.copyWith(
                      color: medusa.fgBase,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This verification request is no longer available.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: medusa.fgSubtle,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: auth.cancelOtp,
                    child: const Text('Back to phone number'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final resendIn = challenge.resendAvailableAt.difference(now).inSeconds;
    final expiresIn = challenge.expiresAt.difference(now).inSeconds;

    return Scaffold(
      backgroundColor: medusa.bgSubtle,
      appBar: AppBar(
        backgroundColor: medusa.bgSubtle,
        leading: IconButton(
          tooltip: 'Change phone number',
          onPressed: auth.isAuthOperationBusy ? null : auth.cancelOtp,
          icon: Icon(Icons.arrow_back, color: medusa.fgBase),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: medusa.interactive,
                  borderRadius: BorderRadius.circular(MedusaTheme.radiusMedium),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.sms_outlined,
                  color: medusa.onColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verify your phone',
                style: textTheme.headlineMedium?.copyWith(
                  color: medusa.fgBase,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the code sent to ${challenge.destinationMasked}.',
                style: textTheme.bodyMedium?.copyWith(
                  color: medusa.fgSubtle,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              if (auth.errorMessage != null) ...[
                _ErrorBanner(message: auth.errorMessage!),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _code,
                enabled: !auth.isAuthOperationBusy,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                obscureText: true,
                obscuringCharacter: '•',
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: medusa.fgBase,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 10,
                ),
                decoration: InputDecoration(
                  labelText: 'Verification code',
                  hintText: '000000',
                  errorText: _showCodeValidationError
                      ? 'Enter a 4- or 6-digit code.'
                      : null,
                  counterText: expiresIn > 0
                      ? 'Expires in ${_duration(expiresIn)}'
                      : 'Code expired — request another',
                  counterStyle: textTheme.bodySmall?.copyWith(
                    color: expiresIn > 0 ? medusa.fgMuted : medusa.error,
                  ),
                ),
                onChanged: (_) {
                  if (auth.errorMessage != null) auth.clearError();
                  if (_showCodeValidationError) {
                    setState(() => _showCodeValidationError = false);
                  } else {
                    setState(() {});
                  }
                },
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed:
                      auth.isAuthOperationBusy ||
                          expiresIn <= 0 ||
                          !_isValidOtp(_code.text.trim())
                      ? null
                      : _verify,
                  style: FilledButton.styleFrom(
                    backgroundColor: medusa.buttonPrimary,
                    foregroundColor: medusa.onColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        MedusaTheme.radiusMedium,
                      ),
                    ),
                  ),
                  child: auth.isAuthOperationBusy
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: medusa.onColor,
                          ),
                        )
                      : const Text(
                          'Verify and continue',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: auth.isAuthOperationBusy || resendIn > 0
                      ? null
                      : () => _resend(auth),
                  style: TextButton.styleFrom(
                    foregroundColor: resendIn > 0
                        ? medusa.fgMuted
                        : medusa.interactive,
                  ),
                  child: Text(
                    resendIn > 0
                        ? 'Send another code in ${_duration(resendIn)}'
                        : 'Send another code',
                  ),
                ),
              ),
            ],
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

String _duration(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final minutes = safe ~/ 60;
  final remainder = safe % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

bool _isValidOtp(String code) =>
    RegExp(r'^(?:[0-9]{4}|[0-9]{6})$').hasMatch(code);
