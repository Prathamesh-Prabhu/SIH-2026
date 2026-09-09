import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/navigation.dart';
import '../core/theme/app_theme.dart';
import '../data/badges.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../services/supabase_service.dart';
import '../widgets/supabase_settings_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<DbService>().refreshMindfulness(),
    );
  }

  /// Effective streak = the profile streak, or the number of distinct days the
  /// user has actually logged something, whichever is higher — so activity in
  /// the demo can push the rank up.
  int _effectiveStreak(DbService db, int profileStreak) {
    final days = <String>{};
    for (final m in db.mindfulnessMoods) {
      final d = (m['created_at'] as String?)?.split('T').first;
      if (d != null) days.add(d);
    }
    for (final l in db.mindfulnessLogs) {
      final d = (l['created_at'] as String?)?.split('T').first;
      if (d != null) days.add(d);
    }
    return days.length > profileStreak ? days.length : profileStreak;
  }

  BadgeStats _stats(DbService db, int streak) {
    int typed(String t) =>
        db.mindfulnessLogs.where((l) => l['activity_type'] == t).length;
    final minutes = db.mindfulnessLogs.fold<int>(
        0, (a, l) => a + (((l['actual_seconds'] as num?)?.toInt() ?? 0) ~/ 60));
    return BadgeStats(
      streak: streak,
      breathingSessions: typed('breathing'),
      meditationSessions: typed('meditation'),
      doodles: typed('doodle'),
      moodCheckIns: db.mindfulnessMoods.length + db.moodLogs.length,
      mindfulMinutes: minutes,
      taraSessions: db.taraSessions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final db = context.watch<DbService>();
    final supabase = SupabaseService();
    final user = auth.currentUser;

    final streak = _effectiveStreak(db, user?.streakCount ?? 0);
    final rank = rankForStreak(streak);
    final next = nextRank(streak);
    final stats = _stats(db, streak);
    final earned = earnedBadgeCount(stats);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.backOr('/home'),
        ),
        title: const Text('Personnel Profile',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RankHero(rank: rank, next: next, streak: streak),
              const SizedBox(height: 16),

              _identityCard(user, rank, streak),
              const SizedBox(height: 20),

              // ── Badge collection ──────────────────────────────────────
              Row(
                children: [
                  const Text('Achievements',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurfaceVariant)),
                  const Spacer(),
                  Text('$earned / ${kMilestoneBadges.length} earned',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary)),
                ],
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.72,
                children: [
                  for (final b in kMilestoneBadges)
                    _BadgeTile(
                      badge: b,
                      value: b.value(stats),
                      onTap: () => _showBadgeDetail(b, b.value(stats)),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Trust banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryFixed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.lock,
                          size: 18, color: AppColors.onSecondaryFixedVariant),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Military-Grade Confidentiality',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary)),
                          Text(
                            'Zero command-hierarchy visibility into check-in '
                            'inputs. RLS enforced.',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('Service & Security',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    _settingsTile(
                      icon: Icons.hub_outlined,
                      title: 'Backend Connection',
                      subtitle: supabase.isMockMode
                          ? 'Demo / offline fallback mode'
                          : 'Connected • ${supabase.currentUrl}',
                      onTap: () => SupabaseSettingsDialog.show(context),
                    ),
                    const Divider(height: 1),
                    _settingsTile(
                      icon: Icons.verified_user_outlined,
                      title: 'Data & Privacy Explainer',
                      subtitle:
                          'DPDP Act 2023 compliance & consent audit ledger',
                      onTap: () => context.push('/onboarding'),
                    ),
                    const Divider(height: 1),
                    _settingsTile(
                      icon: Icons.badge_outlined,
                      title: 'Role',
                      subtitle: user?.role.displayName ?? 'Personnel',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await auth.signOut();
                    if (context.mounted) context.go('/landing');
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign Out from Terminal',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.errorContainer),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _identityCard(dynamic user, StreakRank rank, int streak) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.secondaryContainer,
                    child: Text(
                      (user?.fullName.isNotEmpty == true)
                          ? user!.fullName[0]
                          : 'P',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSecondaryContainer),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: rank.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.surfaceContainerLowest, width: 2),
                      ),
                      child: Icon(rank.icon, size: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user?.fullName ?? 'Constable Dhruv',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            size: 16, color: AppColors.secondary),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID ${user?.serviceId ?? 'CAPF-8821'} • ${user?.rank ?? 'Constable'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                    Text(
                      user?.unit ?? '144th Bn CAPF',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _metricTile('$streak', 'Day Streak', rank.color),
              _metricTile('${user?.readinessScore ?? 88}%', 'Readiness',
                  AppColors.secondary),
              _metricTile(user?.stressZone ?? 'Zone A', 'Stress Level',
                  AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  void _showBadgeDetail(MilestoneBadge b, int value) {
    final earned = value >= b.goal;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 18),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: earned
                    ? b.color.withValues(alpha: 0.16)
                    : AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(b.icon,
                  size: 34,
                  color: earned ? b.color : AppColors.outline),
            ),
            const SizedBox(height: 12),
            Text(b.name,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
            const SizedBox(height: 4),
            Text(b.blurb,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                    height: 1.4)),
            const SizedBox(height: 16),
            if (earned)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 16, color: b.color),
                  const SizedBox(width: 6),
                  Text('Earned',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: b.color)),
                ],
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (value / b.goal).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(b.color),
                ),
              ),
              const SizedBox(height: 8),
              Text('$value / ${b.goal}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricTile(String value, String label, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: valueColor)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary)),
      subtitle: Text(subtitle,
          style: const TextStyle(
              fontSize: 11, color: AppColors.onSurfaceVariant)),
      trailing:
          const Icon(Icons.chevron_right, color: AppColors.outline, size: 18),
      onTap: onTap,
    );
  }
}

// ── Rank hero ─────────────────────────────────────────────────────────────
class _RankHero extends StatelessWidget {
  const _RankHero({required this.rank, required this.next, required this.streak});

  final StreakRank rank;
  final StreakRank? next;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final span = next == null ? 1 : (next!.minStreak - rank.minStreak);
    final done = (streak - rank.minStreak).clamp(0, span);
    final toGo = next == null ? 0 : (next!.minStreak - streak);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [rank.color, AppColors.primaryContainer],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                ),
                child: Icon(rank.icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WELLBEING RANK',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(height: 2),
                    Text(rank.name,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 4),
                      Text('$streak',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ],
                  ),
                  Text('day streak',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.85))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: next == null ? 1.0 : (done / span).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.95)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            next == null
                ? 'Top rank reached — ${rank.motto}'
                : '$toGo more ${toGo == 1 ? 'day' : 'days'} to ${next!.name}. ${rank.motto}',
            style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.92)),
          ),
        ],
      ),
    );
  }
}

// ── Badge tile ────────────────────────────────────────────────────────────
class _BadgeTile extends StatelessWidget {
  const _BadgeTile(
      {required this.badge, required this.value, required this.onTap});

  final MilestoneBadge badge;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final earned = value >= badge.goal;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: earned
                  ? badge.color.withValues(alpha: 0.16)
                  : AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
              border: earned
                  ? Border.all(color: badge.color.withValues(alpha: 0.5))
                  : null,
            ),
            child: Icon(badge.icon,
                size: 24, color: earned ? badge.color : AppColors.outline),
          ),
          const SizedBox(height: 5),
          Text(
            badge.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: earned ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
          ),
          if (!earned)
            Text('$value/${badge.goal}',
                style: const TextStyle(
                    fontSize: 8.5, color: AppColors.outline)),
        ],
      ),
    );
  }
}
