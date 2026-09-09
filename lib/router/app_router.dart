import 'package:go_router/go_router.dart';
import '../core/auth/role_access.dart';
import '../services/auth_service.dart';
import '../screens/landing_screen.dart';
import '../screens/login_service_id_screen.dart';
import '../screens/otp_verification_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/home_screen.dart';
import '../screens/mood_check_in_screen.dart';
import '../screens/wellbeing_check_in_screen.dart';
import '../screens/checkins_hub_screen.dart';
import '../data/assessment_cadence.dart';
import '../screens/tara/tara_screen.dart';
import '../screens/mindfulness/mindfulness_screen.dart';
import '../screens/mindfulness/breathing_exercises_screen.dart';
import '../screens/mindfulness/meditation_screen.dart';
import '../screens/mindfulness/mindfulness_history_screen.dart';
import '../screens/mindfulness/mood_checkin_flow_screen.dart';
import '../screens/mindfulness/doodle_activity_screen.dart';
import '../screens/book_session_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/hr_admin_overview_screen.dart';
import '../screens/hr_data_ingestion_screen.dart';
import '../screens/hr_mobile_ingestion_review_screen.dart';
import '../screens/hr_risk_analytics_screen.dart';
import '../screens/institutional_resilience_screen.dart';
import '../screens/oversight_board_screen.dart';
import '../screens/active_alerts_screen.dart';

class AppRouter {
  /// Routes reachable without a session.
  static const _publicRoutes = {'/landing', '/login'};

  static final GoRouter router = GoRouter(
    initialLocation: '/landing',
    refreshListenable: AuthService(),
    redirect: (context, state) {
      final auth = AuthService();
      final loc = state.matchedLocation;
      final signedIn = auth.isAuthenticated;

      if (!signedIn) {
        return _publicRoutes.contains(loc) ? null : '/landing';
      }

      // Signed in but consent charter not yet accepted.
      if (!auth.onboardingComplete) {
        return loc == '/onboarding' ? null : '/onboarding';
      }

      // Signed in and onboarded — keep them out of the auth funnel, and send
      // each role to its own console rather than the personnel home.
      final home = auth.currentRole.homeRoute;
      if (_publicRoutes.contains(loc) || loc == '/onboarding') {
        return home;
      }

      // Structural RBAC (PRD §6.6): a role may only open the routes its
      // console owns. Deep-linking anything else lands back on its own home.
      if (!auth.currentRole.canAccess(loc)) {
        return home;
      }
      return null;
    },
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
        path: '/checkins',
        builder: (context, state) => const CheckInsHubScreen(),
      ),
      GoRoute(
        path: '/wellbeing',
        builder: (context, state) => WellbeingCheckInScreen(
          cadence: cadenceFromId(state.uri.queryParameters['cadence']),
        ),
      ),
      GoRoute(
        path: '/tara',
        builder: (context, state) => const TaraScreen(),
      ),
      GoRoute(
        path: '/mindfulness',
        builder: (context, state) => const MindfulnessScreen(),
      ),
      GoRoute(
        path: '/mindfulness/breathing',
        builder: (context, state) => const BreathingExercisesScreen(),
      ),
      GoRoute(
        path: '/mindfulness/meditation',
        builder: (context, state) => const MeditationScreen(),
      ),
      GoRoute(
        path: '/mindfulness/history',
        builder: (context, state) => const MindfulnessHistoryScreen(),
      ),
      GoRoute(
        path: '/mindfulness/mood',
        builder: (context, state) => const MoodCheckInFlowScreen(),
      ),
      GoRoute(
        path: '/mindfulness/doodle',
        builder: (context, state) => const DoodleActivityScreen(),
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
      GoRoute(
        path: '/oversight',
        builder: (context, state) => const OversightBoardScreen(),
      ),
      GoRoute(
        path: '/active-alerts',
        builder: (context, state) => const ActiveAlertsScreen(),
      ),
    ],
  );
}
