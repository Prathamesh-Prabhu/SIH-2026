import 'package:flutter/material.dart';
import '../core/navigation.dart';
import '../core/theme/app_theme.dart';
import '../data/assessment_cadence.dart';
import '../data/assessment_questions.dart';
import '../services/db_service.dart';

/// The private check-ins (PRD §7). One question per page, 1–5 scale, nothing
/// scored back to the user. The question bank depends on the [cadence].
class WellbeingCheckInScreen extends StatefulWidget {
  const WellbeingCheckInScreen({super.key, this.cadence = CheckInCadence.weekly});

  final CheckInCadence cadence;

  @override
  State<WellbeingCheckInScreen> createState() => _WellbeingCheckInScreenState();
}

class _WellbeingCheckInScreenState extends State<WellbeingCheckInScreen> {
  final _db = DbService();
  int _index = 0;
  final Map<String, int> _answers = {};
  bool _submitting = false;

  List<AssessmentQuestion> get _items => questionsForCadence(widget.cadence);
  AssessmentQuestion get _item => _items[_index];
  int? get _selected => _answers[_item.key];
  bool get _isLast => _index == _items.length - 1;
  Color get _accent => widget.cadence.accent;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final ok =
        await _db.recordWellbeingCheckIn(_answers, cadence: widget.cadence.id);
    if (!mounted) return;
    setState(() => _submitting = false);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: _accent),
            const SizedBox(width: 8),
            const Expanded(
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
              '${widget.cadence.title} saved — ${_items.length} answers.',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            const Text(
              'Pseudonymised before it reaches welfare analytics. Your commander '
              'cannot see it, and no score or flag is shown back to you.',
              style: TextStyle(fontSize: 12.5, color: AppColors.onSurfaceVariant),
            ),
            if (!ok) ...[
              const SizedBox(height: 10),
              const Text(
                'Saved on this device — it will sync when back online.',
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
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.backOr('/checkins');
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.backOr('/checkins'),
        ),
        title: Text(widget.cadence.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cadence framing — one line.
              Row(
                children: [
                  Icon(widget.cadence.icon, size: 15, color: _accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(widget.cadence.horizon,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.onSurfaceVariant)),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Progress: segmented dots + count.
              Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                            right: i == _items.length - 1 ? 0 : 4),
                        height: 5,
                        decoration: BoxDecoration(
                          color: i <= _index
                              ? _accent
                              : AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Question ${_index + 1} of ${_items.length}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 16),

              // Question card.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_item.icon, size: 18, color: _accent),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Private',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSecondaryContainer)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(_item.question,
                        style: const TextStyle(
                            fontSize: 18,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                    const SizedBox(height: 6),
                    Text(_item.helper,
                        style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              for (var i = 0; i < _item.labels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _optionTile(value: i + 1, label: _item.labels[i]),
                ),
              const SizedBox(height: 14),

              Row(
                children: [
                  if (_index > 0) ...[
                    OutlinedButton(
                      onPressed: () => setState(() => _index--),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.outlineVariant),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Back'),
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
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.surfaceContainerHigh,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
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
                                    _isLast ? 'Submit' : 'Next',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                    _isLast
                                        ? Icons.check_rounded
                                        : Icons.arrow_forward_rounded,
                                    size: 18),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionTile({required int value, required String label}) {
    final isSelected = _selected == value;
    return Material(
      color: isSelected ? _accent.withOpacity(0.10) : AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _answers[_item.key] = value),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? _accent : AppColors.hairline,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? _accent : AppColors.surfaceContainerHigh,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 15, color: Colors.white)
                    : Text('$value',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurfaceVariant)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? _accent : AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
