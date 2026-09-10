import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'core/tara_config.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'services/auth_service.dart';
import 'services/db_service.dart';
import 'services/ml_service.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Startup must never take the whole app down with it — on a release build a
  // thrown exception here just yields a black screen. Every step is isolated
  // and best-effort; the app can always fall back to its mock/demo mode.
  Future<void> step(String label, Future<void> Function() body) async {
    try {
      await body();
    } catch (e, st) {
      debugPrint('ManoFit startup: "$label" failed (continuing): $e\n$st');
    }
  }

  // Load `.env` (bundled as an asset). Missing file is non-fatal.
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('ManoFit startup: dotenv load failed (continuing): $e');
    dotenv.testLoad(fileInput: '');
  }

  final supabaseService = SupabaseService();
  await step('supabase.init', supabaseService.init);

  final authService = AuthService();
  await step('auth.init', authService.init);

  final dbService = DbService();
  await step('db.init', dbService.init);

  // Probe the Analytics & ML microservice in the background — adopts dynamic
  // Supabase endpoints if published by start-backends.ps1, or falls back to
  // .env / heuristics.
  final mlService = MlService();
  unawaited(mlService.init(remoteEndpoint: supabaseService.remoteMlUrl));

  // Apply any dynamic Tara relay URL from Supabase / saved override before the WebView opens.
  await step('tara.load',
      () => TaraConfig.load(remoteEndpoint: supabaseService.remoteTaraUrl));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: supabaseService),
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: dbService),
        ChangeNotifierProvider.value(value: mlService),
      ],
      child: const ManoFitApp(),
    ),
  );
}

class ManoFitApp extends StatelessWidget {
  const ManoFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ManoFit - Personnel Welfare Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}
