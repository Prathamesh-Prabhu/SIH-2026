import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manofit/core/theme/app_theme.dart';
import 'package:manofit/screens/hr_admin_overview_screen.dart';

/// Smoke tests for the HR Admin console home.
///
/// The console now reports only on rosters the HR Admin has ingested. With no
/// roster ingested it must render the ingest prompt cleanly at both
/// breakpoints (the app theme's infinite-min-width buttons blank the route
/// inside an unbounded Row, so pumping surfaces that immediately) and must
/// never show a synthetic cohort or individual-level output.
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
    expect(find.text('Building a Healthier Force'), findsOneWidget);
  });

  testWidgets('renders on a wide (web console) viewport', (tester) async {
    await pumpAt(tester, const Size(1280, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('Ingest a duty roster to begin'), findsOneWidget);
    expect(find.text('Open Data Ingestion'), findsWidgets);
  });

  testWidgets('shows no synthetic cohort before any roster is ingested',
      (tester) async {
    await pumpAt(tester, const Size(1280, 900));
    // The old console hard-coded a 1,248-person cohort and a 78% coverage tile.
    expect(find.textContaining('1,248'), findsNothing);
    expect(find.text('78%'), findsNothing);
    expect(find.text('0'), findsWidgets); // "0  Personnel in DB"
  });

  testWidgets('keeps individual-level records out of the HR view',
      (tester) async {
    await pumpAt(tester, const Size(1280, 900));
    for (final forbidden in [
      'UID-',
      'pseudonym token',
      'Cases awaiting clinical review',
      'Contributing factors',
    ]) {
      expect(find.textContaining(forbidden), findsNothing,
          reason: 'HR Admin must never see individual-level output: "$forbidden"');
    }
  });
}
