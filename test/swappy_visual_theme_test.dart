import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swappy_mobile/core/theme/swappy_theme.dart';

void main() {
  test('Swappy themes expose a complete expressive token layer', () {
    final light = SwappyTheme.light.extension<SwappyVisualTokens>();
    final dark = SwappyTheme.dark.extension<SwappyVisualTokens>();

    expect(light, same(SwappyVisualTokens.light));
    expect(dark, same(SwappyVisualTokens.dark));
    expect(SwappyTheme.light.colorScheme.primary, light!.brandViolet);
    expect(SwappyTheme.dark.colorScheme.secondary, dark!.neonCyan);
    expect(light.eventPalette(SwappyEventTone.music).secondary, light.neonCyan);
    expect(
      dark.eventPalette(SwappyEventTone.sports).primary,
      dark.sportsPrimary,
    );
  });

  testWidgets('dock uses glass and icon stroke without a selection pill', (
    tester,
  ) async {
    var selectedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: SwappyTheme.dark,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            bottomNavigationBar: SwappyFloatingDock(
              destinations: const [
                SwappyDockDestination(icon: Icons.home_outlined, label: 'Home'),
                SwappyDockDestination(
                  icon: Icons.swap_horiz_outlined,
                  label: 'Swaps',
                ),
              ],
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                setState(() => selectedIndex = index);
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SwappyGlassSurface), findsOneWidget);
    expect(
      find.byKey(const ValueKey('swappy-dock-selected-icon-stroke-0')),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('Swaps'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('swappy-dock-selected-icon-stroke-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('swappy-dock-selected-icon-stroke-0')),
      findsNothing,
    );
  });
}
