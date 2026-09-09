import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manofit/core/theme/app_theme.dart';
import 'package:manofit/data/admin_demo_data.dart';
import 'package:manofit/screens/hr_admin_overview_screen.dart';
import 'package:manofit/widgets/dashboard/dashboard_kit.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [child],
          ),
        ),
      ),
    );

void main() {
  group('demo data integrity', () {
    test('accepted + rejected reconciles with the processed total', () {
      expect(kAcceptedRecords + kRejectedRecords, kTotalRecordsProcessed);
    });

    test('trend series are the same 12-week window', () {
      expect(kWellbeingIndexTrend.length, 12);
      expect(kElevatedShareTrend.length, 12);
      expect(kIngestionVolumeTrend.length, 12);
    });

    test('unit elevated counts never exceed headcount', () {
      for (final u in kUnitRisk) {
        expect(u.elevated, lessThanOrEqualTo(u.headcount), reason: u.unitCode);
      }
    });

    test('units are ordered worst-first so the ranking reads correctly', () {
      final severities = kUnitRisk.map((u) => u.severity).toList();
      final sorted = [...severities]..sort((a, b) => b.compareTo(a));
      expect(severities, sorted);
    });
  });

  group('dashboard kit renders at phone width', () {
    testWidgets('index tiles, share bar, ranked bars and sparkline', (t) async {
      await t.binding.setSurfaceSize(const Size(360, 1600));
      addTearDown(() => t.binding.setSurfaceSize(null));

      await t.pumpWidget(_host(Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeading(
              title: 'Cohort Risk Board',
              subtitle: 'Pseudonymized cohort',
              badge: 'On-device scoring'),
          TileGrid(children: [
            const IndexTile(
                label: 'Cohort evaluated', value: '24', icon: Icons.groups_outlined),
            IndexTile(
                label: 'Elevated band',
                value: '5',
                icon: Icons.priority_high_rounded,
                accent: AppColors.error,
                delta: -1.4,
                deltaGoodWhenNegative: true),
          ]),
          const SizedBox(height: 12),
          ChartCard(
            title: 'Risk band distribution',
            description: 'Where the cohort sits',
            child: StackedShareBar(segments: [
              ShareSegment('Low', 15, AppColors.statusPositive),
              ShareSegment('Moderate', 4, AppColors.statusCaution),
              ShareSegment('Elevated', 5, AppColors.statusDistress),
            ]),
          ),
          const SizedBox(height: 12),
          ChartCard(
            title: 'Unit severity ranking',
            child: RankedBarChart(
              maxValue: 100,
              rows: [
                for (final u in kUnitRisk)
                  RankedRow(u.name, u.severity, caption: u.unitCode),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const ChartCard(
              title: 'Composite wellbeing index',
              child: TrendChart(values: kWellbeingIndexTrend)),
        ],
      )));
      await t.pump();

      expect(find.text('Cohort Risk Board'), findsOneWidget);
      expect(find.byType(TrendChart), findsOneWidget);
    });

    testWidgets('executive summary card', (t) async {
      await t.binding.setSurfaceSize(const Size(360, 1200));
      addTearDown(() => t.binding.setSurfaceSize(null));

      await t.pumpWidget(_host(const ExecutiveSummaryCard(
        eyebrow: 'Executive summary',
        headline: '5 of 24 personnel are in the elevated band.',
        body: 'Composite wellbeing index sits at 73.1/100.',
        bullets: ['Unit 104 carries the highest strain.'],
        footnote: 'Tokens only — no names are rendered.',
      )));
      await t.pump();

      expect(find.textContaining('elevated band'), findsOneWidget);
    });
  });

  testWidgets('HR admin console renders at phone width', (t) async {
    await t.binding.setSurfaceSize(const Size(360, 2400));
    addTearDown(() => t.binding.setSurfaceSize(null));

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const HrAdminOverviewScreen(),
    ));
    await t.pump();

    expect(t.takeException(), isNull);
    // With no roster ingested the console shows only the ingest prompt — no
    // synthetic cohort, no individual-level output (PRD §6.4).
    expect(find.text('Ingest a duty roster to begin'), findsOneWidget);
    expect(find.textContaining('1,248'), findsNothing);
    expect(find.textContaining('UID-'), findsNothing);
    expect(find.textContaining('Cases awaiting clinical review'), findsNothing);
  });
}
