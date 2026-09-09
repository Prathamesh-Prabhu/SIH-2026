import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manofit/core/theme/app_theme.dart';
import 'package:manofit/screens/self_help/ambient_sound_player.dart';
import 'package:manofit/screens/self_help/breathing_calmer.dart';
import 'package:manofit/screens/self_help/doodle_canvas.dart';
import 'package:manofit/screens/self_help/grounding_exercise.dart';
import 'package:manofit/screens/self_help/worry_dissolver.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [child],
          ),
        ),
      ),
    );

void main() {
  testWidgets('DoodleCanvas builds', (t) async {
    await t.pumpWidget(_host(const DoodleCanvas()));
    await t.pump();
  });

  testWidgets('BreathingCalmer builds', (t) async {
    await t.pumpWidget(_host(const BreathingCalmer()));
    await t.pump();
  });

  testWidgets('GroundingExercise builds', (t) async {
    await t.pumpWidget(_host(const GroundingExercise()));
    await t.pump();
  });

  testWidgets('WorryDissolver builds', (t) async {
    await t.pumpWidget(_host(const WorryDissolver()));
    await t.pump();
  });

  testWidgets('AmbientSoundPlayer builds', (t) async {
    await t.pumpWidget(_host(const AmbientSoundPlayer()));
    await t.pump();
  });
}
