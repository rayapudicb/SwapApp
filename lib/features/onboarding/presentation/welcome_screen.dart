import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_locale_provider.dart';
import '../../../core/localization/presentation/language_settings_screen.dart';
import '../../../core/theme/medusa_flutter_theme.dart';
import '../../auth/providers/auth_provider.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.tag,
  });

  final IconData icon;
  final String title;
  final String description;
  final String tag;
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingItem> _items = [
    _OnboardingItem(
      icon: Icons.confirmation_number_outlined,
      tag: 'Event Seat Swaps',
      title: 'Swap seats live with fellow fans',
      description:
          'Upgrade your viewpoint, sit closer with friends, or find better rows at concerts, matches, and live theater.',
    ),
    _OnboardingItem(
      icon: Icons.fact_check_outlined,
      tag: 'Clear Ticket Checks',
      title: 'Know what Swappy has checked',
      description:
          'Event matching and ticket evidence are shown separately from ownership, validity, and transferability so you can make an informed choice.',
    ),
    _OnboardingItem(
      icon: Icons.sync_alt_outlined,
      tag: 'Frictionless Experience',
      title: 'Post offers & discover seats',
      description:
          'Publish a seat offer, browse compatible Posts, send a Swap Request, and follow each step until both fans confirm handoff.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onContinue() {
    context.read<AuthProvider>().setHasSeenWelcome(true);
  }

  @override
  Widget build(BuildContext context) {
    final medusa = context.medusa;
    final textTheme = Theme.of(context).textTheme;
    final localeProvider = Provider.of<AppLocaleProvider?>(context);

    return Scaffold(
      backgroundColor: medusa.bgSubtle,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar / Skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
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
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Swappy',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              color: medusa.fgBase,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (localeProvider != null)
                        IconButton(
                          tooltip: 'Language',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const LanguageSettingsScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.translate),
                        ),
                      if (_currentPage < _items.length - 1)
                        TextButton(
                          onPressed: _onContinue,
                          style: TextButton.styleFrom(
                            foregroundColor: medusa.fgSubtle,
                          ),
                          child: const Text('Skip'),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Carousel Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - 32).clamp(
                            0,
                            double.infinity,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon Hero Card
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: medusa.bgBase,
                                borderRadius: BorderRadius.circular(
                                  MedusaTheme.radiusLarge,
                                ),
                                border: Border.all(color: medusa.borderBase),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(
                                      context,
                                    ).shadowColor.withValues(alpha: 0.04),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  item.icon,
                                  size: 56,
                                  color: medusa.interactive,
                                ),
                              ),
                            ),
                            const SizedBox(height: 36),

                            // Pill tag
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: medusa.bgHighlight,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: medusa.interactive.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Text(
                                item.tag,
                                style: textTheme.labelSmall?.copyWith(
                                  color: medusa.interactive,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Title
                            Text(
                              item.title,
                              textAlign: TextAlign.center,
                              style: textTheme.headlineSmall?.copyWith(
                                color: medusa.fgBase,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Description
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                item.description,
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: medusa.fgSubtle,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Indicators & Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  // Page Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_items.length, (index) {
                      final isCurrent = _currentPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        width: isCurrent ? 24.0 : 8.0,
                        height: 8.0,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: isCurrent
                              ? medusa.interactive
                              : medusa.borderStrong,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 50),
                      child: FilledButton(
                        onPressed: () {
                          if (_currentPage < _items.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            _onContinue();
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: medusa.buttonPrimary,
                          foregroundColor: medusa.onColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              MedusaTheme.radiusMedium,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        child: Text(
                          _currentPage == _items.length - 1
                              ? 'Get Started'
                              : 'Next',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
