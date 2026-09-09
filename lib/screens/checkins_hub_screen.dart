import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/navigation.dart';
import '../core/theme/app_theme.dart';
import '../data/assessment_cadence.dart';
import '../services/db_service.dart';

/// Personnel check-ins hub — daily / weekly / monthly.
///
/// Each one the person completes is pseudonymised and folded into the anonymous
/// Organisation Wellbeing roll-up on the HR dashboard immediately.
class CheckInsHubScreen extends StatefulWidget {
  const CheckInsHubScreen({super.key});

  @override
  State<CheckInsHubScreen> createState() => _CheckInsHubScreenState();
}

class _CheckInsHubScreenState extends State<CheckInsHubScreen> {
  final _db = DbService();

  @override
  void initState() {
    super.initState();
    _db.addListener(_onChange);
  }

  @override
  void dispose() {
    _db.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.backOr('/home'),
        ),
        title: const Text('Check-ins',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            const Text(
              'Answer these as they come due. They are private — pseudonymised '
              'before they reach welfare analytics, never shown back to you or '
              'your chain of command.',
              style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            for (final c in CheckInCadence.values) ...[
              _cadenceCard(c),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cadenceCard(CheckInCadence c) {
    final last = _db.lastCheckInAt(c.id);
    final due = _db.isCheckInDue(c.id, c.interval);
    final statusLabel = due ? (last == null ? 'Not started' : 'Due now') : cadenceDueLabel(c, last);
    final statusColor = due ? const Color(0xFFB26A00) : AppColors.secondary;

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/wellbeing?cadence=${c.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: due ? const Color(0xFFF0D9B4) : AppColors.hairline,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(c.icon, size: 21, color: AppColors.onSecondaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    const SizedBox(height: 2),
                    Text('${c.blurb} · ${c.items.length} questions',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(statusLabel,
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700, color: statusColor)),
                  const SizedBox(height: 2),
                  const Icon(Icons.chevron_right, size: 18, color: AppColors.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
