import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swappy_mobile/core/bootstrap/domain/platform_bootstrap.dart';
import 'package:swappy_mobile/core/bootstrap/presentation/legal_document_screen.dart';

void main() {
  testWidgets('renders a validated published legal document', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LegalDocumentScreen(
          slug: 'privacy-policy',
          fallbackTitle: 'Privacy Policy',
          loader: (_) async => LegalDocument(
            slug: 'privacy-policy',
            title: 'Privacy Policy',
            version: 3,
            contentMarkdown: 'How Swappy handles participant data.',
            contentDigest:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            locale: 'en-US',
            jurisdiction: 'US',
            effectiveAt: DateTime.utc(2026, 8, 24),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Privacy Policy'), findsWidgets);
    expect(find.textContaining('Version 3'), findsOneWidget);
    expect(find.textContaining('participant data'), findsOneWidget);
  });

  testWidgets('redacts loader errors and supports retry', (tester) async {
    var attempts = 0;
    Future<LegalDocument> load(String _) async {
      attempts++;
      if (attempts == 1) throw StateError('private transport detail');
      return LegalDocument(
        slug: 'terms-of-service',
        title: 'Terms of Service',
        version: 1,
        contentMarkdown: 'Approved terms.',
        contentDigest:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        locale: 'en-US',
        jurisdiction: 'US',
        effectiveAt: DateTime.utc(2026, 8, 24),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: LegalDocumentScreen(
          slug: 'terms-of-service',
          fallbackTitle: 'Terms of Service',
          loader: load,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Document unavailable'), findsOneWidget);
    expect(find.textContaining('private transport detail'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Approved terms.'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('remains scrollable at large accessibility text sizes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: LegalDocumentScreen(
          slug: 'eula',
          fallbackTitle: 'End User License Agreement',
          loader: (_) async => LegalDocument(
            slug: 'eula',
            title: 'End User License Agreement',
            version: 1,
            contentMarkdown: List.filled(
              20,
              'Review this approved policy section.',
            ).join('\n\n'),
            contentDigest:
                'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
            locale: 'en-US',
            jurisdiction: 'US',
            effectiveAt: DateTime.utc(2026, 8, 24),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsWidgets);
  });
}
