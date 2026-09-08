import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'services/auth_service.dart';
import 'services/db_service.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supabaseService = SupabaseService();
  await supabaseService.init();

  final authService = AuthService();
  await authService.init();

  final dbService = DbService();
  await dbService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: supabaseService),
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: dbService),
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
