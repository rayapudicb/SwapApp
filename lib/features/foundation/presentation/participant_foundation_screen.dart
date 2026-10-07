import 'package:flutter/material.dart';
import 'package:swappy_mobile/core/theme/swappy_theme.dart';
import 'package:swappy_mobile/features/exchange/presentation/post_exchange_screen.dart';
import 'package:swappy_mobile/features/exchange/presentation/swap_intents_screen.dart';
import 'package:swappy_mobile/features/home/presentation/home_feed_screen.dart';
import 'package:swappy_mobile/features/profile/presentation/profile_screen.dart';

class ParticipantFoundationScreen extends StatefulWidget {
  const ParticipantFoundationScreen({super.key});

  @override
  State<ParticipantFoundationScreen> createState() =>
      _ParticipantFoundationScreenState();
}

class _ParticipantFoundationScreenState
    extends State<ParticipantFoundationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final transitionDuration = SwappyMotion.duration(
      context,
      SwappyMotion.standard,
    );
    final screen = switch (_currentIndex) {
      0 => HomeFeedScreen(
        onProfileTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
      ),
      1 => const PostExchangeScreen(),
      _ => const SwapIntentsScreen(),
    };
    return Scaffold(
      extendBody: true,
      body: MediaQuery(
        data: mediaQuery.copyWith(
          padding: mediaQuery.padding.copyWith(
            bottom: mediaQuery.padding.bottom + 86,
          ),
        ),
        child: AnimatedSwitcher(
          duration: transitionDuration,
          switchInCurve: SwappyMotion.fluid,
          switchOutCurve: SwappyMotion.fluid,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.992, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(_currentIndex), child: screen),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SwappyFloatingDock(
          destinations: const [
            SwappyDockDestination(icon: Icons.home_outlined, label: 'Home'),
            SwappyDockDestination(icon: Icons.add_box_outlined, label: 'Post'),
            SwappyDockDestination(
              icon: Icons.swap_horiz_outlined,
              label: 'Swaps',
            ),
          ],
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            if (index == _currentIndex) return;
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}
