import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Small shared building blocks for the Mindfulness screens.
///
/// [MindButton] is an `InkWell`-based pill that sizes to its label — the app
/// theme forces Material buttons to infinite width, which blanks the screen
/// when one is placed in a `Row`/`Align`, so mindfulness CTAs use this instead.

class MindButton extends StatelessWidget {
  const MindButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = true,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool filled;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? AppColors.primaryContainer : Colors.transparent;
    final fg = filled ? Colors.white : AppColors.primary;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg),
          ),
        ),
      ],
    );

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          decoration: filled
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
          child: child,
        ),
      ),
    );
  }
}

/// White rounded panel with an optional title / chevron — the recurring
/// "activity row" and "section card" shape from the reference screens.
class MindCard extends StatelessWidget {
  const MindCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.hairline),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: body,
      ),
    );
  }
}

/// Left-aligned section title with an optional trailing "see all" chevron.
class MindSectionTitle extends StatelessWidget {
  const MindSectionTitle(this.title, {super.key, this.onTapAll});

  final String title;
  final VoidCallback? onTapAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (onTapAll != null)
          InkWell(
            onTap: onTapAll,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.chevron_right, color: AppColors.secondary),
            ),
          ),
      ],
    );
  }
}
