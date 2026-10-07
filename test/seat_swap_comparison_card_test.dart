import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swappy_mobile/features/exchange/presentation/models/swap_comparison_view_data.dart';
import 'package:swappy_mobile/features/exchange/presentation/widgets/seat_swap_comparison_card.dart';

void main() {
  testWidgets('renders give and receive seats without protected identifiers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_app(_comparison()));

      expect(find.text('YOU GIVE'), findsOneWidget);
      expect(find.text('YOU RECEIVE'), findsOneWidget);
      expect(find.textContaining('Section 305'), findsOneWidget);
      expect(find.textContaining('Section 101'), findsOneWidget);
      expect(find.text('Photo details checked'), findsNWidgets(2));
      expect(
        find.bySemanticsLabel(RegExp(r'YOU GIVE.*Section 305.*Seats 22')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'YOU RECEIVE.*Section 101.*Seats 12')),
        findsOneWidget,
      );
      expect(find.textContaining('private-bundle-id'), findsNothing);
      expect(find.textContaining('barcode'), findsNothing);
      expect(find.textContaining('booking'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('stacks safely on a narrow screen with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        _comparison(longAssignment: true),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  SwapComparisonViewData comparison, {
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(textScaler: textScaler),
    child: Scaffold(
      body: SingleChildScrollView(
        child: SeatSwapComparisonCard(
          comparison: comparison,
          title: 'Your proposed swap',
        ),
      ),
    ),
  ),
);

SwapComparisonViewData _comparison({bool longAssignment = false}) =>
    SwapComparisonViewData(
      youGive: SwapSeatViewData(
        title: 'City Finals',
        venue: 'City Arena',
        assignment: longAssignment
            ? 'Section ${List.filled(80, '3').join()} · '
                  'Row ${List.filled(40, 'F').join()} · Seats 22, 23, 24'
            : 'Section 305 · Row F · Seats 22',
        shortAssignment: 'Section 305 · Row F · Seats 22',
        quantity: 1,
        trustLabel: 'Photo details checked',
        trustExplanation:
            'Ownership, validity and transferability are not verified.',
      ),
      youReceive: const SwapSeatViewData(
        title: 'City Finals',
        venue: 'City Arena',
        assignment: 'Section 101 · Row B · Seats 12',
        shortAssignment: 'Section 101 · Row B · Seats 12',
        quantity: 1,
        trustLabel: 'Photo details checked',
        trustExplanation:
            'Ownership, validity and transferability are not verified.',
      ),
      cashSummary: 'No cash difference',
    );
