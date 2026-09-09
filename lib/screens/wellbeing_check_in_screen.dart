import 'package:flutter/material.dart';
import '../core/navigation.dart';
import '../core/theme/app_theme.dart';
import '../data/wellbeing_checkins.dart';
import '../services/db_service.dart';

/// The six private check-ins (PRD §7). Direct "wellness survey data" input to
/// the analytics layer — one item per page, 1–5 scale, nothing scored back to
/// the user.
class WellbeingCheckInScreen extends StatefulWidget {
  const WellbeingCheckInScreen({super.key});

  @override
  State<WellbeingCheckInScreen> createState() => _WellbeingCheckInScreenState();
}

class _WellbeingCheckInScreenState extends State<WellbeingCheckInScreen> {
  final _db = DbService();
  int _index = 0;
  final Map<String, int> _answers = {};
  bool _submitting = false;

  CheckInItem get _item => kWellbeingCheckIns[_index];
  int? get _selected => _answers[_item.key];
  bool get _isLast => _index == kWellbeingCheckIns.length - 1;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final ok = await _db.recordWellbeingCheckIn(_answers);
    if (!mounted) return;
    setState(() => _submitting = false);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.verified_user_outlined, color: AppColors.secondary),
            SizedBox(width: 8),
            Expanded(
              child: Text('Check-in recorded',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${kWellbeingCheckIns.length} of ${kWellbeingCheckIns.length} check-ins saved.',
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your answers are pseudonymized before they reach the welfare analytics layer. '
              'Your commander cannot see them, and no individual score or flag is ever shown '
              'back to you or to the chain of command.',
              style:
                  TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
            ),
            if (!ok) ...[
              const SizedBox(height: 10),
              const Text(
                'Saved on this device — it will sync when the connection is restored.',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.onSurfaceVariant),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.backOr('/home');
            },
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_index + 1) / kWellbeingCheckIns.length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.backOr('/home'),
        ),
        title: const Text('Wellbeing Check-in',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('CHECK-IN PROGRESS',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: AppColors.onSurfaceVariant)),
                  Text('${_index + 1} of ${kWellbeingCheckIns.length}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryContainer)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primaryContainer),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 18),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_item.icon,
                        size: 14, color: AppColors.onSecondaryContainer),
                    const SizedBox(width: 4),
                    const Flexible(
                      child: Text('Private — not visible to your unit',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSecondaryContainer)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Text(
                _item.question,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      height: 1.3,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                _item.helper,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),

              for (var i = 0; i < _item.labels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _optionTile(value: i + 1, label: _item.labels[i]),
                ),
              const SizedBox(height: 20),

              Row(
                children: [
                  if (_index > 0) ...[
                    OutlinedButton(
                      onPressed: () => setState(() => _index--),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side:
                            const BorderSide(color: AppColors.outlineVariant),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Previous'),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_selected == null || _submitting)
                          ? null
                          : () {
                              if (_isLast) {
                                _submit();
                              } else {
                                setState(() => _index++);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        minimumSize: Size.zero,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    _isLast ? 'Submit Check-in' : 'Next',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 18),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
              if (_selected == null) ...[
                const SizedBox(height: 10),
                const Text(
                  'Choose the option that fits best to continue.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionTile({required int value, required String label}) {
    final isSelected = _selected == value;
    return Material(
      color: isSelected
          ? AppColors.secondaryFixed.withOpacity(0.35)
          : AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      elevation: isSelected ? 0 : 1,
      shadowColor: Colors.black.withOpacity(0.04),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _answers[_item.key] = value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primaryContainer
                        : AppColors.onSurface,
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppColors.primaryContainer
                      : AppColors.surfaceContainerHigh,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
