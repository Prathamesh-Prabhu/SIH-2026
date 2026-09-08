import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';

/// The four personal-app destinations, exactly as drawn in the Stitch
/// design (`home_light` bottom nav): Home · Assessments · Companion · Profile.
///
/// Self-Help and Book Session are Home quick-actions in the design, not tabs.
enum ManofitTab {
  home(Icons.home_rounded, 'Home', '/home'),
  assessments(Icons.assignment_turned_in_rounded, 'Assessments', '/wellbeing'),
  companion(Icons.psychology_rounded, 'Companion', '/companion'),
  profile(Icons.person_rounded, 'Profile', '/profile');

  const ManofitTab(this.icon, this.label, this.route);

  final IconData icon;
  final String label;
  final String route;
}

/// Fixed, translucent, blurred bottom navigation — `bg-surface/80
/// backdrop-blur-xl` with an upward hairline shadow, `h-16`.
class ManofitBottomNav extends StatelessWidget {
  const ManofitBottomNav({super.key, required this.current});

  final ManofitTab current;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.8),
            boxShadow: AppShadows.navTop,
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final tab in ManofitTab.values)
                    _NavItem(
                      tab: tab,
                      selected: tab == current,
                      onTap: () {
                        if (tab == current) return;
                        context.go(tab.route);
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final ManofitTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? AppColors.primaryContainer : AppColors.outline;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.brSm,
      child: Container(
        constraints: const BoxConstraints(minWidth: 64, minHeight: 44),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tab.icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: AppText.labelSm.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
