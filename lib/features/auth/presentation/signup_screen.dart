import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/medusa_flutter_theme.dart';
import '../providers/auth_provider.dart';
import 'auth_form_validation.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    auth.clearError();
    await auth.requestLoginOtp(_phoneCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final medusa = context.medusa;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: medusa.bgSubtle,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  // Brand Mark
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: medusa.interactive,
                      borderRadius: BorderRadius.circular(
                        MedusaTheme.radiusMedium,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'S',
                        style: TextStyle(
                          color: medusa.onColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  Text(
                    'Create account',
                    style: textTheme.headlineMedium?.copyWith(
                      color: medusa.fgBase,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Verify your phone, then set up your Swappy profile.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: medusa.fgSubtle,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (auth.errorMessage != null) ...[
                    _ErrorBanner(message: auth.errorMessage!),
                    const SizedBox(height: 16),
                  ],

                  // Phone field
                  TextFormField(
                    controller: _phoneCtrl,
                    enabled: !auth.isAuthOperationBusy,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    style: TextStyle(color: medusa.fgBase, fontSize: 16),
                    validator: validateInternationalPhone,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '+1 234 567 8900',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: auth.isAuthOperationBusy ? null : _submit,
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
                          ? Semantics(
                              liveRegion: true,
                              label: 'Sending verification code',
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: medusa.onColor,
                                ),
                              ),
                            )
                          : const Text(
                              'Send verification code',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: textTheme.bodyMedium?.copyWith(
                          color: medusa.fgSubtle,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          auth.clearError();
                          context.go('/login');
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: medusa.interactive,
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Log in'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      'New here? We will ask for your display name after your '
                      'phone is verified.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: medusa.fgMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
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
            IconButton(
              tooltip: 'Dismiss error',
              onPressed: context.read<AuthProvider>().clearError,
              icon: Icon(Icons.close, color: medusa.tagRedText, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
