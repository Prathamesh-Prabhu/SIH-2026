import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manofit/core/theme/app_theme.dart';
import 'package:manofit/screens/hr_admin_overview_screen.dart';

/// Smoke tests for the HR console.
///
/// The app theme gives every button an infinite minimum width
/// (`minimumSize: Size.fromHeight(52)`), which throws inside an unbounded-width
/// parent like a Row and blanks the whole route to a near-white screen at
/// runtime. Pumping the screen at both breakpoints surfaces that immediately.
void main() {
  Widget harness() => MaterialApp(
        theme: AppTheme.lightTheme,
        home: const HrAdminOverviewScreen(),
      );

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness());
    await tester.pump();
  }

  testWidgets('renders on a narrow (mobile) viewport', (tester) async {
    await pumpAt(tester, const Size(420, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('HR Dashboard'), findsOneWidget);
  });

  testWidgets('renders on a wide (web console) viewport', (tester) async {
    await pumpAt(tester, const Size(1280, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('HR Dashboard'), findsOneWidget);
    expect(find.text('Ingestion sources'), findsOneWidget);
    expect(find.text('Recent ingestion activity'), findsOneWidget);
  });

  testWidgets('shows the three PRD ingestion tiers', (tester) async {
    await pumpAt(tester, const Size(1280, 900));
    expect(find.text('HRMS integration (Tier 1)'), findsOneWidget);
    expect(find.text('CSV / XLSX upload (Tier 2)'), findsOneWidget);
    expect(find.text('Manual entry (Tier 3)'), findsOneWidget);
  });

  testWidgets('exposes no risk-model output to HR (PRD 6.4)', (tester) async {
    await pumpAt(tester, const Size(1280, 900));
    for (final forbidden in ['ELEVATED', 'MODERATE', 'Risk band', 'risk score']) {
      expect(find.textContaining(forbidden), findsNothing,
          reason: 'HR Admin must never see analytics output: "$forbidden"');
    }
  });
}
