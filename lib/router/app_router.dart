import 'package:go_router/go_router.dart';
import '../screens/landing_screen.dart';
import '../screens/login_service_id_screen.dart';
import '../screens/otp_verification_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/home_screen.dart';
import '../screens/mood_check_in_screen.dart';
import '../screens/wellbeing_check_in_screen.dart';
import '../screens/self_help_screen.dart';
import '../screens/ai_companion_screen.dart';
import '../screens/book_session_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/hr_admin_overview_screen.dart';
import '../screens/hr_data_ingestion_screen.dart';
import '../screens/hr_mobile_ingestion_review_screen.dart';
import '../screens/hr_risk_analytics_screen.dart';
import '../screens/institutional_resilience_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/landing',
    routes: [
      GoRoute(
        path: '/landing',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginServiceIdScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) => const OtpVerificationScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/mood',
        builder: (context, state) => const MoodCheckInScreen(),
      ),
      GoRoute(
        path: '/wellbeing',
        builder: (context, state) => const WellbeingCheckInScreen(),
      ),
      GoRoute(
        path: '/self-help',
        builder: (context, state) => const SelfHelpScreen(),
      ),
      GoRoute(
        path: '/companion',
        builder: (context, state) => const AiCompanionScreen(),
      ),
      GoRoute(
        path: '/book',
        builder: (context, state) => const BookSessionScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/hr-overview',
        builder: (context, state) => const HrAdminOverviewScreen(),
      ),
      GoRoute(
        path: '/hr-ingestion',
        builder: (context, state) => const HrDataIngestionScreen(),
      ),
      GoRoute(
        path: '/hr-mobile-review',
        builder: (context, state) => const HrMobileIngestionReviewScreen(),
      ),
      GoRoute(
        path: '/hr-analytics',
        builder: (context, state) => const HrRiskAnalyticsScreen(),
      ),
      GoRoute(
        path: '/resilience',
        builder: (context, state) => const InstitutionalResilienceScreen(),
      ),
    ],
  );
}
