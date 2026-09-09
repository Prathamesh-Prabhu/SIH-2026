import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'services/auth_service.dart';
import 'services/db_service.dart';
import 'services/ml_service.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load `.env` (bundled as an asset). Missing file is non-fatal — the app
  // then runs on its resilient mock/demo fallback.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    dotenv.testLoad(fileInput: '');
  }

  final supabaseService = SupabaseService();
  await supabaseService.init();

  final authService = AuthService();
  await authService.init();

  final dbService = DbService();
  await dbService.init();

  // Probe the Analytics & ML microservice in the background — the app stays
  // fully usable on its fallback heuristics if the service is not running.
  final mlService = MlService();
  unawaited(mlService.init());

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
