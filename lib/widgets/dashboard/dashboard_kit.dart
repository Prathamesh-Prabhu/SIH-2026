import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Console building blocks, following mindspace's admin widget architecture
/// (PageHeading / IndexTile / DeltaBadge / ChartCard / StackedShareBar /
/// RankedBarChart / TrendChart) but drawn entirely from the ManoFit "Serene
/// Institutional Resilience" stitch tokens in [AppColors].
///
/// Nothing here renders a raw model probability — the PRD allows bands,
/// aggregates and factor attributions only.

// ── Page heading ───────────────────────────────────────────────────────────
class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.badge,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String? badge;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: AppColors.primary)),
                    if (badge != null) StatusPill(label: badge!),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.onSurfaceVariant)),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

// ── Pills & badges ─────────────────────────────────────────────────────────
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.fg = AppColors.secondary,
    this.bg = const Color(0xFFE8F0EA),
    this.icon,
  });

  final String label;
  final Color fg;
  final Color bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

/// Signed change chip. [goodWhenNegative] flips the colour for metrics where a
/// fall is the good outcome (elevated-risk headcount, rejected rows).
class DeltaBadge extends StatelessWidget {
  const DeltaBadge(this.delta,
      {super.key, this.suffix = '', this.goodWhenNegative = false});

  final double delta;
  final String suffix;
  final bool goodWhenNegative;

  @override
  Widget build(BuildContext context) {
    final improving = goodWhenNegative ? delta <= 0 : delta >= 0;
    final color = delta == 0
        ? AppColors.onSurfaceVariant
        : improving
            ? AppColors.secondary
            : AppColors.error;
    final sign = delta > 0 ? '+' : '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          delta == 0
              ? Icons.remove
              : delta > 0
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
          size: 11,
          color: color,
        ),
        const SizedBox(width: 2),
        Text('$sign${delta.toStringAsFixed(1)}$suffix',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

// ── Card shell ─────────────────────────────────────────────────────────────
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    this.description,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final String title;
  final String? description;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(description!,
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Index / stat tile ──────────────────────────────────────────────────────
class IndexTile extends StatelessWidget {
  const IndexTile({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.icon,
    this.accent = AppColors.primary,
    this.delta,
    this.deltaGoodWhenNegative = false,
  });

  final String label;
  final String value;
  final String? hint;
  final IconData? icon;
  final Color accent;
  final double? delta;
  final bool deltaGoodWhenNegative;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: accent),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        letterSpacing: -0.5,
                        color: accent)),
              ),
              if (delta != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: DeltaBadge(delta!,
                      goodWhenNegative: deltaGoodWhenNegative),
                ),
              ],
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 3),
            Text(hint!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10.5, color: AppColors.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

/// Lays tiles out in a responsive grid that never overflows on a phone.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children, this.minTileWidth = 150});

  final List<Widget> children;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = max(1, (c.maxWidth / minTileWidth).floor());
        const gap = 10.0;
        final width = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

// ── Distribution bar ───────────────────────────────────────────────────────
class ShareSegment {
  const ShareSegment(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

/// Single stacked bar showing how a population splits, with a legend.
class StackedShareBar extends StatelessWidget {
  const StackedShareBar({super.key, required this.segments, this.height = 14});

  final List<ShareSegment> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<int>(0, (a, s) => a + s.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: height,
            child: total == 0
                ? Container(color: AppColors.surfaceContainerHigh)
                : Row(
                    children: [
                      for (final s in segments)
                        if (s.value > 0)
                          Expanded(
                            flex: s.value,
                            child: Container(color: s.color),
                          ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final s in segments)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                        color: s.color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${s.label} · ${s.value}'
                    '${total > 0 ? ' (${(s.value / total * 100).round()}%)' : ''}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

// ── Ranked bars ────────────────────────────────────────────────────────────
class RankedRow {
  const RankedRow(this.label, this.value, {this.caption, this.color});
  final String label;
  final double value;
  final String? caption;
  final Color? color;
}

class RankedBarChart extends StatelessWidget {
  const RankedBarChart({
    super.key,
    required this.rows,
    this.maxValue,
    this.valueSuffix = '',
  });

  final List<RankedRow> rows;
  final double? maxValue;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('No cohort data yet.',
          style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant));
    }
    final peak =
        maxValue ?? rows.map((r) => r.value).reduce(max).clamp(1, double.infinity);

    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    ),
                    const SizedBox(width: 8),
                    Text('${r.value.toStringAsFixed(0)}$valueSuffix',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (r.value / peak).clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: AppColors.surfaceContainerHigh,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        r.color ?? AppColors.primaryContainer),
                  ),
                ),
                if (r.caption != null) ...[
                  const SizedBox(height: 3),
                  Text(r.caption!,
                      style: const TextStyle(
                          fontSize: 10.5, color: AppColors.onSurfaceVariant)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ── Sparkline trend ────────────────────────────────────────────────────────
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.values,
    this.height = 58,
    this.color = AppColors.primaryContainer,
  });

  final List<double> values;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SparklinePainter(values, color)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color);
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final lo = values.reduce(min);
    final hi = values.reduce(max);
    final span = (hi - lo).abs() < 0.0001 ? 1.0 : hi - lo;

    Offset at(int i) => Offset(
          size.width * (i / (values.length - 1)),
          size.height - ((values[i] - lo) / span) * (size.height - 6) - 3,
        );

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      final prev = at(i - 1);
      final curr = at(i);
      final midX = (prev.dx + curr.dx) / 2;
      line.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.18), color.withOpacity(0.0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final last = at(values.length - 1);
    canvas.drawCircle(last, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.color != color;
}

// ── Executive summary hero ─────────────────────────────────────────────────
class ExecutiveSummaryCard extends StatelessWidget {
  const ExecutiveSummaryCard({
    super.key,
    required this.eyebrow,
    required this.headline,
    required this.body,
    this.bullets = const [],
    this.footnote,
  });

  final String eyebrow;
  final String headline;
  final String body;
  final List<String> bullets;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryContainer, AppColors.secondary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.secondaryFixed.withOpacity(0.95))),
          const SizedBox(height: 6),
          Text(headline,
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  letterSpacing: -0.3,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text(body,
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: Colors.white.withOpacity(0.88))),
          if (bullets.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final b in bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                            color: AppColors.secondaryFixed,
                            shape: BoxShape.circle),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(b,
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: Colors.white.withOpacity(0.92))),
                    ),
                  ],
                ),
              ),
          ],
          if (footnote != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.lock_outline,
                    size: 12, color: Colors.white.withOpacity(0.7)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(footnote!,
                      style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.white.withOpacity(0.7))),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Section heading ────────────────────────────────────────────────────────
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.icon, this.trailing});

  final String title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: AppColors.secondary),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
