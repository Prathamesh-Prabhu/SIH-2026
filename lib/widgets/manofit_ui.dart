import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Shared visual primitives transcribed from the Stitch design system so
/// every screen composes from the same parts (`DESIGN.md` → Components).

/// White elevated surface: `rounded-2xl` fill, hairline-free `shadow-sm`.
class ManofitCard extends StatelessWidget {
  const ManofitCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.color,
    this.radius = AppRadii.brLg,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final BorderRadius radius;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceContainerLowest,
        borderRadius: radius,
        boxShadow: AppShadows.sm,
        border: border,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: radius, onTap: onTap, child: content),
    );
  }
}

/// Section heading with an optional trailing "View all ›" link.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: AppText.headlineSm.copyWith(fontWeight: FontWeight.w700)),
        if (actionLabel != null)
          InkWell(
            onTap: onAction,
            borderRadius: AppRadii.brSm,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxs, vertical: 2),
              child: Row(
                children: [
                  Text(actionLabel!,
                      style: AppText.labelMd.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600)),
                  const Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppColors.secondary),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Low-contrast confidentiality reassurance strip.
class TrustBanner extends StatelessWidget {
  const TrustBanner(
    this.text, {
    super.key,
    this.icon = Icons.verified_user_rounded,
    this.center = true,
  });

  final String text;
  final IconData icon;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.trustPanel,
        borderRadius: AppRadii.brMd,
      ),
      child: Row(
        mainAxisAlignment:
            center ? MainAxisAlignment.center : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(text,
                textAlign: center ? TextAlign.center : TextAlign.start,
                style: AppText.bodySm.copyWith(
                    color: const Color(0xFF526E65),
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

/// Pill badge. [tone] picks the fill/text pairing from the design's
/// badge + status-tag guidance.
enum PillTone { neutral, required_, optional, positive, caution, distress }

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.tone = PillTone.neutral, this.icon});

  final String label;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Color fg;
    switch (tone) {
      case PillTone.neutral:
        bg = AppColors.tertiaryFixed;
        fg = AppColors.primary;
      case PillTone.required_:
        bg = const Color(0xFFFBEBE8);
        fg = const Color(0xFF9C3C2D);
      case PillTone.optional:
        bg = const Color(0xFFE2EDE8);
        fg = const Color(0xFF2D5D51);
      case PillTone.positive:
        bg = AppColors.statusPositive.withValues(alpha: 0.22);
        fg = AppColors.onSecondaryContainer;
      case PillTone.caution:
        bg = AppColors.statusCaution.withValues(alpha: 0.22);
        fg = const Color(0xFF8A5A16);
      case PillTone.distress:
        bg = AppColors.statusDistress.withValues(alpha: 0.20);
        fg = AppColors.onErrorContainer;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadii.brPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: AppText.labelSm
                  .copyWith(color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Full-width primary action — 52px, `rounded-xl`, optional trailing icon.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailingIcon = Icons.arrow_forward_rounded,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? trailingIcon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.onPrimary),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: AppText.labelLg.copyWith(color: AppColors.onPrimary)),
                if (trailingIcon != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Icon(trailingIcon, size: 18),
                ],
              ],
            ),
    );
  }
}

/// Small square icon tile used inside cards/rows (`w-11 h-11 rounded-xl`).
class IconTile extends StatelessWidget {
  const IconTile(
    this.icon, {
    super.key,
    this.background,
    this.foreground,
    this.size = 44,
    this.radius = AppRadii.brMd,
  });

  final IconData icon;
  final Color? background;
  final Color? foreground;
  final double size;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? AppColors.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: radius,
      ),
      child: Icon(icon,
          size: size * 0.52,
          color: foreground ?? AppColors.onSecondaryContainer),
    );
  }
}
