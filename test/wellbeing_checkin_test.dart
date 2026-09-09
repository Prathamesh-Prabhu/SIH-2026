import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manofit/core/theme/app_theme.dart';
import 'package:manofit/data/wellbeing_checkins.dart';
import 'package:manofit/screens/wellbeing_check_in_screen.dart';

void main() {
  group('check-in definition', () {
    test('is exactly the 6 check-ins the PRD and ML layer expect', () {
      expect(kWellbeingCheckIns.length, 6);
      expect(
        kWellbeingCheckIns.map((e) => e.key).toSet(),
        {
          'workload_perception',
          'sleep_quality',
          'physical_exhaustion',
          'mood_rating',
          'manager_relationship',
          'peer_social_support',
        },
      );
    });

    test('every item offers exactly five options', () {
      for (final item in kWellbeingCheckIns) {
        expect(item.labels.length, 5, reason: item.key);
      }
    });

    test('scale direction matches the ML contract', () {
      // DbService._generateDemoCohort / MlService treat these as higher = worse.
      for (final key in ['workload_perception', 'physical_exhaustion']) {
        expect(kWellbeingCheckIns.firstWhere((e) => e.key == key).higherIsBetter,
            isFalse,
            reason: '$key must be higher = worse');
      }
      for (final key in [
        'sleep_quality',
        'mood_rating',
        'manager_relationship',
        'peer_social_support'
      ]) {
        expect(kWellbeingCheckIns.firstWhere((e) => e.key == key).higherIsBetter,
            isTrue,
            reason: '$key must be higher = better');
      }
    });
  });

  group('orientedWellbeingTotal', () {
    test('best possible answers score 30', () {
      final best = {
        for (final i in kWellbeingCheckIns) i.key: i.higherIsBetter ? 5 : 1
      };
      expect(orientedWellbeingTotal(best), 30);
    });

    test('worst possible answers score 6', () {
      final worst = {
        for (final i in kWellbeingCheckIns) i.key: i.higherIsBetter ? 1 : 5
      };
      expect(orientedWellbeingTotal(worst), 6);
    });

    test('all-neutral answers score 18', () {
      final mid = {for (final i in kWellbeingCheckIns) i.key: 3};
      expect(orientedWellbeingTotal(mid), 18);
    });

    test('skipped items are ignored, not treated as neutral', () {
      expect(orientedWellbeingTotal({'mood_rating': 5}), 5);
    });
  });

  testWidgets('walks all six pages and reaches submit', (t) async {
    // Tall surface so the whole form is in the viewport; the default 800x600
    // puts the Next button below the fold and taps silently miss.
    await t.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const WellbeingCheckInScreen(),
    ));

    for (var i = 0; i < kWellbeingCheckIns.length; i++) {
      final item = kWellbeingCheckIns[i];
      expect(find.text(item.question), findsOneWidget,
          reason: 'page ${i + 1} should show ${item.key}');
      expect(find.text('${i + 1} of 6'), findsOneWidget);

      // Advancing is blocked until an option is chosen.
      final next = find.byType(ElevatedButton);
      expect(t.widget<ElevatedButton>(next).onPressed, isNull,
          reason: 'page ${i + 1} should block Next before an answer');

      await t.tap(find.text(item.labels[2]));
      await t.pump();

      if (i < kWellbeingCheckIns.length - 1) {
        await t.tap(find.text('Next'));
        await t.pumpAndSettle();
      }
    }

    expect(find.text('Submit Check-in'), findsOneWidget);
  });
}
