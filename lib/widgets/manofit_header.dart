import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// The fixed, translucent, blurred top bar used across the personal app —
/// `bg-surface/80 backdrop-blur-xl` with a hairline `shadow-sm`, height 56
/// (`h-14`), padded to `margin-mobile`.
///
/// Two modes:
///  * [ManofitHeader.brand] — the ManoFit lock-up on the left (Home, Profile).
///  * [ManofitHeader.page]  — a back button + page title (sub-screens).
class ManofitHeader extends StatelessWidget implements PreferredSizeWidget {
  const ManofitHeader._({
    this.title,
    this.showBack = false,
    this.showBrand = false,
    this.onBack,
    this.actions = const [],
    this.tall = false,
  });

  /// Brand lock-up variant.
  factory ManofitHeader.brand({
    List<Widget> actions = const [],
    bool tall = false,
  }) =>
      ManofitHeader._(showBrand: true, actions: actions, tall: tall);

  /// Back-button + title variant.
  factory ManofitHeader.page(
    String title, {
    VoidCallback? onBack,
    List<Widget> actions = const [],
  }) =>
      ManofitHeader._(title: title, showBack: true, onBack: onBack, actions: actions);

  final String? title;
  final bool showBack;
  final bool showBrand;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool tall;

  double get _barHeight => tall ? 64 : 56;

  @override
  Size get preferredSize => Size.fromHeight(_barHeight);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.8),
            boxShadow: AppShadows.sm,
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: _barHeight,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
                child: Row(
                  children: [
                    if (showBack)
                      _RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: onBack ?? () => Navigator.maybePop(context),
                      ),
                    if (showBrand) const _BrandLockup(),
                    if (showBack) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          title ?? '',
                          style: AppText.headlineSm,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    ...actions,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: AppRadii.brSm,
          ),
          child: const Icon(Icons.spa_rounded,
              size: 20, color: AppColors.primaryFixed),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('ManoFit',
            style: AppText.headlineSm.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.brPill,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 24, color: AppColors.onSurface),
      ),
    );
  }
}

/// Standard trailing action — a notification bell.
class HeaderBellAction extends StatelessWidget {
  const HeaderBellAction({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _RoundIconButton(
      icon: Icons.notifications_none_rounded,
      onTap: onTap ??
          () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Operational status: normal. No urgent alerts.'),
                ),
              ),
    );
  }
}

/// Standard trailing action — the round personnel avatar.
class HeaderAvatarAction extends StatelessWidget {
  const HeaderAvatarAction({super.key, this.initial, this.onTap});

  final String? initial;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xxs),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: initial == null || initial!.isEmpty
              ? const Icon(Icons.person_rounded, size: 18, color: AppColors.onPrimary)
              : Text(
                  initial!,
                  style: AppText.labelMd.copyWith(color: AppColors.onPrimary),
                ),
        ),
      ),
    );
  }
}
