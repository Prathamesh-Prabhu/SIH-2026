import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/mindfulness_content.dart';
import '../../services/db_service.dart';
import '../../widgets/dashboard/dashboard_kit.dart';

enum _Grain { days, weeks, months }

extension on _Grain {
  String get label => switch (this) {
        _Grain.days => 'Days',
        _Grain.weeks => 'Weeks',
        _Grain.months => 'Months',
      };
  String get unit => switch (this) {
        _Grain.days => 'day',
        _Grain.weeks => 'week',
        _Grain.months => 'month',
      };
  int get buckets => switch (this) {
        _Grain.days => 7,
        _Grain.weeks => 8,
        _Grain.months => 6,
      };
}

class _Bucket {
  _Bucket(this.label);
  final String label;
  final List<int> moodLevels = [];
  int breathing = 0;
  int meditation = 0;
  int doodle = 0;
  int seconds = 0;

  int get sessions => breathing + meditation + doodle;
  int get checkins => moodLevels.length;
  int get minutes => seconds ~/ 60;
  double get avgMood => moodLevels.isEmpty
      ? 0
      : moodLevels.reduce((a, b) => a + b) / moodLevels.length;
}

/// Mindfulness tracking dashboard — Days / Weeks / Months, mirroring the
/// Samsung Health mindfulness history. All figures are derived from the
/// user's own `mindfulness_moods` + `mindfulness_logs` rows.
class MindfulnessHistoryScreen extends StatefulWidget {
  const MindfulnessHistoryScreen({super.key});

  @override
  State<MindfulnessHistoryScreen> createState() =>
      _MindfulnessHistoryScreenState();
}

class _MindfulnessHistoryScreenState extends State<MindfulnessHistoryScreen> {
  _Grain _grain = _Grain.days;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<DbService>().refreshMindfulness(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DbService>();
    final buckets = _build(db);
    final rangeMoods = buckets.expand((b) => b.moodLevels).toList();
    final totalCheckins = rangeMoods.length;
    final totalBreathing = buckets.fold<int>(0, (a, b) => a + b.breathing);
    final totalMeditation = buckets.fold<int>(0, (a, b) => a + b.meditation);
    final totalDoodle = buckets.fold<int>(0, (a, b) => a + b.doodle);
    final totalMinutes = buckets.fold<int>(0, (a, b) => a + b.seconds) ~/ 60;
    final avgMood = rangeMoods.isEmpty
        ? 0.0
        : rangeMoods.reduce((a, b) => a + b) / rangeMoods.length;

    final dist = <int, int>{for (var l = 1; l <= 5; l++) l: 0};
    for (final l in rangeMoods) {
      dist[l] = (dist[l] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.backOr('/mindfulness'),
        ),
        title: const Text('Mindfulness history',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Row(
              children: [
                for (final g in _Grain.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(g.label),
                      selected: _grain == g,
                      onSelected: (_) => setState(() => _grain = g),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            TileGrid(
              minTileWidth: 150,
              children: [
                IndexTile(
                  label: 'Mood check-ins',
                  value: '$totalCheckins',
                  icon: Icons.favorite_border_rounded,
                  accent: AppColors.secondary,
                ),
                IndexTile(
                  label: 'Mindful minutes',
                  value: '$totalMinutes',
                  icon: Icons.timer_outlined,
                  accent: AppColors.primaryContainer,
                ),
                IndexTile(
                  label: 'Breathing sessions',
                  value: '$totalBreathing',
                  icon: Icons.air_rounded,
                  accent: const Color(0xFF7C6FD6),
                ),
                IndexTile(
                  label: 'Meditation sessions',
                  value: '$totalMeditation',
                  icon: Icons.self_improvement_rounded,
                  accent: AppColors.secondary,
                ),
                IndexTile(
                  label: 'Doodles',
                  value: '$totalDoodle',
                  icon: Icons.gesture_rounded,
                  accent: const Color(0xFFC86D51),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Mood check-ins bar chart ──────────────────────────────────
            ChartCard(
              title: 'Mood check-ins per ${_grain.unit}',
              description: totalCheckins == 0
                  ? 'No check-ins in this range yet'
                  : 'Bar height = number of check-ins, coloured by average mood',
              child: totalCheckins == 0
                  ? const _EmptyLine('Log a mood check-in to start this chart.')
                  : _VBarChart(
                      bars: [
                        for (final b in buckets)
                          _Bar(
                            label: b.label,
                            value: b.checkins.toDouble(),
                            caption: b.checkins == 0 ? '' : '${b.checkins}',
                            color: b.moodLevels.isEmpty
                                ? AppColors.surfaceContainerHigh
                                : moodLevelFor(b.avgMood.round()).color,
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // ── Average-mood trend line ───────────────────────────────────
            ChartCard(
              title: 'Average mood trend',
              description: avgMood == 0
                  ? 'No check-ins in this range yet'
                  : '${avgMood.toStringAsFixed(1)} / 5 · '
                      '${moodLevelFor(avgMood.round()).label}',
              child: rangeMoods.length < 2
                  ? const _EmptyLine('Log a few mood check-ins to see a trend.')
                  : Column(
                      children: [
                        TrendChart(
                          values: buckets
                              .map((b) => b.avgMood == 0 ? avgMood : b.avgMood)
                              .toList(),
                          color: AppColors.secondary,
                        ),
                        const SizedBox(height: 8),
                        _AxisLabels(
                            labels: buckets.map((b) => b.label).toList()),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // ── Mood mix ──────────────────────────────────────────────────
            ChartCard(
              title: 'Mood mix',
              description: 'How your check-ins broke down',
              child: totalCheckins == 0
                  ? const _EmptyLine('No mood data in this range.')
                  : StackedShareBar(
                      segments: [
                        for (final m in kMoodLevels)
                          ShareSegment(m.label, dist[m.level] ?? 0, m.color),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // ── Mindful minutes bar chart ─────────────────────────────────
            ChartCard(
              title: 'Mindful minutes per ${_grain.unit}',
              description: 'Time spent breathing, meditating and doodling',
              child: buckets.every((b) => b.minutes == 0)
                  ? const _EmptyLine('No sessions logged in this range.')
                  : _VBarChart(
                      bars: [
                        for (final b in buckets)
                          _Bar(
                            label: b.label,
                            value: b.minutes.toDouble(),
                            caption: b.minutes == 0 ? '' : '${b.minutes}m',
                            color: AppColors.primaryContainer,
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // ── Sessions breakdown ────────────────────────────────────────
            ChartCard(
              title: 'Sessions per ${_grain.unit}',
              description: 'Breathing · Meditation · Doodle',
              child: buckets.every((b) => b.sessions == 0)
                  ? const _EmptyLine('No sessions logged in this range.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final b in buckets)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                    width: 44,
                                    child: Text(b.label,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color:
                                                AppColors.onSurfaceVariant))),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Row(
                                      children: [
                                        if (b.breathing > 0)
                                          Expanded(
                                            flex: b.breathing,
                                            child: Container(
                                                height: 10,
                                                color:
                                                    const Color(0xFF7C6FD6)),
                                          ),
                                        if (b.meditation > 0)
                                          Expanded(
                                            flex: b.meditation,
                                            child: Container(
                                                height: 10,
                                                color: AppColors.secondary),
                                          ),
                                        if (b.doodle > 0)
                                          Expanded(
                                            flex: b.doodle,
                                            child: Container(
                                                height: 10,
                                                color:
                                                    const Color(0xFFC86D51)),
                                          ),
                                        if (b.sessions == 0)
                                          Expanded(
                                            child: Container(
                                                height: 10,
                                                color: AppColors
                                                    .surfaceContainerHigh),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${b.sessions}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 14,
                          runSpacing: 4,
                          children: const [
                            _LegendDot(Color(0xFF7C6FD6), 'Breathing'),
                            _LegendDot(AppColors.secondary, 'Meditation'),
                            _LegendDot(Color(0xFFC86D51), 'Doodle'),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            const SectionHeading('Recent activity', icon: Icons.history_rounded),
            _RecentList(db: db),
          ],
        ),
      ),
    );
  }

  List<_Bucket> _build(DbService db) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final buckets = <_Bucket>[];
    final n = _grain.buckets;

    DateTime start(int i) => switch (_grain) {
          _Grain.days => today.subtract(Duration(days: n - 1 - i)),
          _Grain.weeks =>
            today.subtract(Duration(days: (n - 1 - i) * 7 + today.weekday - 1)),
          _Grain.months => DateTime(now.year, now.month - (n - 1 - i), 1),
        };

    for (var i = 0; i < n; i++) {
      final s = start(i);
      final label = switch (_grain) {
        _Grain.days => _wd(s.weekday),
        _Grain.weeks => '${s.day}/${s.month}',
        _Grain.months => _mon(s.month),
      };
      buckets.add(_Bucket(label));
    }

    DateTime? next(int i) => i + 1 < n ? start(i + 1) : null;

    int idxFor(DateTime ts) {
      for (var i = 0; i < n; i++) {
        final lo = start(i);
        final hi = next(i);
        if (!ts.isBefore(lo) && (hi == null || ts.isBefore(hi))) return i;
      }
      return -1;
    }

    for (final m in db.mindfulnessMoods) {
      final ts = DateTime.tryParse(m['created_at'] as String? ?? '');
      if (ts == null) continue;
      final i = idxFor(ts);
      if (i < 0) continue;
      buckets[i].moodLevels.add((m['mood_level'] as num?)?.toInt() ?? 3);
    }
    for (final l in db.mindfulnessLogs) {
      final ts = DateTime.tryParse(l['created_at'] as String? ?? '');
      if (ts == null) continue;
      final i = idxFor(ts);
      if (i < 0) continue;
      buckets[i].seconds += (l['actual_seconds'] as num?)?.toInt() ?? 0;
      switch (l['activity_type']) {
        case 'breathing':
          buckets[i].breathing++;
        case 'doodle':
          buckets[i].doodle++;
        default:
          buckets[i].meditation++;
      }
    }
    return buckets;
  }

  static String _wd(int w) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][(w - 1) % 7];
  static String _mon(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][(m - 1) % 12];
}

// ── Vertical bar chart ─────────────────────────────────────────────────────
class _Bar {
  const _Bar(
      {required this.label,
      required this.value,
      required this.color,
      this.caption = ''});
  final String label;
  final double value;
  final Color color;
  final String caption;
}

class _VBarChart extends StatelessWidget {
  const _VBarChart({required this.bars});

  final List<_Bar> bars;

  static const double height = 130;

  @override
  Widget build(BuildContext context) {
    final peak = bars.fold<double>(1, (m, b) => b.value > m ? b.value : m);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in bars)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (b.caption.isNotEmpty)
                    Text(b.caption,
                        style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  const SizedBox(height: 2),
                  Container(
                    width: 14,
                    height: (b.value / peak * (height - 34)).clamp(3.0, height),
                    decoration: BoxDecoration(
                      color: b.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(b.label,
                      style: const TextStyle(
                          fontSize: 9.5, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.labels});
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final l in labels)
          Text(l,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.onSurfaceVariant)),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.color, this.label);
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5, color: AppColors.onSurfaceVariant)),
        ],
      );
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.4));
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.db});
  final DbService db;

  static const _titles = {
    'breathing': 'Breathing',
    'meditation': 'Meditation',
    'doodle': 'Doodle',
  };

  @override
  Widget build(BuildContext context) {
    IconData iconFor(String type) => switch (type) {
          'breathing' => Icons.air_rounded,
          'doodle' => Icons.gesture_rounded,
          _ => Icons.self_improvement_rounded,
        };

    final items = <Map<String, dynamic>>[
      ...db.mindfulnessMoods.map((m) => {
            'ts': m['created_at'],
            'icon': Icons.sentiment_satisfied_alt_rounded,
            'title': 'Mood · ${m['mood_label']}',
            'sub': ((m['factors'] as List?)?.join(', ') ?? '').toString(),
          }),
      ...db.mindfulnessLogs.map((l) {
        final type = (l['activity_type'] as String?) ?? 'meditation';
        return {
          'ts': l['created_at'],
          'icon': iconFor(type),
          'title': '${_titles[type] ?? 'Session'} · ${l['title']}',
          'sub': '${(((l['actual_seconds'] as num?)?.toInt() ?? 0) ~/ 60)} min',
        };
      }),
    ]..sort((a, b) =>
        (b['ts'] as String? ?? '').compareTo(a['ts'] as String? ?? ''));

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: _EmptyLine('Nothing logged yet. Your sessions and check-ins '
            'will appear here.'),
      );
    }

    return Column(
      children: [
        for (final it in items.take(12))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              children: [
                Icon(it['icon'] as IconData,
                    size: 18, color: AppColors.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it['title'] as String,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                      if ((it['sub'] as String).isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(it['sub'] as String,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
                Text(_ago(it['ts'] as String? ?? ''),
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
      ],
    );
  }

  static String _ago(String iso) {
    final ts = DateTime.tryParse(iso);
    if (ts == null) return '';
    final d = DateTime.now().difference(ts);
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}
